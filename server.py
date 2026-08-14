from http.server import HTTPServer, BaseHTTPRequestHandler
import re

def get_tunnel():
    try:
        with open('/tmp/pinggy.log', 'r') as f:
            content = f.read()
        
        # Try all patterns
        patterns = [
            r'tcp://([^\s]+)',
            r'([a-z0-9]+\.pinggy\.io:[0-9]+)',
            r'tun([^\s]+:[0-9]+)',
        ]
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1).replace('tcp://', '')
        return None
    except:
        return None

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        tunnel = get_tunnel()

        if tunnel:
            host = tunnel.split(':')[0]
            port = tunnel.split(':')[1]
            body = f"""
🟢 Container is RUNNING!

🔗 SSH Command:
ssh -p {port} root@{host}

🔑 Password: toor

📡 Tunnel: {tunnel}
""".encode()
        else:
            body = b"🟡 Container running but Pinggy tunnel not ready yet. Refresh in 30 seconds!"

        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
