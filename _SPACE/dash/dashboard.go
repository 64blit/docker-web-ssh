package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func RunShell(command string) string {
	cmd := exec.Command("bash", "-c", command)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Sprintf("Error: %v, Output: %s", err, string(out))
	}
	return string(out)
}

func getXAuth() string {
	return "/home/nimda/.Xauthority"
}

type InputMessage struct {
	Action string `json:"action"`
	X      string `json:"x"`
	Y      string `json:"y"`
	Button string `json:"button"`
	Key    string `json:"key"`
}

func handleLiveWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Upgrade error: %v", err)
		return
	}
	defer conn.Close()

	fps := r.URL.Query().Get("fps")
	if fps == "" { fps = "20" }
	scale := r.URL.Query().Get("scale")
	if scale == "" { scale = "1280x720" }
	quality := r.URL.Query().Get("q")
	if quality == "" { quality = "5" }

	xauth := getXAuth()
	cmd := exec.Command("ffmpeg",
		"-f", "x11grab",
		"-video_size", "1920x1080",
		"-framerate", fps,
		"-probesize", "32",
		"-i", ":0",
		"-vf", "scale="+scale,
		"-vcodec", "mjpeg",
		"-q:v", quality,
		"-f", "mpjpeg",
		"-boundary_tag", "frame",
		"-")

	log.Printf("Starting FFmpeg: %v", cmd.Args)

	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, "XAUTHORITY="+xauth)
	cmd.Env = append(cmd.Env, "DISPLAY=:0")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("StdoutPipe error: %v", err)
		return
	}
	
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Printf("StderrPipe error: %v", err)
		return
	}

	if err := cmd.Start(); err != nil {
		log.Printf("Start error: %v", err)
		return
	}
	
	// Log stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			log.Printf("FFmpeg Stderr: %s", scanner.Text())
		}
	}()
	
	// Ensure we wait for the process to avoid zombies
	go func() {
		err := cmd.Wait()
		log.Printf("FFmpeg process exited: %v", err)
	}()

	// Goroutine to read input messages from WebSocket
	stopChan := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer close(stopChan)
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Printf("WebSocket ReadMessage error: %v", err)
				return
			}
			var input InputMessage
			if err := json.Unmarshal(message, &input); err != nil {
				continue
			}
			handleInputLogic(input)
		}
	}()

	// Read MJPEG stream and push frames to WebSocket
	frameChan := make(chan []byte, 5) // Buffer a few frames
	
	// Reader goroutine
	go func() {
		defer close(frameChan)
		reader := bufio.NewReader(stdout)
		for {
			// Find SOI (0xFF 0xD8)
			for {
				b, err := reader.ReadByte()
				if err != nil {
					return
				}
				if b == 0xFF {
					b2, err := reader.ReadByte()
					if err != nil {
						return
					}
					if b2 == 0xD8 {
						break
					}
				}
			}

			// We found SOI, now capture everything until EOI (0xFF 0xD9)
			frame := []byte{0xFF, 0xD8}
			for {
				b, err := reader.ReadByte()
				if err != nil {
					return
				}
				frame = append(frame, b)
				if b == 0xFF {
					b2, err := reader.ReadByte()
					if err != nil {
						return
					}
					frame = append(frame, b2)
					if b2 == 0xD9 {
						break
					}
					// If we see 0xFF 0xFF, the second 0xFF might be the start of EOI
					for b2 == 0xFF {
						b2, err = reader.ReadByte()
						if err != nil {
							return
						}
						frame = append(frame, b2)
						if b2 == 0xD9 {
							goto foundEOI
						}
					}
				}
				if len(frame) > 5*1024*1024 { break }
			}
			foundEOI:

			select {
			case frameChan <- frame:
			default:
				// Drop frame if consumer is slow
			}
		}
	}()

	// Writer loop
	for {
		select {
		case <-stopChan:
			log.Printf("WebSocket stopChan closed, exiting loop")
			cmd.Process.Kill()
			return
		case frame, ok := <-frameChan:
			if !ok {
				log.Printf("frameChan closed")
				cmd.Process.Kill()
				return
			}
			if err := conn.WriteMessage(websocket.BinaryMessage, frame); err != nil {
				log.Printf("WS Write error: %v", err)
				cmd.Process.Kill()
				return
			}
		}
	}
}

