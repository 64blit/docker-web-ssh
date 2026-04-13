#!/bin/bash
set -e

# Update ttyd service with VERY LARGE FONT (40px) and padding for high-res/mobile
cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=TTYD Persistent Web Terminal with Mouse Support
After=network.target

[Service]
User=nimda
# fontSize=40 ensures it's readable on high-res displays
# padding=40 prevents text from touching screen edges
ExecStart=/usr/bin/ttyd -p 7681 -t enableMouse=true -t fontSize=40 -t padding=40 -W tmux new -A -s main
Restart=always
RestartSec=5
WorkingDirectory=/home/nimda
Environment=HOME=/home/nimda

[Install]
WantedBy=multi-user.target
EOF

# Reload and restart
systemctl daemon-reload
systemctl restart ttyd
