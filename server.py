from http.server import HTTPServer, BaseHTTPRequestHandler
import re

def get_tunnel():
    try:
        with open('/tmp/pinggy.log', 'r') as f:
            content = f.read()

        # Try all possible Pinggy URL patterns
        patterns = [
            r'([a-zA-Z0-9._-]+\.a\.pinggy\.io:[0-9]+)',
            r'tcp://([^\s]+)',
            r'([a-zA-Z0-9-]+\.pinggy\.io:[0-9]+)',
        ]
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1).replace('tcp://', '')

        # If no URL found, return raw log for debugging
        return None, content

    except Exception as e:
        return None, str(e)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        result = get_tunnel()

        if isinstance(result, tuple):
            tunnel, raw_log = result
        else:
            tunnel = result
            raw_log = ""

        if tunnel:
            host = tunnel.split(':')[0]
            port = tunnel.split(':')[1]
            body = f"""
===============================
  HERMES CONTAINER IS RUNNING
===============================

🔗 SSH Command:
   ssh -p {port} root@{host}

🔑 Password: toor

📡 Full Tunnel: {tunnel}

===============================
""".encode()
        else:
            body = f"""
⚠️ Tunnel URL not found yet!
Refresh in 30 seconds...

📄 Raw Pinggy Log:
{raw_log}
""".encode()

        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
