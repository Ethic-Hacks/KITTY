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
    nodejs \
    npm \
    netcat-openbsd \
    build-essential cmake libuv1-dev libssl-dev libhwloc-dev git \
    && rm -rf /var/lib/apt/lists/*

# NOTE: XMRig is NOT built here. It only gets cloned/compiled the
# first time you run `kstart` inside the container.

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
# Custom aliases & helper functions (base64-decoded, no heredoc)
# --------------------------------------------------
RUN echo "CmFsaWFzIHNjcHU9J2h0b3AnCmFsaWFzIHNyYW09J2ZyZWUgLWgnCmFsaWFzIHNkaXNrPSdkZiAtaCcKYWxpYXMgc25ldD0nc3MgLXR1bnAnCmFsaWFzIHN0b3A9J3RvcCcKYWxpYXMgc3VwdGltZT0ndXB0aW1lJwoKc3RhdHVzKCkgewplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICIgS2l0dHkgU3lzdGVtIFN0YXR1cyIKZWNobyAiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSIKZWNobwplY2hvICJIb3N0bmFtZSA6ICQoaG9zdG5hbWUpIgplY2hvICJVcHRpbWUgICA6ICQodXB0aW1lIC1wKSIKZWNobyAiTG9hZCAgICAgOiAkKGNhdCAvcHJvYy9sb2FkYXZnIHwgYXdrICd7cHJpbnQgJDEsJDIsJDN9JykiCmVjaG8KZnJlZSAtaAplY2hvCmRmIC1oIC8KfQoKaGVscG1lKCkgewpjYXNlICIkMSIgaW4KLWh8LWhlbHB8LS1oZWxwfCIiKQpjYXQgPDwgRU9GCgo9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CktJVFRZIENPTU1BTkRTCgpTeXN0ZW0gTW9uaXRvcmluZwoKc3RhdHVzICAgICAgLSBGdWxsIHN5c3RlbSBzdGF0dXMKc2NwdSAgICAgICAgLSBDUFUgbW9uaXRvcgpzcmFtICAgICAgICAtIFJBTSB1c2FnZQpzZGlzayAgICAgICAtIERpc2sgdXNhZ2UKc25ldCAgICAgICAgLSBOZXR3b3JrIGNvbm5lY3Rpb25zCnN0b3AgICAgICAgIC0gUHJvY2VzcyB2aWV3ZXIKc3VwdGltZSAgICAgLSBTeXN0ZW0gdXB0aW1lCgpNaW5lciBjb250cm9sCgprc3RhcnQgICAgICAtIEluc3RhbGwgKGZpcnN0IHJ1biBvbmx5KSBhbmQgc3RhcnQgdGhlIFhNUmlnIG1pbmVyCmtzdG9wICAgICAgIC0gU3RvcCB0aGUgWE1SaWcgbWluZXIKa3N0YXR1cyAgICAgLSBTaG93IHdoZXRoZXIgdGhlIG1pbmVyIGlzIHJ1bm5pbmcgKyByZWNlbnQgbG9nIGxpbmVzCmtpdHR5IC1oZWxwIC0gU2hvdyB0aGlzIG1lbnUKCj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCkVPRgo7OwoqKQplY2hvICJVbmtub3duIG9wdGlvbjogJDEiCmVjaG8gIlRyeTogaGVscG1lIC1oIgo7Owplc2FjCn0KCmFsaWFzIGtpdHR5PSdfa2l0dHlfY21kJwpfa2l0dHlfY21kKCkgewpjYXNlICIkMSIgaW4KLWh8LWhlbHB8LS1oZWxwKSBoZWxwbWUgLWggOzsKKikgZWNobyAiVHJ5OiBraXR0eSAtaGVscCIgOzsKZXNhYwp9Cg==" | base64 -d >> /root/.bashrc

# --------------------------------------------------
# Miner control scripts (base64-decoded, no heredoc)
# Installed but inert: do nothing until you run kstart yourself.
# --------------------------------------------------
RUN echo "IyEvYmluL2Jhc2gKc2V0IC1lClhNUklHX0JJTj0vb3B0L3htcmlnL2J1aWxkL3htcmlnCkxPRz0vdmFyL2xvZy9raXR0eS13b3JrZXIubG9nClBJREZJTEU9L3Zhci9ydW4va2l0dHktd29ya2VyLnBpZAoKaWYgWyAteiAiJFhNUl9XQUxMRVQiIF07IHRoZW4KICBlY2hvICJbIV0gWE1SX1dBTExFVCBpcyBub3Qgc2V0LiBQYXNzIGl0IHdpdGggLWUgWE1SX1dBTExFVD15b3VyX21vbmVyb19hZGRyZXNzIGF0IGRvY2tlciBydW4sIG9yIGV4cG9ydCBpdCBub3cuIgogIGV4aXQgMQpmaQoKaWYgWyAhIC14ICIkWE1SSUdfQklOIiBdOyB0aGVuCiAgZWNobyAiWytdIEZpcnN0IHJ1bjogaW5zdGFsbGluZyBtaW5lciAodGhpcyBoYXBwZW5zIG9uY2UpLi4uIgogIHJtIC1yZiAvb3B0L3htcmlnCiAgZ2l0IGNsb25lIC0tcXVpZXQgaHR0cHM6Ly9naXRodWIuY29tL3htcmlnL3htcmlnLmdpdCAvb3B0L3htcmlnCiAgY2QgL29wdC94bXJpZyAmJiBta2RpciAtcCBidWlsZCAmJiBjZCBidWlsZAogIGNtYWtlIC4uID4gL2Rldi9udWxsICYmIG1ha2UgLWoiJChucHJvYykiID4gL2Rldi9udWxsCiAgZWNobyAiWytdIEluc3RhbGwgY29tcGxldGUuIgpmaQoKaWYgWyAtZiAiJFBJREZJTEUiIF0gJiYga2lsbCAtMCAiJChjYXQgIiRQSURGSUxFIikiIDI+L2Rldi9udWxsOyB0aGVuCiAgZWNobyAiWyFdIEFscmVhZHkgcnVubmluZyAocGlkICQoY2F0ICIkUElERklMRSIpKS4iCiAgZXhpdCAwCmZpCgplY2hvICJbK10gU3RhcnRpbmcgd29ya2VyLi4uIgpub2h1cCAiJFhNUklHX0JJTiIgXAogIC1vICIke1hNUl9QT09MOi1wb29sLnN1cHBvcnR4bXIuY29tOjQ0M30iIFwKICAtdSAiJFhNUl9XQUxMRVQiIFwKICAtcCAiJHtYTVJfV09SS0VSOi1raXR0eS13b3JrZXJ9IiBcCiAgLWsgLS10bHMgXAogIC0tdGhyZWFkcz0iJHtYTVJfVEhSRUFEUzotNn0iIFwKICA+ICIkTE9HIiAyPiYxICYKZWNobyAkISA+ICIkUElERklMRSIKc2xlZXAgMQplY2hvICJbK10gV29ya2VyIHN0YXJ0ZWQgKHBpZCAkKGNhdCAiJFBJREZJTEUiKSkuIExvZ3M6ICRMT0ciCg==" | base64 -d > /usr/local/bin/kstart

RUN echo "IyEvYmluL2Jhc2gKUElERklMRT0vdmFyL3J1bi9raXR0eS13b3JrZXIucGlkCmlmIFsgLWYgIiRQSURGSUxFIiBdICYmIGtpbGwgLTAgIiQoY2F0ICIkUElERklMRSIpIiAyPi9kZXYvbnVsbDsgdGhlbgogIGtpbGwgIiQoY2F0ICIkUElERklMRSIpIgogIHJtIC1mICIkUElERklMRSIKICBlY2hvICJbK10gV29ya2VyIHN0b3BwZWQuIgplbHNlCiAgZWNobyAiWyFdIFdvcmtlciBpcyBub3QgcnVubmluZy4iCmZpCg==" | base64 -d > /usr/local/bin/kstop

RUN echo "IyEvYmluL2Jhc2gKUElERklMRT0vdmFyL3J1bi9raXR0eS13b3JrZXIucGlkCkxPRz0vdmFyL2xvZy9raXR0eS13b3JrZXIubG9nCmlmIFsgLWYgIiRQSURGSUxFIiBdICYmIGtpbGwgLTAgIiQoY2F0ICIkUElERklMRSIpIiAyPi9kZXYvbnVsbDsgdGhlbgogIGVjaG8gIlsrXSBXb3JrZXIgcnVubmluZyAocGlkICQoY2F0ICIkUElERklMRSIpKS4iCmVsc2UKICBlY2hvICJbIV0gV29ya2VyIGlzIG5vdCBydW5uaW5nLiIKZmkKaWYgWyAtZiAiJExPRyIgXTsgdGhlbgogIGVjaG8gIi0tLS0gbGFzdCAxMCBsb2cgbGluZXMgLS0tLSIKICB0YWlsIC1uIDEwICIkTE9HIgpmaQo=" | base64 -d > /usr/local/bin/kstatus

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
printf 'const http=require("http");\n\
http.createServer((req,res)=>{\n\
res.writeHead(200,{"Content-Type":"text/plain"});\n\
res.end("kitty alive");\n\
}).listen(process.env.PORT||10000,"0.0.0.0");\n' \
> /srv/keepalive.js


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
# Runtime â€” only base services. No miner auto-start.
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
node /srv/keepalive.js & \
\
echo "[+] Ready. SSH in and run kstart to begin the worker."; \
tail -f /dev/null \
'
