package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
)

var faviconData string
var (
	initialReadTimeout time.Duration
	statusReadTimeout  time.Duration
	pingReadTimeout    time.Duration
)

const azureScope = "https://management.azure.com/.default"

var lastStartTime time.Time

func main() {
	listenAddr := getEnv("LISTEN_ADDR", ":25565")
	backendAddr := getEnv("BACKEND_ADDR", "minecraft-java:25565")
	motd := getEnv("MOTD", "§aMinecraft Server via Proxy")

	// Load favicon if pRrovided. Accept raw base64 in FAVICON_BASE64 or a file path in FAVICON_PATH.
	if fb := getEnv("FAVICON_BASE64", ""); fb != "" {
		// if it already includes data: prefix, keep as-is, else prepend PNG data URL
		if strings.HasPrefix(fb, "data:") {
			faviconData = fb
		} else {
			faviconData = "data:image/png;base64," + fb
		}
	} else if fp := getEnv("FAVICON_PATH", ""); fp != "" {
		if dat, err := os.ReadFile(fp); err == nil {
			faviconData = "data:image/png;base64," + base64.StdEncoding.EncodeToString(dat)
		} else {
			log.Printf("Failed to read FAVICON_PATH=%s: %v", fp, err)
		}
	}

	// Configure timeouts (ms) from environment with sensible defaults.
	initialReadMs := getEnvInt("INITIAL_READ_MS", 300)
	statusReadMs := getEnvInt("STATUS_READ_MS", 300)
	pingWaitMs := getEnvInt("PING_WAIT_MS", 300)
	initialReadTimeout = time.Duration(initialReadMs) * time.Millisecond
	statusReadTimeout = time.Duration(statusReadMs) * time.Millisecond
	pingReadTimeout = time.Duration(pingWaitMs) * time.Millisecond

	log.Printf("Starting proxy: %s -> %s", listenAddr, backendAddr)
	log.Printf("MOTD: %s", motd)
	log.Printf("timeouts: initial=%s status=%s ping=%s", initialReadTimeout, statusReadTimeout, pingReadTimeout)

	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		log.Fatal(err)
	}
	defer listener.Close()

	for {
		clientConn, err := listener.Accept()
		if err != nil {
			log.Printf("Accept error: %v", err)
			continue
		}

		go handleConnection(clientConn, backendAddr, motd)
	}
}

func handleConnection(clientConn net.Conn, backendAddr string, motd string) {
	defer clientConn.Close()

	if getEnv("DEBUG", "0") == "1" {
		log.Printf("New connection from %s", clientConn.RemoteAddr())
	}

	// Set short read timeout for initial packet so we don't block waiting for a full handshake.
	// This lets us reply to status requests much faster when the client sends them immediately.
	clientConn.SetReadDeadline(time.Now().Add(initialReadTimeout))

	// Read first packet to check if it's a status request. Time this operation for diagnostics.
	readStart := time.Now()
	packet, err := readPacket(clientConn)
	readElapsed := time.Since(readStart)
	if err != nil {
		// Many platforms (health probes, sidecars) will open TCP and close immediately.
		// Treat an immediate EOF as a probe and avoid noisy logs. Use a small threshold so
		// genuine client errors are still visible.
		if err == io.EOF && readElapsed < 50*time.Millisecond {
			return
		}
		log.Printf("Failed to read packet after %s: %v", readElapsed, err)
		return
	}
	log.Printf("Initial read took %s", readElapsed)

	// Clear the short deadline used for the initial read so future I/O isn't affected.
	clientConn.SetReadDeadline(time.Time{})

	// If it's a handshake packet (0x00), parse it to get next state and protocol
	nextState := 0
	var protocol int32
	if len(packet) > 0 && packet[0] == 0x00 {
		ns, proto, err := parseHandshake(packet)
		if err == nil {
			nextState = ns
			protocol = proto
		}
		if err == nil && nextState == 1 {
			handleStatusRequest(clientConn, motd, protocol)
			return
		}
	}

	// For all other packets, proxy to backend. Pass along the parsed nextState so we can
	// send a friendly Disconnect if the backend is unavailable during login.
	proxyToBackend(clientConn, backendAddr, packet, nextState, protocol)
}

func readPacket(conn net.Conn) ([]byte, error) {
	// Read packet length (VarInt)
	length, err := readVarInt(conn)
	if err != nil {
		return nil, err
	}

	if length <= 0 || length > 2097151 { // Max packet size
		return nil, fmt.Errorf("invalid packet length: %d", length)
	}

	// Read packet data
	packet := make([]byte, length)
	_, err = io.ReadFull(conn, packet)
	if err != nil {
		return nil, err
	}

	return packet, nil
}

