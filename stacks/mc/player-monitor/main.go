package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
)

type Config struct {
	MinecraftHost     string
	MinecraftPort     int
	ConnectionString  string
	QueueName         string
	CheckInterval     time.Duration
	InactivityTimeout time.Duration
}

type ActivityMessage struct {
	Timestamp   time.Time `json:"timestamp"`
	PlayerCount int       `json:"player_count"`
	Server      string    `json:"server"`
}

func getConfig() *Config {
	port, _ := strconv.Atoi(getEnv("MINECRAFT_PORT", "25565"))
	checkInterval, _ := strconv.Atoi(getEnv("CHECK_INTERVAL", "30"))
	inactivityTimeout, _ := strconv.Atoi(getEnv("INACTIVITY_TIMEOUT", "600"))

	return &Config{
		MinecraftHost:     getEnv("MINECRAFT_HOST", "localhost"),
		MinecraftPort:     port,
		ConnectionString:  os.Getenv("AZURE_STORAGE_CONNECTION_STRING"),
		QueueName:         getEnv("QUEUE_NAME", "player-activity"),
		CheckInterval:     time.Duration(checkInterval) * time.Second,
		InactivityTimeout: time.Duration(inactivityTimeout) * time.Second,
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Simple TCP check to see if server is responsive
func checkServerAlive(host string, port int) (bool, error) {
	addr := net.JoinHostPort(host, fmt.Sprintf("%d", port))

	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		return false, err
	}
	defer conn.Close()

	return true, nil
}

func sendActivitySignal(client *azqueue.QueueClient, server string) error {
	message := ActivityMessage{
		Timestamp:   time.Now().UTC(),
		PlayerCount: 1, // We just care that server is alive
		Server:      server,
	}

	messageBytes, err := json.Marshal(message)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	ttl := int32(600) // 10 minutes
	_, err = client.EnqueueMessage(ctx, string(messageBytes), &azqueue.EnqueueMessageOptions{
		TimeToLive: &ttl,
	})

	return err
}

func clearQueue(client *azqueue.QueueClient) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := client.ClearMessages(ctx, nil)
	return err
}

func main() {
	config := getConfig()

	log.Printf("Starting player monitor for %s:%d", config.MinecraftHost, config.MinecraftPort)
	log.Printf("Check interval: %v, Inactivity timeout: %v", config.CheckInterval, config.InactivityTimeout)

	// Wait for Minecraft to initialize
	log.Println("Waiting 60 seconds for Minecraft server to initialize...")
	time.Sleep(60 * time.Second)

	// Initialize Azure Queue client
	queueClient, err := azqueue.NewQueueClientFromConnectionString(
		config.ConnectionString,
		config.QueueName,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to create queue client: %v", err)
	}

	// Create queue if it doesn't exist
	ctx := context.Background()
	_, _ = queueClient.Create(ctx, nil)

	var lastServerUp bool
	var inactiveChecks int
	checksUntilShutdown := int(config.InactivityTimeout / config.CheckInterval)

	for {
		serverAddr := fmt.Sprintf("%s:%d", config.MinecraftHost, config.MinecraftPort)
		serverUp, err := checkServerAlive(config.MinecraftHost, config.MinecraftPort)

		if serverUp {
			log.Printf("✅ Server is running and responsive")
			if err := sendActivitySignal(queueClient, serverAddr); err != nil {
				log.Printf("Failed to send activity signal: %v", err)
			}
			inactiveChecks = 0
		} else {
			log.Printf("❌ Server not responding: %v", err)
			inactiveChecks++
			remaining := checksUntilShutdown - inactiveChecks

			if remaining > 0 {
				log.Printf("Server unresponsive. Shutdown in %d checks (%v)",
					remaining, time.Duration(remaining)*config.CheckInterval)
			} else {
				log.Println("Inactivity timeout reached. Container will scale down soon.")
				_ = clearQueue(queueClient)
			}
		}

		if !lastServerUp && serverUp {
			log.Println("🎮 Server is now responsive!")
		} else if lastServerUp && !serverUp {
			log.Println("👋 Server has stopped responding")
		}

		lastServerUp = serverUp
		time.Sleep(config.CheckInterval)
	}
}
