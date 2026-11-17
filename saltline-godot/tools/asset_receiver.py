#!/usr/bin/env python3
"""Loopback-only receiver for source-generated assets; no arbitrary filesystem writes."""
import argparse, base64, json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'assets/export'
class Handler(BaseHTTPRequestHandler):
    def headers_ok(self):
        self.send_header('Access-Control-Allow-Origin','http://127.0.0.1:8793')
        self.send_header('Access-Control-Allow-Methods','POST,OPTIONS,GET')
        self.send_header('Access-Control-Allow-Headers','Content-Type')
    def do_OPTIONS(self):
        self.send_response(204);self.headers_ok();self.end_headers()
    def do_GET(self):
        self.send_response(200);self.headers_ok();self.end_headers();self.wfile.write(b'{"ready":true}')
    def do_POST(self):
        try:
            size=int(self.headers.get('Content-Length','0'))
            if not 0<size<=64*1024*1024:raise ValueError('invalid body size')
            payload=json.loads(self.rfile.read(size))
            dest=(ROOT/payload['path']).resolve()
            if not dest.is_relative_to(ROOT.resolve()):raise ValueError('path outside export root')
            data=base64.b64decode(payload['base64'],validate=True) if 'base64' in payload else json.dumps(payload['json'],ensure_ascii=False,separators=(',',':')).encode()
            dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
            self.send_response(200);self.headers_ok();self.end_headers();self.wfile.write(b'{"saved":true}')
        except Exception as exc:
            self.send_response(400);self.headers_ok();self.end_headers();self.wfile.write(str(exc).encode())
    def log_message(self,*args):pass
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8794);a=p.parse_args()
    ThreadingHTTPServer(('127.0.0.1',a.port),Handler).serve_forever()
