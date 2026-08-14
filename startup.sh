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

# Wait longer for Pinggy to fully connect
echo "⏳ Waiting for Pinggy to connect..."
sleep 15

# ── 3. Print RAW log + parsed info ───────────────────────
echo ""
echo "============================================"
echo "📄 RAW PINGGY LOG:"
cat /tmp/pinggy.log
echo ""
echo "============================================"

# Try multiple grep patterns to find port
TUNNEL=$(grep -oE 'tcp://[^[:space:]]+' /tmp/pinggy.log | head -1)
if [ -z "$TUNNEL" ]; then
    TUNNEL=$(grep -oE '[a-z0-9]+\.pinggy\.io:[0-9]+' /tmp/pinggy.log | head -1)
fi
if [ -z "$TUNNEL" ]; then
    TUNNEL=$(grep -oE 'tun[^ ]+:[0-9]+' /tmp/pinggy.log | head -1)
fi

echo "🔗 Connect from Termux:"
if [ -n "$TUNNEL" ]; then
    # Remove tcp:// prefix if present
    CLEAN=$(echo $TUNNEL | sed 's|tcp://||')
    HOST=$(echo $CLEAN | cut -d: -f1)
    PORT=$(echo $CLEAN | cut -d: -f2)
    echo "   ssh -p $PORT root@$HOST"
    echo "   Password: toor"
else
    echo "   ⚠️ Check RAW LOG above for your tunnel URL!"
fi
echo "============================================"
echo ""

# ── 4. Watchdog ───────────────────────────────────────────
(
while true; do
    sleep 120

    if ! nc -z localhost 22 2>/dev/null; then
        echo "⚠️ SSH died! Restarting..."
        /usr/sbin/sshd -D &
        sleep 5
    fi

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
        sleep 15
        echo "📄 NEW PINGGY LOG:"
        cat /tmp/pinggy.log
    fi

done
) &

# ── 5. Start server.py ────────────────────────────────────
echo "🚀 Starting server.py on port 8080..."
python3 /root/server.py