func handleInputLogic(input InputMessage) {
	var cmdArgs []string
	switch input.Action {
	case "move":
	        cmdArgs = []string{"mousemove", input.X, input.Y}
	case "rel_move":
	        cmdArgs = []string{"mousemove_relative", "--", input.X, input.Y}
	case "click":

		button := input.Button
		if button == "" { button = "1" }
		cmdArgs = []string{"mousemove", input.X, input.Y, "click", button}
	case "mousedown":
		button := input.Button
		if button == "" { button = "1" }
		cmdArgs = []string{"mousemove", input.X, input.Y, "mousedown", button}
	case "mouseup":
		button := input.Button
		if button == "" { button = "1" }
		cmdArgs = []string{"mousemove", input.X, input.Y, "mouseup", button}
	case "doubleclick":
		button := input.Button
		if button == "" { button = "1" }
		cmdArgs = []string{"mousemove", input.X, input.Y, "click", "--repeat", "2", "--delay", "50", button}
	case "type":
		cmdArgs = []string{"type", "--delay", "10", input.Key}
	case "key":
		cmdArgs = []string{"key", input.Key}
	case "scroll":
		// input.Y will contain the delta. xdotool uses button 4 (up) and 5 (down).
		button := "4" // Up
		delta := 0
		fmt.Sscanf(input.Y, "%d", &delta)
		if delta > 0 {
			button = "5" // Down
		}
		// Convert delta to absolute for iteration or just click once
		cmdArgs = []string{"click", button}
	default:
		return
	}

	xauth := getXAuth()
	cmd := exec.Command("xdotool", cmdArgs...)
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, "DISPLAY=:0", "XAUTHORITY="+xauth)
	cmd.Run()
}