func readVarInt(conn net.Conn) (int32, error) {
	var value int32
	var position int

	for {
		if position >= 5 {
			return 0, fmt.Errorf("VarInt too big")
		}

		buf := make([]byte, 1)
		_, err := conn.Read(buf)
		if err != nil {
			return 0, err
		}

		currentByte := buf[0]
		value |= int32(currentByte&0x7F) << (position * 7)

		if (currentByte & 0x80) == 0 {
			break
		}
		position++
	}

	return value, nil
}

// parseHandshake parses a handshake packet and returns nextState and protocol (protocol is VarInt)
func parseHandshake(packet []byte) (int, int32, error) {
	if len(packet) < 1 || packet[0] != 0x00 {
		return 0, 0, fmt.Errorf("not a handshake")
	}
	offset := 1

	// read protocol (VarInt)
	proto, n, err := readVarIntFromBytes(packet, offset)
	if err != nil {
		return 0, 0, err
	}
	offset += n

	// read server address (string with VarInt length)
	addrLen32, m, err := readVarIntFromBytes(packet, offset)
	if err != nil {
		return 0, 0, err
	}
	offset += m
	addrLen := int(addrLen32)
	offset += addrLen

	// skip port (2 bytes)
	offset += 2

	// read next state (VarInt)
	nextState32, _, err := readVarIntFromBytes(packet, offset)
	if err != nil {
		return 0, 0, err
	}

	return int(nextState32), proto, nil
}

// readVarIntFromBytes reads a VarInt from a byte slice starting at offset and returns the value and bytes consumed.
func readVarIntFromBytes(b []byte, offset int) (int32, int, error) {
	var value int32
	var position int
	var i int = offset
	for {
		if i >= len(b) {
			return 0, 0, fmt.Errorf("unexpected end of buffer")
		}
		current := b[i]
		value |= int32(current&0x7F) << (position * 7)
		i++
		position++
		if (current & 0x80) == 0 {
			break
		}
		if position > 5 {
			return 0, 0, fmt.Errorf("VarInt too big")
		}
	}
	return value, i - offset, nil
}

func handleStatusRequest(clientConn net.Conn, motd string, protocol int32) {
	log.Printf("Handling status request: (protocol=%d)", protocol)
	// First try to consume the client's Status Request packet (usually sent right after the handshake).
	// Use a short deadline; if not present we still continue and send the status response.
	clientConn.SetReadDeadline(time.Now().Add(statusReadTimeout))
	_, _ = readPacket(clientConn) // ignore errors (timeout or otherwise)
	// clear deadline before writing
	clientConn.SetReadDeadline(time.Time{})

	// Build status response including version.protocol so client doesn't mark server as "Old".
	statusObj := struct {
		Description struct {
			Text string `json:"text"`
		} `json:"description"`
		Players struct {
			Max    int `json:"max"`
			Online int `json:"online"`
			Sample []struct {
				Name string `json:"name"`
				ID   string `json:"id"`
			} `json:"sample,omitempty"`
		} `json:"players"`
		Favicon string `json:"favicon,omitempty"`
		Version struct {
			Name     string `json:"name"`
			Protocol int32  `json:"protocol"`
		} `json:"version"`
	}{}
	// MOTD: use value as provided (no rainbow transformation)
	statusObj.Description.Text = motd
	statusObj.Players.Online = 0
	statusObj.Players.Max = 0
	// Allow overriding player counts via environment variables
	if v := getEnv("PLAYERS_MAX", ""); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			statusObj.Players.Max = n
		} else {
			log.Printf("Invalid PLAYERS_MAX=%q: %v", v, err)
		}
	}
	if v := getEnv("PLAYERS_ONLINE", ""); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			statusObj.Players.Online = n
		} else {
			log.Printf("Invalid PLAYERS_ONLINE=%q: %v", v, err)
		}
	}
	// Optionally include a short message in the players.sample list.
	// This shows up in the client when hovering the player count. It cannot replace the numeric count
	sampleEnv := getEnv("PLAYER_SAMPLE", "")
	if sampleEnv != "" {
		// allow comma or pipe separated list
		var parts []string
		if strings.Contains(sampleEnv, "|") {
			parts = strings.Split(sampleEnv, "|")
		} else {
			parts = strings.Split(sampleEnv, ",")
		}

		// clean and collect non-empty entries
		entries := make([]string, 0, len(parts))
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p == "" {
				continue
			}
			if len(p) > 32 {
				p = p[:32]
			}
			entries = append(entries, p)
		}

		if len(entries) > 0 {
			// always randomize the order so the sample shown is different each status
			r := rand.New(rand.NewSource(time.Now().UnixNano()))
			r.Shuffle(len(entries), func(i, j int) { entries[i], entries[j] = entries[j], entries[i] })

			maxSamples := 5
			if len(entries) < maxSamples {
				maxSamples = len(entries)
			}

			samples := make([]struct {
				Name string `json:"name"`
				ID   string `json:"id"`
			}, 0, maxSamples)
			dummyID := "00000000-0000-0000-0000-000000000000"
			for i := 0; i < maxSamples; i++ {
				samples = append(samples, struct {
					Name string `json:"name"`
					ID   string `json:"id"`
				}{Name: entries[i], ID: dummyID})
			}
			statusObj.Players.Sample = samples
		}
	}
	// static version name (no rotating frame token)
	statusObj.Version.Name = fmt.Sprintf("proxy-%d", protocol)
	statusObj.Version.Protocol = protocol
	if faviconData != "" {
		statusObj.Favicon = faviconData
	}

	statusBytes, err := json.Marshal(statusObj)
	if err != nil {
		log.Printf("Failed to marshal status JSON: %v", err)
		return
	}

	var packet []byte
	packet = append(packet, 0x00)                          // Packet ID
	packet = appendVarInt(packet, int32(len(statusBytes))) // String length
	packet = append(packet, statusBytes...)                // JSON data

	writeVarInt(clientConn, int32(len(packet)))
	clientConn.Write(packet)

	// Now wait for the ping and echo it back. Use a small window so we don't artificially add seconds
	// to the client's measured latency.
	clientConn.SetReadDeadline(time.Now().Add(pingReadTimeout))
	defer clientConn.SetReadDeadline(time.Time{})

	pingPacket, err := readPacket(clientConn)
	if err != nil {
		return
	}

	if len(pingPacket) > 0 && pingPacket[0] == 0x01 {
		log.Printf("Echoing ping back to %s", clientConn.RemoteAddr())
		writeVarInt(clientConn, int32(len(pingPacket)))
		clientConn.Write(pingPacket)
	}
}

