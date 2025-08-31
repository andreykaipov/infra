package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/gorcon/rcon"
)

const azureScope = "https://management.azure.com/.default"

type Monitor struct {
	rconAddr          string
	rconPassword      string
	checkInterval     time.Duration
	inactivityTimeout time.Duration
	stopMethod        string
	lastPlayerTime    time.Time

	// Azure Container App stopping
	subscriptionID   string
	resourceGroup    string
	containerAppName string
	azureCredential  *azidentity.DefaultAzureCredential
	lastStopTime     time.Time
}

func main() {
	log.SetPrefix("[player-monitor] ")
	log.Println("Starting...")
	log.Println("Waiting for server to start before monitoring...")
	time.Sleep(1 * time.Minute)

	credential, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Printf("Failed to create Azure credential (continuing without scaling): %v", err)
	}

	m := &Monitor{
		rconAddr:          fmt.Sprintf("%s:%s", env("MINECRAFT_HOST", "127.0.0.1"), env("RCON_PORT", "25575")),
		rconPassword:      env("RCON_PASSWORD", ""),
		checkInterval:     duration(env("CHECK_INTERVAL", "30s")),
		inactivityTimeout: duration(env("INACTIVITY_TIMEOUT", "5m")),
		stopMethod:        env("STOP_METHOD", "rcon"),
		lastPlayerTime:    time.Now(),

		subscriptionID:   env("AZURE_SUBSCRIPTION_ID", ""),
		resourceGroup:    env("AZURE_RESOURCE_GROUP", ""),
		containerAppName: env("AZURE_CONTAINER_APP_NAME", ""),
		azureCredential:  credential,
	}

	if m.rconPassword == "" {
		log.Fatal("RCON_PASSWORD required")
	}

	if m.checkInterval >= m.inactivityTimeout {
		log.Fatal("CHECK_INTERVAL must be less than INACTIVITY_TIMEOUT")
	}

	log.Printf("Config: %s, check=%v, timeout=%v, method=%s", m.rconAddr, m.checkInterval, m.inactivityTimeout, m.stopMethod)
	m.run()
}

func (m *Monitor) run() {
	ticker := time.NewTicker(m.checkInterval)
	defer ticker.Stop()

	for range ticker.C {
		if err := m.check(); err != nil {
			log.Printf("Check failed: %v", err)
		}
	}
}

var playerCountRegex = regexp.MustCompile(`There are (\d+) of`)

func (m *Monitor) check() error {
	conn, err := rcon.Dial(m.rconAddr, m.rconPassword)
	if err != nil {
		return err
	}
	defer conn.Close()

	resp, err := conn.Execute("list")
	if err != nil {
		return err
	}

	// Parse player count using regex
	playerCount := 0
	if matches := playerCountRegex.FindStringSubmatch(resp); len(matches) > 1 {
		playerCount, _ = strconv.Atoi(matches[1])
	}

	if playerCount > 0 {
		m.lastPlayerTime = time.Now()
		log.Printf("%d players online", playerCount)
		return nil
	}

	empty := time.Since(m.lastPlayerTime)
	log.Printf("Empty for %v", empty)

	if empty >= m.inactivityTimeout {
		log.Printf("Stopping server after %v of inactivity", empty)
		return m.stop()
	}

	return nil
}

func (m *Monitor) stop() error {
	switch m.stopMethod {
	case "azure":
		return m.stopContainerApp()
	case "rcon":
		return m.stopViaRcon()
	case "noop":
		log.Println("Stop method is noop, doing nothing")
		return nil
	default:
		log.Printf("Unknown stop method: %s", m.stopMethod)
		return m.stopViaRcon()
	}
}

func (m *Monitor) stopViaRcon() error {
	conn, err := rcon.Dial(m.rconAddr, m.rconPassword)
	if err != nil {
		return err
	}
	defer conn.Close()

	// Warn and stop
	if _, err := conn.Execute("say Server stopping in 30s due to inactivity"); err != nil {
		log.Printf("Warning message failed: %v", err)
	}
	time.Sleep(30 * time.Second)

	_, err = conn.Execute("stop")
	if err != nil {
		return err
	}

	log.Println("Stop command sent")
	return nil
}

func (m *Monitor) stopContainerApp() error {
	// Cooldown check
	const cooldown = 2 * time.Minute
	if time.Since(m.lastStopTime) < cooldown {
		return nil
	}

	// Validate config
	if m.azureCredential == nil {
		return fmt.Errorf("Azure credentials not available")
	}
	if m.subscriptionID == "" {
		return fmt.Errorf("AZURE_SUBSCRIPTION_ID not set")
	}
	if m.resourceGroup == "" {
		return fmt.Errorf("AZURE_RESOURCE_GROUP not set")
	}
	if m.containerAppName == "" {
		return fmt.Errorf("AZURE_CONTAINER_APP_NAME not set")
	}

	// Get token
	ctx := context.Background()
	token, err := m.azureCredential.GetToken(ctx, policy.TokenRequestOptions{
		Scopes: []string{azureScope},
	})
	if err != nil {
		return fmt.Errorf("failed to get token: %v", err)
	}

	// Stop container app
	url := fmt.Sprintf("https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.App/containerApps/%s/stop?api-version=2025-01-01",
		m.subscriptionID, m.resourceGroup, m.containerAppName)

	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(1<<(attempt-1)) * time.Second)
		}

		req, err := http.NewRequest("POST", url, nil)
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+token.Token)

		resp, err := (&http.Client{}).Do(req)
		if err != nil {
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 200 && resp.StatusCode < 300 || resp.StatusCode == 409 {
			log.Println("✅ Container app stopped")
			m.lastStopTime = time.Now()
			return nil
		}

		if resp.StatusCode >= 400 && resp.StatusCode < 500 && resp.StatusCode != 409 {
			break
		}
	}

	return fmt.Errorf("stop failed")
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func duration(s string) time.Duration {
	d, err := time.ParseDuration(s)
	if err != nil {
		log.Printf("Invalid duration %q, using 30s", s)
		return 30 * time.Second
	}
	return d
}
