FROM debian:12

# Update and install essentials
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    sudo \
    bash \
    xz-utils \
    ripgrep \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    openssh-server \
    openssh-client \
    netcat-openbsd \
    tmux \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js v22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install FFmpeg
RUN apt-get update \
    && apt-get install -y ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install sshx
RUN curl -sSf https://sshx.io/get | sh

# Install Hermes + all its dependencies
RUN curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash \
    && echo 'export PATH="/root/.hermes/hermes-agent/venv/bin:/root/.local/bin:$PATH"' >> /root/.bashrc

# ── SSH Setup (Properly Fixed) ─────────────────────────────
RUN mkdir -p /var/run/sshd /root/.ssh

# Generate all SSH host keys
RUN ssh-keygen -A

# Set root password
RUN echo 'root:toor' | chpasswd

# Write clean sshd_config
RUN cat > /etc/ssh/sshd_config << 'EOF'
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
ClientAliveInterval 60
ClientAliveCountMax 10
TCPKeepAlive yes
UseDNS no
X11Forwarding no
PrintMotd no
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Copy files
COPY server.py /root/server.py
COPY startup.sh /root/startup.sh
RUN chmod +x /root/startup.sh

WORKDIR /root

EXPOSE 22 8080

CMD ["/bin/bash", "/root/startup.sh"]
