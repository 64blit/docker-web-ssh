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
| 18790 | Unified Dash | The main control center (Terminal, IDE, Live, AI) |
| 7681 | ttyd | Backend terminal service (proxied) |
| 8080 | IDE | VS Code backend (proxied) |

## ⚙️ Persistence
Data is persisted in the following local directories:
- `data/picoclaw`: Agent configuration and settings.
- `data/spacebot`: Agent data and memory.
- `data/cloudflared`: Cloudflare Tunnel credentials and config.

## 📱 Mobile Support
- **Touch**: Drag windows and interact with the desktop directly via touch.
- **Keyboard**: Use the "KEYBOARD" button in the Live tab to trigger your mobile's native keyboard for typing.
- **Scrolling**: Supports scroll wheels and touchpad gestures (two-finger scroll).

## ☁️ Cloudflare Zero Trust Setup
To expose your dashboard securely over the public internet, use a Cloudflare Tunnel. This removes the need to open ports on your router or handle SSL certificates manually.

### 1. Create a Tunnel (Cloudflare Dashboard)
1.  Log in to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/).
2.  Navigate to **Networks** -> **Tunnels**.
3.  Click **Create a tunnel**.
4.  Choose **Cloudflared** as your connector and give it a name (e.g., `my-dashboard`).
5.  On the **Install and run a connector** page, select **Docker**.
6.  Copy the **Tunnel Token** (the long string of alphanumeric characters after `--token`).

### 2. Configure the Tunnel
1.  Open your `.env` file in the project root.
2.  Paste your token into `TUNNEL_TOKEN`:
    ```bash
    TUNNEL_TOKEN=your_token_here
    ```
3.  Restart your services:
    ```bash
    docker compose up -d
    ```

### 3. Connect to a Domain
1.  Back in the Cloudflare Dashboard, go to the **Public Hostname** tab for your tunnel.
2.  Click **Add a public hostname**.
3.  **Domain/Subdomain**: Enter the domain or subdomain you want to use (e.g., `pico.kingdomcraft.io`).
4.  **Service Type**: `HTTP`
5.  **URL**: `localhost:18790` (or `http://localhost:18790`)
6.  Click **Save hostname**.

### 4. Enable Zero Trust Access (Optional but Recommended)
To prevent unauthorized access, add an Access Policy:
1.  Navigate to **Access** -> **Applications**.
2.  Click **Add an application** -> **Self-hosted**.
3.  **Application Name**: `Dashboard`
4.  **Domain**: Same as step 3 (e.g., `pico.kingdomcraft.io`).
5.  In the **Policies** tab, create a rule (e.g., Allow emails ending in `@yourdomain.com`).
6.  Now, when you visit your domain, Cloudflare will prompt for authentication (e.g., One-Time PIN via email) before showing the dashboard.

## 🔧 Maintenance
- **View Logs:** `docker compose logs -f`
- **Restart All:** `docker compose restart`
- **Update Image:** `docker compose build --no-cache && docker compose up -d`
