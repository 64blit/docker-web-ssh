#!/bin/bash
set -e

# Ensure runtime directories exist
export XDG_RUNTIME_DIR=/run/user/$(id -u nimda)
sudo mkdir -p $XDG_RUNTIME_DIR
sudo chown -R nimda:nimda $XDG_RUNTIME_DIR

echo "🦞 64blit Dashboard starting up..."

# Start supervisord to manage all processes
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
