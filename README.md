# 🦞 64blit Dashboard Docker Project

This project provides a complete, containerized installation of the 64blit pro web dashboard and its associated services.

## 🚀 Features
- **Pro Dashboard (Go):** Unified interface for all tools.
- **Spacebot (Gateway):** OpenClaw/PicoClaw agent for automation.
- **Pinchtab:** Integrated browser automation and profile management.
- **Terminal (ttyd):** Full-featured web terminal with tmux persistence.
- **IDE (code-server):** Visual Studio Code in the browser.
- **Live Stream:** High-performance MJPEG over WebSocket with synchronized audio (Linux host only).
- **Cross-Platform Support:** Optimized for Linux (Physical Mirror) and Windows/macOS (Terminal/IDE focus).
- **Mobile Optimized:** Touch dragging and virtual keyboard support for tablet/phone access.

## 🛠️ Quick Start

### 🐧 On Linux (Ubuntu/Debian) - Physical Mirror Mode
To capture and mirror your physical HDMI display (`:0`):
1.  **Configure environment:** Edit `.env` with your tokens.
2.  **Start:**
    ```bash
    docker compose up -d
    ```

### 🪟 On Windows (Docker Desktop) - Terminal Mode
To run the dashboard services (Terminal, IDE, Spacebot) on Windows:
1.  **Configure environment:** Edit `.env` with your tokens.
2.  **Start:**
    ```bash
    docker compose -f docker-compose.windows.yml up -d
    ```
    *Note: The "Live" tab will be unavailable on Windows as it requires a native Linux X11 display.*

## 📂 Architecture
The project uses a single-container approach managed by **Supervisor**.

| Port | Service | Description |
|---|---|---|
| 18790 | Dashboard | The main control center (root) |
| 7681 | ttyd | Dedicated terminal port |
| 8080 | IDE | VS Code / code-server |

## ⚙️ Persistence
Data is persisted in the following local directories:
- `data/picoclaw`: Agent configuration and settings.
- `data/spacebot`: Agent data and memory.
- `data/cloudflared`: Cloudflare Tunnel credentials and config.

## 📱 Mobile Support
- **Touch**: Drag windows and interact with the desktop directly via touch.
- **Keyboard**: Use the "KEYBOARD" button in the Live tab to trigger your mobile's native keyboard for typing.
- **Scrolling**: Supports scroll wheels and touchpad gestures (two-finger scroll).

## ☁️ Cloudflare Tunnel Setup
1.  **Tunnel Token**: Paste your `TUNNEL_TOKEN` from Cloudflare Zero Trust into the `.env` file.
2.  **Access**: Access via `pico.kingdomcraft.io` (or your configured domain).

## 🔧 Maintenance
- **View Logs:** `docker compose logs -f`
- **Restart All:** `docker compose restart`
- **Update Image:** `docker compose build --no-cache && docker compose up -d`