func writeVarInt(conn net.Conn, value int32) {
	for {
		temp := byte(value & 0x7F)
		value >>= 7
		if value != 0 {
			temp |= 0x80
		}
		conn.Write([]byte{temp})
		if value == 0 {
			break
		}
	}
}

func appendVarInt(data []byte, value int32) []byte {
	for {
		temp := byte(value & 0x7F)
		value >>= 7
		if value != 0 {
			temp |= 0x80
		}
		data = append(data, temp)
		if value == 0 {
			break
		}
	}
	return data
}

func proxyToBackend(clientConn net.Conn, backendAddr string, firstPacket []byte, nextState int, protocol int32) {
	// Connect to backend
	backendConn, err := net.Dial("tcp", backendAddr)
	if err != nil {
		log.Printf("Backend connection failed: %v", err)
		// If the client intended to login (nextState == 2) or play (1), send a friendly disconnect JSON
		// so the client shows a message instead of a generic network error.
		if nextState == 2 || nextState == 1 {
			message := getEnv("DISCONNECT_MESSAGE", "Uhoh spaghetti")
			sendDisconnectJSON(clientConn, message)
		}
		return
	}
	defer backendConn.Close()

	log.Printf("Proxying connection to %s", backendAddr)

	// Send the first packet to backend
	if len(firstPacket) > 0 {
		writeVarInt(backendConn, int32(len(firstPacket)))
		if _, err := backendConn.Write(firstPacket); err != nil {
			log.Printf("Write to backend failed: %v", err)
			message := getEnv("DISCONNECT_MESSAGE", "Uhoh mama-mia")
			sendDisconnectJSON(clientConn, message)
			return
		}
	}

	// Peek for any immediate backend response or immediate close. If the backend accepted TCP
	// but immediately closed/reset (common when the port is open but no Minecraft server is running),
	// the Read will return an error (not a timeout). Use a short deadline to avoid delaying normal proxies.
	backendConn.SetReadDeadline(time.Now().Add(1000 * time.Millisecond))
	buf := make([]byte, 2048)
	n, err := backendConn.Read(buf)
	// clear the deadline
	backendConn.SetReadDeadline(time.Time{})
	if err != nil {
		// If it's a timeout, the backend is simply quiet — proceed to normal proxying.
		if ne, ok := err.(net.Error); ok && ne.Timeout() {
			// continue below to normal proxying without buffered data
		} else {
			// backend closed/reset immediately — send friendly disconnect
			log.Printf("Backend connection closed immediately after connect/write: %v", err)
			message := getEnv("DISCONNECT_MESSAGE_2", "§eGet some water and try reconnecting in a minute while the server starts up!")
			sendDisconnectJSON(clientConn, message)
			startAzureContainerApp()
			return
		}
	}

	// Start proxying. If we read initial bytes from backend, prepend them back to the stream.
	if n > 0 {
		// Non-blocking: copy client->backend and backend(buffer+conn)->client
		go io.Copy(backendConn, clientConn)
		r := io.MultiReader(bytes.NewReader(buf[:n]), backendConn)
		io.Copy(clientConn, r)
		return
	}

	// No immediate data — normal bidirectional proxying
	go io.Copy(backendConn, clientConn)
	io.Copy(clientConn, backendConn)
}

