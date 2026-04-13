#!/bin/bash
# Wrapper to run cloudflared within Supervisor

if [ -n "$TUNNEL_TOKEN" ]; then
    echo "Starting Cloudflare Tunnel with TOKEN..."
    exec cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN"
elif [ -n "$TUNNEL_NAME" ]; then
    echo "Starting Cloudflare Tunnel with NAME: $TUNNEL_NAME"
    # Assumes credentials and config are in ~/.cloudflared/
    exec cloudflared tunnel --no-autoupdate run "$TUNNEL_NAME"
else
    echo "Cloudflare Tunnel not configured. Skipping."
    # Stay alive to prevent supervisor from restarting it too quickly
    sleep infinity
fi
