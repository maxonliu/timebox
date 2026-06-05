#!/usr/bin/env python3
"""TimeBox local server — serves the HTML + writes daily note on punch."""

import json
import os
import re
import sys
import http.server
import socketserver
from datetime import datetime

PORT = 8765
NOTE_DIR = os.environ.get(
    "NOTE_DIR",
    os.path.expanduser("~/Documents/Notes/Today/"),
)


def note_path():
    """Return the daily note path based on current year-month."""
    now = datetime.now()
    return os.path.join(NOTE_DIR, f"{now.year}-{now.month:02d}.md")


def today_section():
    """Return the section header for today, e.g. '## 6.3'."""
    now = datetime.now()
    return f"## {now.month}.{now.day}"


def write_punch(time_str, task):
    """Append a punch entry under today's section in the daily note."""
    section = today_section()
    entry = f"{time_str} {task}"

    path = note_path()

    # Read existing file
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    else:
        content = ""

    lines = content.split("\n")
    # Remove trailing empty lines for clean processing
    while lines and lines[-1] == "":
        lines.pop()

    # Find today's section
    section_idx = None
    for i, line in enumerate(lines):
        if line.strip() == section:
            section_idx = i
            break

    if section_idx is not None:
        # Find the last non-blank entry line in this section.
        # This avoids inserting after section-separator blank lines.
        last_entry_idx = section_idx
        i = section_idx + 1
        while i < len(lines):
            if lines[i].startswith("## "):
                break  # next section
            if lines[i].strip() != "":
                last_entry_idx = i
            i += 1

        # Insert after the last non-blank entry
        if last_entry_idx == section_idx:
            # Empty section — blank line after header, then entry
            lines.insert(section_idx + 1, "")
            lines.insert(section_idx + 2, entry)
        else:
            # Consecutive entry — no blank line
            lines.insert(last_entry_idx + 1, entry)
    else:
        # Section doesn't exist — add after the last entry of file
        lines.append("")
        lines.append(section)
        lines.append("")
        lines.append(entry)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    return True


class TimeBoxHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(
            *args, directory=os.path.dirname(os.path.abspath(__file__)), **kwargs
        )

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.path = "/timebox.html"
        return super().do_GET()

    def do_POST(self):
        if self.path == "/api/punch":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
                time_str = data.get("time", "")
                task = data.get("task", "")
                write_punch(time_str, task)
                self._json(200, {"ok": True})
            except Exception as e:
                self._json(500, {"ok": False, "error": str(e)})
        else:
            self.send_response(404)
            self.end_headers()

    def _json(self, status, data):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, format, *args):
        # Quieter logs
        msg = format % args
        if "/api/" in msg:
            print(f"[TimeBox] {msg}")


if __name__ == "__main__":
    print(f"✦ TimeBox server → http://localhost:{PORT}")
    print(f"✦ Daily note → {note_path()}")
    print("  Press Ctrl+C to stop.")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), TimeBoxHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n⏹ TimeBox server stopped.")
            sys.exit(0)
