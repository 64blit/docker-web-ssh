#!/bin/bash
set -e

echo "=== PicoClaw + Discord + Cloudflare Tunnel Setup for Kubuntu ==="

# === Hardcoded Config ===
DISCORD_TOKEN=""
DISCORD_USER_ID=""
GEMINI_KEY=""
OPENROUTER_KEY=""
TUNNEL_NAME=""
CUSTOM_HOST="pico.yourdomain.com"
REAL_USER="nimda"
USER_HOME="/home/$REAL_USER"

# === PicoClaw configuration ===
CONFIG_DIR="$USER_HOME/.picoclaw"
CONFIG="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

cp "$USER_HOME/picoclaw/config/config.example.json" "$CONFIG"

# Use MiniMax-M2.5 via OpenRouter
jq --arg token "$DISCORD_TOKEN" \
   --arg uid "$DISCORD_USER_ID" \
   --arg orkey "$OPENROUTER_KEY" '
   .agents.defaults.model_name = "minimax" |
   .model_list = [
     {
       "model_name": "minimax",
       "model": "openai/minimax/minimax-m2.5",
       "api_key": $orkey,
       "api_base": "https://openrouter.ai/api/v1"
     }
   ] |
   .channels.discord.enabled = true |
   .channels.discord.token = $token |
   .channels.discord.allow_from = [$uid] |
   .channels.discord.mention_only = false |
   .gateway.host = "0.0.0.0" |
   .gateway.port = 18790
   ' "$CONFIG" > /tmp/config.json && mv /tmp/config.json "$CONFIG"

chown -R $REAL_USER:$REAL_USER "$CONFIG_DIR"

echo "✅ Config updated to MiniMax-M2.5 (OpenRouter)"

# === Restart Service ===
systemctl stop picoclaw || true
systemctl daemon-reload
systemctl enable --now picoclaw
echo "✅ PicoClaw service restarted"

# === Cloudflare Tunnel ===
echo "Ensuring Cloudflare Tunnel is active..."
TUNNEL_ID=$(sudo -u $REAL_USER cloudflared tunnel list | grep "$TUNNEL_NAME" | awk "{print \$1}")

if [ -z "$TUNNEL_ID" ]; then
    sudo -u $REAL_USER cloudflared tunnel create "$TUNNEL_NAME"
    TUNNEL_ID=$(sudo -u $REAL_USER cloudflared tunnel list | grep "$TUNNEL_NAME" | awk "{print \$1}")
fi

cat > "$USER_HOME/.cloudflared/config.yml" <<EOF
tunnel: $TUNNEL_ID
credentials-file: $USER_HOME/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $CUSTOM_HOST
    service: http://localhost:18790
  - service: http_status:404
EOF
chown -R $REAL_USER:$REAL_USER "$USER_HOME/.cloudflared"

echo "✅ Tunnel configured! ID = $TUNNEL_ID"
echo "🎉 SETUP COMPLETE!"
