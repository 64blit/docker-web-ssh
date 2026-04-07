# Use Ubuntu 24.04 (Noble) as base
FROM ubuntu:24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
# Added: xvfb, lxde-core, xterm for self-contained desktop fallback
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    golang-go \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    ffmpeg \
    xdotool \
    x11-utils \
    xvfb \
    lxde-core \
    xterm \
    tmux \
    jq \
    sudo \
    supervisor \
    net-tools \
    iputils-ping \
    vim \
    unzip \
    libpulse0 \
    pulseaudio-utils \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd
RUN wget https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -O /usr/bin/ttyd \
    && chmod +x /usr/bin/ttyd

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install cloudflared
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# Setup user 'nimda'
RUN useradd -m -s /bin/bash nimda && \
    echo "nimda ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER nimda
WORKDIR /home/nimda

# Create necessary directories
RUN mkdir -p /home/nimda/_SPACE/dash/static \
    /home/nimda/.picoclaw \
    /home/nimda/.spacebot \
    /home/nimda/.cloudflared \
    /home/nimda/scripts \
    /home/nimda/skills \
    /home/nimda/config/agents

# Copy Dashboard source and static files
COPY --chown=nimda:nimda _SPACE/dash/dashboard.go /home/nimda/_SPACE/dash/
COPY --chown=nimda:nimda _SPACE/dash/static/ /home/nimda/_SPACE/dash/static/
COPY --chown=nimda:nimda _SPACE/index.html /home/nimda/_SPACE/index.html

# Pre-compile the Go dashboard
RUN cd /home/nimda/_SPACE/dash && go build -o dashboard dashboard.go

# Copy Spacebot (Assuming it exists in the build context)
COPY --chown=nimda:nimda spacebot-v0.3.3-x86_64-unknown-linux-gnu/spacebot /home/nimda/spacebot

# Copy Pinchtab related files
COPY --chown=nimda:nimda pinchtab_mcp.py /home/nimda/pinchtab_mcp.py

# Copy helper scripts
COPY --chown=nimda:nimda _SPACE/fix_ttyd_mouse.sh /home/nimda/_SPACE/
COPY --chown=nimda:nimda _SPACE/setup_picoclaw.sh /home/nimda/_SPACE/

# Setup Supervisor configuration
USER root
COPY docker-project/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Entrypoint script
COPY docker-project/entrypoint.sh /entrypoint.sh
COPY docker-project/run_cloudflared.sh /usr/local/bin/run_cloudflared.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/run_cloudflared.sh

# Expose the main dashboard port
EXPOSE 18790

# Environmental setup for X11/PulseAccess
ENV DISPLAY=:0
ENV XAUTHORITY=/home/nimda/.Xauthority
ENV XDG_RUNTIME_DIR=/run/user/1000

ENTRYPOINT ["/entrypoint.sh"]
