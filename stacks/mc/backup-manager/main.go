package main

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/james4k/rcon"
	"github.com/robfig/cron/v3"
)

type Config struct {
	ConnectionString  string
	BackupContainer   string
	BackupSchedule    string
	RetentionDays     int
	MinecraftDataPath string
	RconHost          string
	RconPort          string
	RconPassword      string
}

func getConfig() *Config {
	retentionDays := 7
	if days := os.Getenv("BACKUP_RETENTION_DAYS"); days != "" {
		fmt.Sscanf(days, "%d", &retentionDays)
	}

	return &Config{
		ConnectionString:  os.Getenv("AZURE_STORAGE_CONNECTION_STRING"),
		BackupContainer:   getEnv("BACKUP_CONTAINER", "minecraft-backups"),
		BackupSchedule:    getEnv("BACKUP_SCHEDULE", "0 */6 * * *"),
		RetentionDays:     retentionDays,
		MinecraftDataPath: "/data",
		RconHost:          getEnv("RCON_HOST", "localhost"),
		RconPort:          getEnv("RCON_PORT", "25575"),
		RconPassword:      os.Getenv("RCON_PASSWORD"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func sendRconCommand(config *Config, command string) error {
	addr := fmt.Sprintf("%s:%s", config.RconHost, config.RconPort)
	conn, err := rcon.Dial(addr, config.RconPassword)
	if err != nil {
		return err
	}
	defer conn.Close()

	// send the command by writing it to the connection (some rcon clients don't expose Command)
	// write the command followed by a newline and ignore the server response
	if _, err := conn.Write(command + "\n"); err != nil {
		return err
	}
	return nil
}

func notifyPlayers(config *Config, message string) {
	cmd := fmt.Sprintf(`tellraw @a {"text":"%s","color":"yellow"}`, message)
	if err := sendRconCommand(config, cmd); err != nil {
		log.Printf("Failed to notify players: %v", err)
	}
}

func createBackup(config *Config, client *azblob.Client) error {
	timestamp := time.Now().UTC().Format("20060102_150405")
	backupName := fmt.Sprintf("minecraft_backup_%s.tar.gz", timestamp)

	log.Printf("Starting backup: %s", backupName)

	// Notify players
	notifyPlayers(config, "[Backup] Starting world backup in 10 seconds...")
	time.Sleep(10 * time.Second)

	// Disable auto-save
	sendRconCommand(config, "save-off")
	sendRconCommand(config, "save-all")
	time.Sleep(2 * time.Second)

	defer sendRconCommand(config, "save-on")

	// Create temp file
	tmpFile, err := os.CreateTemp("", "minecraft-backup-*.tar.gz")
	if err != nil {
		return err
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Create tar.gz
	gzWriter := gzip.NewWriter(tmpFile)
	defer gzWriter.Close()

	tarWriter := tar.NewWriter(gzWriter)
	defer tarWriter.Close()

	// Add world folders
	worldFolders := []string{"world", "world_nether", "world_the_end"}
	for _, folder := range worldFolders {
		folderPath := filepath.Join(config.MinecraftDataPath, folder)
		if _, err := os.Stat(folderPath); err == nil {
			if err := addToTar(tarWriter, folderPath, folder); err != nil {
				log.Printf("Failed to add %s: %v", folder, err)
			}
		}
	}

	// Add config files
	configFiles := []string{
		"server.properties", "ops.json", "whitelist.json",
		"banned-players.json", "banned-ips.json",
	}
	for _, file := range configFiles {
		filePath := filepath.Join(config.MinecraftDataPath, file)
		if _, err := os.Stat(filePath); err == nil {
			if err := addToTar(tarWriter, filePath, file); err != nil {
				log.Printf("Failed to add %s: %v", file, err)
			}
		}
	}

	// Close writers to flush
	tarWriter.Close()
	gzWriter.Close()

	// Upload to Azure
	tmpFile.Seek(0, 0)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	_, err = client.UploadFile(ctx, config.BackupContainer, backupName, tmpFile, nil)
	if err != nil {
		return fmt.Errorf("upload failed: %w", err)
	}

	// Get file size
	stat, _ := tmpFile.Stat()
	sizeMB := float64(stat.Size()) / (1024 * 1024)

	log.Printf("Backup completed: %s (%.2f MB)", backupName, sizeMB)
	notifyPlayers(config, fmt.Sprintf("[Backup] World backup completed (%.2f MB)", sizeMB))

	return nil
}

func addToTar(tw *tar.Writer, path string, name string) error {
	return filepath.Walk(path, func(file string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		header, err := tar.FileInfoHeader(fi, fi.Name())
		if err != nil {
			return err
		}

		relPath, _ := filepath.Rel(path, file)
		if relPath == "." {
			relPath = ""
		}
		header.Name = filepath.Join(name, relPath)

		if err := tw.WriteHeader(header); err != nil {
			return err
		}

		if !fi.Mode().IsRegular() {
			return nil
		}

		f, err := os.Open(file)
		if err != nil {
			return err
		}
		defer f.Close()

		_, err = io.Copy(tw, f)
		return err
	})
}

func cleanupOldBackups(config *Config, client *azblob.Client) error {
	ctx := context.Background()
	cutoff := time.Now().Add(-time.Duration(config.RetentionDays) * 24 * time.Hour)

	pager := client.NewListBlobsFlatPager(config.BackupContainer, nil)

	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return err
		}

		for _, blob := range page.Segment.BlobItems {
			if blob.Properties.LastModified.Before(cutoff) {
				log.Printf("Deleting old backup: %s", *blob.Name)
				_, err := client.DeleteBlob(ctx, config.BackupContainer, *blob.Name, nil)
				if err != nil {
					log.Printf("Failed to delete %s: %v", *blob.Name, err)
				}
			}
		}
	}

	return nil
}

func main() {
	config := getConfig()

	log.Printf("Minecraft Backup Manager started")
	log.Printf("Schedule: %s, Retention: %d days", config.BackupSchedule, config.RetentionDays)

	// Create Azure client
	client, err := azblob.NewClientFromConnectionString(config.ConnectionString, nil)
	if err != nil {
		log.Fatalf("Failed to create Azure client: %v", err)
	}

	// Create container if needed
	ctx := context.Background()
	_, _ = client.CreateContainer(ctx, config.BackupContainer, nil)

	// Schedule backups
	c := cron.New()

	_, err = c.AddFunc(config.BackupSchedule, func() {
		if err := createBackup(config, client); err != nil {
			log.Printf("Backup failed: %v", err)
			notifyPlayers(config, "[Backup] Backup failed! Check server logs.")
		}
	})
	if err != nil {
		log.Fatalf("Invalid cron schedule: %v", err)
	}

	// Schedule cleanup daily at 3 AM
	c.AddFunc("0 3 * * *", func() {
		if err := cleanupOldBackups(config, client); err != nil {
			log.Printf("Cleanup failed: %v", err)
		}
	})

	// Run initial backup after 5 minutes
	time.AfterFunc(5*time.Minute, func() {
		createBackup(config, client)
	})

	c.Start()

	// Keep running
	select {}
}
