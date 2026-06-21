# syntax=docker/dockerfile:1.4
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive
ENV HOSTNAME=kitty
ENV TZ=UTC
ENV PORT=10000

# --------------------------------------------------
# Base minimal system
# --------------------------------------------------
RUN apt-get update && apt-get install -y \
    openssh-server \
    curl \
    ca-certificates \
    iproute2 \
    iputils-ping \
    procps \
    fastfetch \
    nano \
    vim \
    less \
    htop \
    sudo \
    tini \
    netcat-openbsd \
    build-essential cmake libuv1-dev libssl-dev libhwloc-dev git \
    && rm -rf /var/lib/apt/lists/*

# NOTE: XMRig is NOT built here anymore. It only gets cloned/compiled
# the first time you run `kstart` inside the container. Until then,
# nothing mining-related is installed or running.

# --------------------------------------------------
# Install Tailscale (userspace)
# --------------------------------------------------
RUN mkdir -p /usr/share/keyrings && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
    | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] \
    https://pkgs.tailscale.com/stable/debian bookworm main" \
    > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && \
    apt-get install -y tailscale && \
    rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# SSH setup
# --------------------------------------------------
RUN mkdir -p /run/sshd /root/.ssh /var/run/tailscale && \
    chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    echo "root:root" | chpasswd

# --------------------------------------------------
# Shell UI
# --------------------------------------------------
RUN printf '\
clear\n\
fastfetch\n\
PS1="\\u@kitty:\\w\\$ "\
' >> /root/.bashrc

# --------------------------------------------------
# Custom aliases & helper functions
# --------------------------------------------------
RUN cat << 'BASHRC_EOF' >> /root/.bashrc

alias scpu='htop'
alias sram='free -h'
alias sdisk='df -h'
alias snet='ss -tunp'
alias stop='top'
alias suptime='uptime'

status() {
echo "=================================="
echo " Kitty System Status"
echo "=================================="
echo
echo "Hostname : $(hostname)"
echo "Uptime   : $(uptime -p)"
echo "Load     : $(cat /proc/loadavg | awk '{print $1,$2,$3}')"
echo
free -h
echo
df -h /
}

helpme() {
case "$1" in
-h|-help|--help|"")
cat << EOF

========================================
KITTY COMMANDS

System Monitoring

status      - Full system status
scpu        - CPU monitor
sram        - RAM usage
sdisk       - Disk usage
snet        - Network connections
stop        - Process viewer
suptime     - System uptime

Miner control

kstart      - Install (first run only) and start the XMRig miner
kstop       - Stop the XMRig miner
kstatus     - Show whether the miner is running + recent log lines
kitty -help - Show this menu

========================================

EOF
;;
*)
echo "Unknown option: $1"
echo "Try: helpme -h"
;;
esac
}

alias kitty='_kitty_cmd'
_kitty_cmd() {
case "$1" in
-h|-help|--help) helpme -h ;;
*) echo "Try: kitty -help" ;;
esac
}
BASHRC_EOF

# --------------------------------------------------
# Miner control script (kstart / kstop / kstatus)
# Installed but inert: does nothing until you run kstart yourself.
# --------------------------------------------------
RUN cat << 'KSCRIPT_EOF' > /usr/local/bin/kstart
#!/bin/bash
set -e
XMRIG_BIN=/opt/xmrig/build/xmrig
LOG=/var/log/kitty-worker.log
PIDFILE=/var/run/kitty-worker.pid

if [ -z "$XMR_WALLET" ]; then
  echo "[!] XMR_WALLET is not set. Pass it with -e XMR_WALLET=your_monero_address at docker run, or export it now."
  exit 1
fi

if [ ! -x "$XMRIG_BIN" ]; then
  echo "[+] First run: installing miner (this happens once)..."
  rm -rf /opt/xmrig
  git clone --quiet https://github.com/xmrig/xmrig.git /opt/xmrig
  cd /opt/xmrig && mkdir -p build && cd build
  cmake .. > /dev/null && make -j"$(nproc)" > /dev/null
  echo "[+] Install complete."
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "[!] Already running (pid $(cat "$PIDFILE"))."
  exit 0
fi

echo "[+] Starting worker..."
nohup "$XMRIG_BIN" \
  -o "${XMR_POOL:-pool.supportxmr.com:443}" \
  -u "$XMR_WALLET" \
  -p "${XMR_WORKER:-kitty-worker}" \
  -k --tls \
  --threads="${XMR_THREADS:-6}" \
  > "$LOG" 2>&1 &
echo $! > "$PIDFILE"
sleep 1
echo "[+] Worker started (pid $(cat "$PIDFILE")). Logs: $LOG"
KSCRIPT_EOF

RUN cat << 'KSTOP_EOF' > /usr/local/bin/kstop
#!/bin/bash
PIDFILE=/var/run/kitty-worker.pid
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  kill "$(cat "$PIDFILE")"
  rm -f "$PIDFILE"
  echo "[+] Worker stopped."
else
  echo "[!] Worker is not running."
fi
KSTOP_EOF

RUN cat << 'KSTATUS_EOF' > /usr/local/bin/kstatus
#!/bin/bash
PIDFILE=/var/run/kitty-worker.pid
LOG=/var/log/kitty-worker.log
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "[+] Worker running (pid $(cat "$PIDFILE"))."
else
  echo "[!] Worker is not running."
fi
if [ -f "$LOG" ]; then
  echo "---- last 10 log lines ----"
  tail -n 10 "$LOG"
fi
KSTATUS_EOF

RUN chmod +x /usr/local/bin/kstart /usr/local/bin/kstop /usr/local/bin/kstatus

# --------------------------------------------------
# Persistent directories
# --------------------------------------------------
RUN mkdir -p /data /apps
VOLUME ["/data", "/apps"]

# --------------------------------------------------
# Keepalive HTTP server
# --------------------------------------------------
RUN mkdir -p /srv && \
    printf 'require("http")\n\
.createServer((req,res)=>res.end("kitty alive\n"))\n\
.listen(process.env.PORT||10000,"0.0.0.0");\n' > /srv/keepalive.js

# --------------------------------------------------
# Expose public port
# --------------------------------------------------
EXPOSE 10000

# --------------------------------------------------
# Worker config (only used if/when you run `kstart`)
# --------------------------------------------------
ENV XMR_WALLET=""
ENV XMR_POOL="pool.supportxmr.com:443"
ENV XMR_WORKER="kitty-worker"
ENV XMR_THREADS="6"

ENTRYPOINT ["/usr/bin/tini", "--"]

# --------------------------------------------------
# Runtime — only base services. No miner auto-start.
# --------------------------------------------------
CMD sh -c '\
set -e; \
echo "[+] kitty initializing..."; \
ulimit -n 1048576 || true; \
hostname kitty || true; \
\
echo "[+] Starting SSH daemon"; \
/usr/sbin/sshd; \
\
echo "[+] Starting tailscaled"; \
tailscaled \
--tun=userspace-networking \
--state=/data/tailscale.state \
--socket=/var/run/tailscale/tailscaled.sock & \
\
sleep 4; \
\
echo "[+] Connecting to Tailscale"; \
tailscale up \
--auth-key=${TAILSCALE_AUTHKEY} \
--ssh \
--hostname=kitty \
--accept-routes \
--accept-dns=false || true; \
\
echo "[+] Starting public keepalive server on port $PORT"; \
( while true; do \
echo -e "HTTP/1.1 200 OK\r\n\r\nkitty alive" | nc -l -p $PORT -q 1; \
done ) & \
\
echo "[+] Ready. SSH in and run kstart to begin the worker."; \
tail -f /dev/null \
'
