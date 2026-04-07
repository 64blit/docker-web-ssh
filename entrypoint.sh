#!/bin/bash
set -e

# Ensure XAUTHORITY is set (even if empty, prevents some app crashes)
export XAUTHORITY=/home/nimda/.Xauthority
if [ ! -f "$XAUTHORITY" ]; then
    touch $XAUTHORITY
fi
sudo chown nimda:nimda $XAUTHORITY

# Detect if we should use virtual X server (headless/Generic Linux)
# or if we are mirroring a host :0 (standard Linux setup)
if [ "$VIRTUAL_DESKTOP" = "true" ]; then
    echo "Starting virtual desktop environment (Xvfb + LXDE)..."
    # Clear any old X11 locks
    sudo rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
    if [ ! -e /tmp/.X11-unix/X0 ]; then
        Xvfb :0 -screen 0 1920x1080x24 &
        sleep 2
    fi
    DISPLAY=:0 lxsession -s LXDE -e LXDE &
else
    echo "Virtual Desktop disabled. Focusing on Terminal (ttyd) and IDE services."
fi

# Ensure XDG_RUNTIME_DIR exists for PulseAudio
export XDG_RUNTIME_DIR=/run/user/$(id -u)
sudo mkdir -p $XDG_RUNTIME_DIR
sudo chown -R nimda:nimda $XDG_RUNTIME_DIR

# Start supervisord to manage all processes
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
