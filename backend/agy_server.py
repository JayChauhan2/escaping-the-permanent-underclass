#!/usr/bin/env python3
"""
Antigravity Remote Bridge Server (AGY Bridge)
Enables secure, real-time remote control of Antigravity CLI from iOS mobile app.
"""

import http.server
import json
import os
import subprocess
import sys
import threading
import time
from urllib.parse import urlparse

PORT = 11435
AGY_PATH = os.path.expanduser("~/.local/bin/agy")
DEFAULT_WORKSPACE = os.path.expanduser("~/StudentAgent")

active_processes = {}
lock = threading.Lock()

class AGYBridgeHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/status" or parsed.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._send_cors_headers()
            self.end_headers()
            resp = {
                "status": "online",
                "agy_installed": os.path.exists(AGY_PATH),
                "agy_path": AGY_PATH,
                "workspace": DEFAULT_WORKSPACE,
                "timestamp": time.time()
            }
            self.wfile.write(json.dumps(resp).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path in ["/stream", "/api/stream", "/run"]:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            try:
                data = json.loads(body.decode("utf-8"))
            except Exception:
                data = {}

            prompt = data.get("prompt", "").strip()
            convo_id = data.get("conversation_id")
            cwd = data.get("cwd", DEFAULT_WORKSPACE)
            if not os.path.exists(cwd):
                cwd = os.path.expanduser("~")

            if not prompt:
                self.send_response(400)
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(b"Prompt is required")
                return

            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self._send_cors_headers()
            self.end_headers()

            # Build agy command line
            cmd = [
                AGY_PATH,
                "--print", prompt,
                "--output-format", "stream-json",
                "--dangerously-skip-permissions"
            ]
            if convo_id:
                cmd.extend(["--conversation", convo_id])

            client_id = f"{self.client_address[0]}_{time.time()}"
            try:
                proc = subprocess.Popen(
                    cmd,
                    cwd=cwd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1
                )
                with lock:
                    active_processes[client_id] = proc

                for line in proc.stdout:
                    if line:
                        payload = f"data: {line.strip()}\n\n"
                        self.wfile.write(payload.encode("utf-8"))
                        self.wfile.flush()

                proc.wait()
                # Send completion sentinel
                done_event = json.dumps({"event": "completed", "exit_code": proc.returncode})
                self.wfile.write(f"data: {done_event}\n\n".encode("utf-8"))
                self.wfile.flush()

            except Exception as e:
                err_event = json.dumps({"event": "error", "error": str(e)})
                try:
                    self.wfile.write(f"data: {err_event}\n\n".encode("utf-8"))
                    self.wfile.flush()
                except Exception:
                    pass
            finally:
                with lock:
                    active_processes.pop(client_id, None)

        elif parsed.path in ["/abort", "/api/abort"]:
            with lock:
                for cid, p in list(active_processes.items()):
                    try:
                        p.terminate()
                    except Exception:
                        pass
                active_processes.clear()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"aborted": True}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    server_address = ("0.0.0.0", PORT)
    httpd = http.server.ThreadingHTTPServer(server_address, AGYBridgeHandler)
    print(f"🚀 AGY Remote Bridge running on http://0.0.0.0:{PORT} (Workspace: {DEFAULT_WORKSPACE})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()

if __name__ == "__main__":
    run_server()