func startAzureContainerApp() {
	// Cooldown to avoid rapid restarts
	const cooldown = 5 * time.Minute
	if time.Since(lastStartTime) < cooldown {
		log.Printf("startAzureContainerApp: cooldown in effect")
		return
	}

	// Read configuration from environment
	subscriptionID := getEnv("AZURE_SUBSCRIPTION_ID", "")
	resourceGroup := getEnv("AZURE_RESOURCE_GROUP", "")
	containerAppName := getEnv("AZURE_CONTAINER_APP_NAME", "")

	if subscriptionID == "" || resourceGroup == "" || containerAppName == "" {
		log.Printf("startAzureContainerApp: Azure config missing; not starting")
		return
	}

	// Acquire Azure credential and token
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Printf("startAzureContainerApp: failed to create credential: %v", err)
		return
	}

	ctx := context.Background()
	token, err := cred.GetToken(ctx, policy.TokenRequestOptions{Scopes: []string{azureScope}})
	if err != nil {
		log.Printf("startAzureContainerApp: failed to get token: %v", err)
		return
	}

	url := fmt.Sprintf("https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.App/containerApps/%s/start?api-version=2025-01-01",
		subscriptionID, resourceGroup, containerAppName)

	client := &http.Client{Timeout: 10 * time.Second}

	// Retry with exponential backoff similar to stop logic
	for attempt := 0; attempt < 3; attempt++ {
		log.Printf("startAzureContainerApp: attempt %d to start container app", attempt+1)

		if attempt > 0 {
			time.Sleep(time.Duration(1<<(attempt-1)) * time.Second)
		}

		req, err := http.NewRequestWithContext(ctx, "POST", url, nil)
		if err != nil {
			log.Printf("startAzureContainerApp: new request failed: %v", err)
			continue
		}
		req.Header.Set("Authorization", "Bearer "+token.Token)

		resp, err := client.Do(req)
		if err != nil {
			log.Printf("startAzureContainerApp: request failed (attempt %d): %v", attempt+1, err)
			continue
		}

		// Read response body for diagnostics then close
		bodyBytes, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if (resp.StatusCode >= 200 && resp.StatusCode < 300) || resp.StatusCode == 409 {
			log.Println("✅ Container app start requested")
			if len(bodyBytes) > 0 {
				log.Printf("startAzureContainerApp: response body: %s", strings.TrimSpace(string(bodyBytes)))
			}
			lastStartTime = time.Now()
			return
		}

		// Log client errors (4xx) including body to surface permission details from Azure
		if resp.StatusCode >= 400 && resp.StatusCode < 500 && resp.StatusCode != 409 {
			log.Printf("startAzureContainerApp: client error %d; body: %s; aborting", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
			break
		}

		// For other non-success statuses, log body and retry according to backoff
		if len(bodyBytes) > 0 {
			log.Printf("startAzureContainerApp: unexpected status %d; body: %s", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
		} else {
			log.Printf("startAzureContainerApp: unexpected status %d", resp.StatusCode)
		}
	}

	log.Printf("startAzureContainerApp: start failed")
}

// sendDisconnectJSON sends a login Disconnect packet containing a JSON text message.
func sendDisconnectJSON(conn net.Conn, message string) {
	// Build JSON text
	body := struct {
		Text string `json:"text"`
	}{Text: message}
	b, _ := json.Marshal(body)

	// Packet ID for Disconnect in the Login state is 0x00 (clientbound)
	// Build packet: [packet id (0x00)] [string length VarInt] [string bytes]
	var pkt []byte
	pkt = append(pkt, 0x00)
	pkt = appendVarInt(pkt, int32(len(b)))
	pkt = append(pkt, b...)

	// send length prefix and packet
	writeVarInt(conn, int32(len(pkt)))
	conn.Write(pkt)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt reads an integer environment variable, returning defaultValue if unset or invalid.
func getEnvInt(key string, defaultValue int) int {
	if v := os.Getenv(key); v != "" {
		n, err := strconv.Atoi(v)
		if err == nil {
			return n
		}
	}
	return defaultValue
}