func main() {
	mux := http.NewServeMux()

	spacebotURL, _ := url.Parse("http://127.0.0.1:19898")
	spacebotProxy := httputil.NewSingleHostReverseProxy(spacebotURL)
	spacebotProxy.FlushInterval = -1
	spacebotProxy.Director = func(req *http.Request) {
		req.URL.Scheme = spacebotURL.Scheme
		req.URL.Host = spacebotURL.Host
		origHost := req.Host
		req.Host = spacebotURL.Host
		req.Header.Set("X-Forwarded-Host", origHost)
		req.Header.Set("X-Forwarded-Proto", "https")
		req.Header.Set("X-Forwarded-For", req.RemoteAddr)
		if strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
			req.Header.Set("Connection", "Upgrade")
		}
	}

	pinchtabURL, _ := url.Parse("http://127.0.0.1:9867")
	pinchProxy := httputil.NewSingleHostReverseProxy(pinchtabURL)
	pinchProxy.FlushInterval = -1
	pinchProxy.Director = func(req *http.Request) {
		req.URL.Scheme = pinchtabURL.Scheme
		req.URL.Host = pinchtabURL.Host
		req.Host = pinchtabURL.Host
		if strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
			req.Header.Set("Connection", "Upgrade")
		}
	}

	ttydURL, _ := url.Parse("http://127.0.0.1:7681")
	ttydProxy := httputil.NewSingleHostReverseProxy(ttydURL)
	ttydProxy.FlushInterval = -1
	ttydProxy.Director = func(req *http.Request) {
		req.URL.Scheme = ttydURL.Scheme
		req.URL.Host = ttydURL.Host
		req.Host = ttydURL.Host
		if strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
			req.Header.Set("Connection", "Upgrade")
			req.Header.Set("Upgrade", "websocket")
		}
	}

	ideURL, _ := url.Parse("http://127.0.0.1:8080")
	ideProxy := httputil.NewSingleHostReverseProxy(ideURL)
	ideProxy.FlushInterval = -1
	ideProxy.Director = func(req *http.Request) {
		req.URL.Scheme = ideURL.Scheme
		req.URL.Host = ideURL.Host
		origHost := req.Host
		req.Host = ideURL.Host
		req.Header.Set("X-Forwarded-Host", origHost)
		req.Header.Set("X-Forwarded-Proto", "https")
		req.Header.Set("X-Forwarded-For", req.RemoteAddr)
		if strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
			req.Header.Set("Connection", "Upgrade")
			req.Header.Set("Upgrade", "websocket")
		}
	}

	wrap := func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			log.Printf("Req: %s %s %s", r.RemoteAddr, r.Method, r.URL.Path)
			w.Header().Set("Permissions-Policy", "interest-cohort=(), browsing-topics=(), run-ad-auction=(), join-ad-interest-group=(), attribution-reporting=()")
			h.ServeHTTP(w, r)
		})
	}

	terminalHandler := func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/terminal" || r.URL.Path == "/terminal/" || r.URL.Path == "/terminal/index.html" {
			http.ServeFile(w, r, "/home/nimda/_SPACE/dash/static/terminal/index.html")
			return
		}
		r.URL.Path = "/ttyd" + strings.TrimPrefix(r.URL.Path, "/terminal")
		ttydProxy.ServeHTTP(w, r)
	}

	mux.HandleFunc("/api/live/audio", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Audio stream requested from %s", r.RemoteAddr)
		w.Header().Set("Content-Type", "audio/mpeg")
		w.Header().Set("Connection", "keep-alive")

		// Source: alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
		cmd := exec.Command("ffmpeg",
			"-f", "pulse",
			"-i", "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor",
			"-acodec", "libmp3lame",
			"-ab", "128k",
			"-f", "mp3",
			"pipe:1")

		log.Printf("Starting Audio FFmpeg: %v", cmd.Args)
		cmd.Env = os.Environ()

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			log.Printf("Audio StdoutPipe error: %v", err)
			return
		}

		if err := cmd.Start(); err != nil {
			log.Printf("Audio Start error: %v", err)
			return
		}
		defer cmd.Process.Kill()

		n, err := io.Copy(w, stdout)
		log.Printf("Audio stream finished after %d bytes, err: %v", n, err)
	})

	mux.Handle("/api/live/ws", wrap(http.HandlerFunc(handleLiveWS)))

	mux.HandleFunc("/api/agents/avatar", func(w http.ResponseWriter, r *http.Request) {
		agentID := r.URL.Query().Get("agent_id")
		if agentID == "" {
			// Try to extract from path if proxying /avatar/{id}
			parts := strings.Split(r.URL.Path, "/")
			if len(parts) >= 4 && parts[1] == "api" && parts[2] == "agents" && parts[3] == "avatar" && len(parts) > 4 {
				agentID = parts[4]
			}
		}
		if agentID == "" {
			agentID = "main"
		}

		// If meta=1 is requested, return JSON with the avatar URL
		if r.URL.Query().Get("meta") == "1" {
			w.Header().Set("Content-Type", "application/json")
			// We point back to this same endpoint without the meta=1 param
			avatarUrl := fmt.Sprintf("/api/agents/avatar?agent_id=%s", agentID)
			json.NewEncoder(w).Encode(map[string]string{"avatarUrl": avatarUrl})
			return
		}

		// Try to serve a local avatar file if it exists
		avatarPath := fmt.Sprintf("/home/nimda/config/agents/%s/avatar.png", agentID)
		if _, err := os.Stat(avatarPath); err == nil {
			http.ServeFile(w, r, avatarPath)
			return
		}

		// Fallback to a default SVG avatar
		w.Header().Set("Content-Type", "image/svg+xml")
		w.Header().Set("Cache-Control", "public, max-age=3600")
		fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
			<rect width="100" height="100" rx="20" fill="#16161a"/>
			<text x="50" y="70" font-size="60" text-anchor="middle">🤖</text>
		</svg>`)
	})

	// Also handle /avatar/ path used by some components
	mux.HandleFunc("/avatar/", func(w http.ResponseWriter, r *http.Request) {
		agentID := strings.TrimPrefix(r.URL.Path, "/avatar/")
		if agentID == "" {
			agentID = "main"
		}
		
		// Redirect to the canonical API endpoint
		newURL := fmt.Sprintf("/api/agents/avatar?agent_id=%s", agentID)
		if r.URL.RawQuery != "" {
			newURL += "&" + r.URL.RawQuery
		}
		http.Redirect(w, r, newURL, http.StatusTemporaryRedirect)
	})

	mux.HandleFunc("/api/system/config", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"terminal_font_size":"16"}`)
	})

	mux.HandleFunc("/api/system/restart", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		cmd := "/home/nimda/.picoclaw/bin/sudo systemctl --user restart spacebot"
		RunShell(cmd)
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Spacebot restarted successfully")
	})

	mux.Handle("/profiles/", wrap(pinchProxy))
	mux.Handle("/profiles", wrap(pinchProxy))
	mux.Handle("/instances/", wrap(pinchProxy))
	mux.Handle("/instances", wrap(pinchProxy))
	mux.Handle("/tabs", wrap(pinchProxy))
	mux.Handle("/health", wrap(pinchProxy))

	mux.Handle("/live", wrap(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "/home/nimda/_SPACE/dash/static/live.html")
	})))
	mux.Handle("/live/", wrap(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "/home/nimda/_SPACE/dash/static/live.html")
	})))
	mux.Handle("/agents/", wrap(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "/home/nimda/_SPACE/dash/static/index.html")
	})))
	mux.Handle("/agents", wrap(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "/home/nimda/_SPACE/dash/static/index.html")
	})))

	rootHandler := func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" && r.URL.Query().Get("ui") == "" {
			http.ServeFile(w, r, "/home/nimda/_SPACE/index.html")
			return
		}
		if strings.HasPrefix(r.URL.Path, "/terminal") {
			terminalHandler(w, r)
			return
		}
		spacebotProxy.ServeHTTP(w, r)
	}
	mux.Handle("/", wrap(http.HandlerFunc(rootHandler)))

	uiHandler := func(w http.ResponseWriter, r *http.Request) {
		r.URL.Path = strings.TrimPrefix(r.URL.Path, "/ui")
		if !strings.HasPrefix(r.URL.Path, "/") {
			r.URL.Path = "/" + r.URL.Path
		}
		spacebotProxy.ServeHTTP(w, r)
	}
	mux.Handle("/ui", wrap(http.HandlerFunc(uiHandler)))
	mux.Handle("/ui/", wrap(http.HandlerFunc(uiHandler)))

	browserHandler := func(w http.ResponseWriter, r *http.Request) {
		r.URL.Path = strings.TrimPrefix(r.URL.Path, "/browser")
		if r.URL.Path == "" || r.URL.Path == "/" {
			r.URL.Path = "/dashboard"
		}
		pinchProxy.ServeHTTP(w, r)
	}
	mux.Handle("/browser", wrap(http.HandlerFunc(browserHandler)))
	mux.Handle("/browser/", wrap(http.HandlerFunc(browserHandler)))

	mux.Handle("/dashboard/", wrap(pinchProxy))

	mux.Handle("/ide/", wrap(http.StripPrefix("/ide", ideProxy)))
	mux.Handle("/ide", wrap(http.StripPrefix("/ide", ideProxy)))
	mux.Handle("/_static/", wrap(ideProxy))
	mux.Handle("/stable-", wrap(ideProxy))
	mux.Handle("/manifest.json", wrap(ideProxy))
	mux.Handle("/favicon.ico", wrap(ideProxy))
	mux.Handle("/remote/", wrap(ideProxy))
	mux.Handle("/vscode-remote/", wrap(ideProxy))
	mux.Handle("/update/", wrap(ideProxy))

	mux.Handle("/ttyd/", wrap(ttydProxy))

	fmt.Println("Dashboard server starting on :18790 (Spacebot + HDMI Stream + WebSocket mode)")
	log.Fatal(http.ListenAndServe(":18790", mux))
}
