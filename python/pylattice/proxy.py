"""
proxy.py: Dynamic Proxy for Virtual Actor Invocations
"""

import json
from typing import Any
from .wire import Opcode, WireFrame


class GrainProxy:
    def __init__(self, client: Any, grain_type: str, key: str):
        self._client = client
        self._grain_type = grain_type
        self._key = key

    @property
    def grain_id(self) -> str:
        return f"{self._grain_type}/{self._key}"

    def invoke(self, method_name: str, *args) -> Any:
        payload_dict = {
            "type": self._grain_type,
            "key": self._key,
            "method": method_name,
            "args": list(args),
        }
        payload_bytes = json.dumps(payload_dict).encode("utf-8")
        frame = WireFrame(
            opcode=Opcode.GRAIN_MESSAGE,
            flags=0,
            sequence_id=self._client.next_sequence(),
            payload=payload_bytes,
        )
        reply = self._client.send_frame(frame)
        if reply.flags & 0x02:
            raise RuntimeError(f"Grain invocation failed: {reply.payload.decode('utf-8')}")

        try:
            return json.loads(reply.payload.decode("utf-8"))
        except Exception:
            return reply.payload.decode("utf-8")

    def __getattr__(self, name: str):
        def caller(*args):
            return self.invoke(name, *args)
        return caller
