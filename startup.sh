#!/bin/bash

echo "=============================="
echo "   Debian 12 Container Start"
echo "=============================="

# ── 1. SSH Server ─────────────────────────────────────────
echo "🔑 Starting SSH..."
[ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -A
/usr/sbin/sshd -D &
sleep 3

if nc -z localhost 22 2>/dev/null; then
    echo "✅ SSH running on port 22"
else
    echo "❌ SSH failed, retrying..."
    /usr/sbin/sshd -D &
    sleep 5
fi

# ── 2. Pinggy TCP Tunnel ──────────────────────────────────
echo "🌐 Starting Pinggy tunnel..."
ssh -T -N \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=5 \
    -p 443 \
    -R 0:localhost:22 \
    tcp@a.pinggy.io 2>&1 | tee /tmp/pinggy.log &

PINGGY_PID=$!
sleep 8

# ── 3. Print SSH Info ─────────────────────────────────────
echo ""
echo "============================================"
TUNNEL=$(grep -o 'tun[a-z0-9.-]*pinggy\.io:[0-9]*' /tmp/pinggy.log | head -1)
HOST=$(echo $TUNNEL | cut -d: -f1)
PORT=$(echo $TUNNEL | cut -d: -f2)
echo "🔗 Connect from Termux:"
echo "   ssh -p $PORT root@$HOST"
echo "   Password: toor"
echo "============================================"
echo ""

# ── 4. Watchdog ───────────────────────────────────────────
(
while true; do
    sleep 120

    # Restart SSH if dead
    if ! nc -z localhost 22 2>/dev/null; then
        echo "⚠️ SSH died! Restarting..."
        /usr/sbin/sshd -D &
        sleep 5
    fi

    # Restart Pinggy if dead
    if ! kill -0 $PINGGY_PID 2>/dev/null; then
        echo "⚠️ Pinggy died! Restarting..."
        ssh -T -N \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ServerAliveInterval=30 \
            -o ServerAliveCountMax=5 \
            -p 443 \
            -R 0:localhost:22 \
            tcp@a.pinggy.io 2>&1 | tee /tmp/pinggy.log &
        PINGGY_PID=$!
        sleep 8

        TUNNEL=$(grep -o 'tun[a-z0-9.-]*pinggy\.io:[0-9]*' /tmp/pinggy.log | head -1)
        echo "🔗 New: ssh -p $(echo $TUNNEL | cut -d: -f2) root@$(echo $TUNNEL | cut -d: -f1)"
    fi

done
) &

# ── 5. Start server.py ────────────────────────────────────
echo "🚀 Starting server.py on port 8080..."
python3 /root/server.py
