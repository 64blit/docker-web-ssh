#!/bin/bash
# 64blit Dashboard Docker Setup Script (macOS + Linux)

set -e

echo "🦞 64blit Dashboard Docker Setup"
echo "================================="

# Detect OS
OS=$(uname -s)

# Check if docker is installed
if ! [ -x "$(command -v docker)" ]; then
    if [ "$OS" = "Darwin" ]; then
        echo "Docker not found. Please install Docker Desktop for Mac:"
        echo "  brew install --cask docker"
        echo "Then open Docker Desktop and run this script again."
        exit 1
    else
        echo "Docker is not installed. Installing Docker for Ubuntu..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER
        echo "✅ Docker installed! You may need to log out and back in for group changes to take effect."
    fi
fi

# Verify Docker daemon is running
if ! docker info &>/dev/null; then
    echo "⚠️  Docker daemon is not running."
    if [ "$OS" = "Darwin" ]; then
        echo "Opening Docker Desktop..."
        open -a Docker
        echo "Waiting for Docker to start..."
        for i in $(seq 1 30); do
            docker info &>/dev/null && break
            printf "."
            sleep 2
        done
        docker info &>/dev/null || { echo "\n❌ Docker failed to start. Open Docker Desktop manually and try again."; exit 1; }
        echo ""
        echo "✅ Docker is ready!"
    else
        echo "Please start the Docker daemon: sudo systemctl start docker"
        exit 1
    fi
fi

# Create data directories for persistence
mkdir -p data/picoclaw data/spacebot data/cloudflared data/workspace

# Create .env file for secrets if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file. Please fill in your keys."
    cat > .env <<EOF
DISCORD_TOKEN=your_discord_token_here
GEMINI_KEY=your_gemini_key_here
OPENROUTER_KEY=your_openrouter_key_here
START_SPACEBOT=false
# Cloudflare Tunnel Configuration
# Option A: Use a Tunnel Token (Recommended for Docker)
TUNNEL_TOKEN=
# Option B: Use Tunnel Name (requires mounting credentials in data/cloudflared)
TUNNEL_NAME=
EOF
    echo "✅ .env created! Edit it later with your real keys."
fi

# Build and start the container
echo ""
echo "Building and starting the dashboard..."
docker compose up -d --build

echo ""
echo "✅ SUCCESS! The dashboard should be starting up."
echo ""
echo "  🦞 Dashboard:  http://localhost:18790"
echo "  ⌨️  Terminal:   http://localhost:7681"
echo "  🖥️  IDE:        http://localhost:8080"
echo ""
echo "Use 'docker compose logs -f' to see the progress."
