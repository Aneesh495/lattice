"""
client.py: Client Connection and Grain Factory for Lattice Clusters
"""

import socket
import threading
from typing import Optional
from .wire import WireFrame, Opcode
from .proxy import GrainProxy


class LatticeClient:
    def __init__(self, host: str = "127.0.0.1", port: int = 9000):
        self.host = host
        self.port = port
        self._sock: Optional[socket.socket] = None
        self._seq = 0
        self._lock = threading.Lock()

    def next_sequence(self) -> int:
        with self._lock:
            self._seq += 1
            return self._seq

    def connect(self):
        with self._lock:
            if self._sock is None:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.connect((self.host, self.port))
                self._sock = s

    def close(self):
        with self._lock:
            if self._sock is not None:
                try:
                    self._sock.close()
                except Exception:
                    pass
                self._sock = None

    def send_frame(self, frame: WireFrame) -> WireFrame:
        self.connect()
        encoded = frame.encode()
        with self._lock:
            assert self._sock is not None
            self._sock.sendall(encoded)

            header_bytes = self._recv_exact(24)
            payload_len = int.from_bytes(header_bytes[16:20], byteorder="big")
            payload_bytes = self._recv_exact(payload_len) if payload_len > 0 else b""

            full_frame = header_bytes + payload_bytes
            reply, _ = WireFrame.decode(full_frame)
            return reply

    def _recv_exact(self, count: int) -> bytes:
        buf = bytearray()
        while len(buf) < count:
            assert self._sock is not None
            chunk = self._sock.recv(count - len(buf))
            if not chunk:
                raise ConnectionResetError("Connection closed while receiving frame")
            buf.extend(chunk)
        return bytes(buf)

    def ping(self) -> bool:
        frame = WireFrame(
            opcode=Opcode.HEARTBEAT,
            flags=0,
            sequence_id=self.next_sequence(),
            payload=b"PING",
        )
        reply = self.send_frame(frame)
        return reply.opcode == Opcode.ACK

    def grain(self, grain_type: str, key: str) -> GrainProxy:
        return GrainProxy(self, grain_type, key)
