# Use Ubuntu 24.04 (Noble) as base
FROM ubuntu:24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
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
    tmux \
    jq \
    sudo \
    supervisor \
    net-tools \
    iputils-ping \
    vim \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd (multi-arch)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        wget https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -O /usr/bin/ttyd; \
    elif [ "$ARCH" = "arm64" ]; then \
        wget https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.aarch64 -O /usr/bin/ttyd; \
    fi && \
    chmod +x /usr/bin/ttyd

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install cloudflared (multi-arch)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb; \
    elif [ "$ARCH" = "arm64" ]; then \
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb; \
    fi && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# Setup user 'nimda'
RUN useradd -m -s /bin/bash nimda && \
    echo "nimda ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER nimda
WORKDIR /home/nimda

# Create necessary directories
RUN mkdir -p /home/nimda/workspace \
    /home/nimda/.picoclaw \
    /home/nimda/.spacebot \
    /home/nimda/.cloudflared \
    /home/nimda/scripts \
    /home/nimda/skills \
    /home/nimda/config/agents

# Copy Dashboard source and static files (now in the same context)
COPY --chown=nimda:nimda _SPACE/dash/ /home/nimda/_SPACE/dash/
COPY --chown=nimda:nimda _SPACE/index.html /home/nimda/_SPACE/index.html

# Pre-compile the Go dashboard
RUN cd /home/nimda/_SPACE/dash && go build -o dashboard dashboard.go

# Install Spacebot (multi-arch, skip on arm64 since only x86_64 binary exists)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        wget https://github.com/64blit/spacebot/releases/download/v0.4.1/spacebot-v0.4.1-x86_64-unknown-linux-gnu.tar.gz && \
        tar -xzf spacebot-v0.4.1-x86_64-unknown-linux-gnu.tar.gz && \
        mv spacebot-v0.4.1-x86_64-unknown-linux-gnu/spacebot /home/nimda/spacebot && \
        rm -rf spacebot-v0.4.1-x86_64-unknown-linux-gnu* && \
        chmod +x /home/nimda/spacebot; \
    else \
        echo "Spacebot not available for $ARCH, creating stub..." && \
        echo '#!/bin/bash' > /home/nimda/spacebot && \
        echo 'echo "Spacebot not available on this architecture"; sleep infinity' >> /home/nimda/spacebot && \
        chmod +x /home/nimda/spacebot; \
    fi

# Copy Pinchtab related files
COPY --chown=nimda:nimda pinchtab_mcp.py /home/nimda/pinchtab_mcp.py

# Copy helper scripts
COPY --chown=nimda:nimda _SPACE/fix_ttyd_mouse.sh /home/nimda/_SPACE/
COPY --chown=nimda:nimda _SPACE/setup_picoclaw.sh /home/nimda/_SPACE/
COPY --chown=nimda:nimda run_cloudflared.sh /home/nimda/scripts/
COPY --chown=nimda:nimda run_spacebot.sh /home/nimda/scripts/
RUN chmod +x /home/nimda/scripts/*.sh /home/nimda/_SPACE/*.sh

# Setup Supervisor configuration
USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports: Dashboard, ttyd, code-server
EXPOSE 18790 7681 8080

ENTRYPOINT ["/entrypoint.sh"]
