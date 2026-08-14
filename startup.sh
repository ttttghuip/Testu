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
    tcp@a.pinggy.io > /tmp/pinggy.log 2>&1 &

PINGGY_PID=$!

# Wait for Pinggy URL to appear in log
echo "⏳ Waiting for Pinggy URL..."
for i in $(seq 1 20); do
    sleep 3
    if grep -q "forwarding\|pinggy.io" /tmp/pinggy.log 2>/dev/null; then
        echo "✅ Pinggy connected!"
        break
    fi
    echo "  Waiting... $i/20"
done

# ── 3. Print full raw log ─────────────────────────────────
echo ""
echo "====== RAW PINGGY LOG ======"
cat /tmp/pinggy.log
echo "============================"

# Extract URL — match Pinggy's actual format
TUNNEL=$(grep -oE '[a-zA-Z0-9._-]+\.a\.pinggy\.io:[0-9]+' /tmp/pinggy.log | head -1)
if [ -z "$TUNNEL" ]; then
    TUNNEL=$(grep -oE 'tcp://[^ ]+' /tmp/pinggy.log | head -1 | sed 's|tcp://||')
fi
if [ -z "$TUNNEL" ]; then
    TUNNEL=$(grep -oE '[a-zA-Z0-9-]+\.pinggy\.io:[0-9]+' /tmp/pinggy.log | head -1)
fi

echo ""
echo "============================================"
if [ -n "$TUNNEL" ]; then
    HOST=$(echo $TUNNEL | cut -d: -f1)
    PORT=$(echo $TUNNEL | cut -d: -f2)
    echo "🔗 Connect from Termux:"
    echo "   ssh -p $PORT root@$HOST"
    echo "   Password: toor"
else
    echo "⚠️ Could not parse URL — check RAW LOG above!"
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
            tcp@a.pinggy.io > /tmp/pinggy.log 2>&1 &
        PINGGY_PID=$!
        sleep 30
        echo "📄 NEW PINGGY LOG:"
        cat /tmp/pinggy.log
    fi

done
) &

# ── 5. Start server.py ────────────────────────────────────
echo "🚀 Starting server.py on port 8080..."
python3 /root/server.py
