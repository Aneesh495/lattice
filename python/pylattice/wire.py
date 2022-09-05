"""
wire.py: Binary Framing and CRC32C Implementation for Lattice Wire Protocol (LWP)
"""

import struct
from enum import IntEnum
from typing import Tuple

MAGIC = b"LATX"
VERSION = 1
HEADER_SIZE = 24


class Opcode(IntEnum):
    HEARTBEAT = 0x01
    PING_REQ = 0x02
    ACK = 0x03
    REQUEST_VOTE = 0x10
    REQUEST_VOTE_REPLY = 0x11
    APPEND_ENTRIES = 0x12
    APPEND_ENTRIES_REPLY = 0x13
    GRAIN_MESSAGE = 0x20
    GRAIN_REPLY = 0x21
    EVENT_BATCH = 0x30
    STREAM_CHUNK = 0x40


class CRC32C:
    _TABLE = None

    @classmethod
    def _init_table(cls):
        if cls._TABLE is not None:
            return
        poly = 0x82F63B78
        table = []
        for i in range(256):
            crc = i
            for _ in range(8):
                if crc & 1:
                    crc = (crc >> 1) ^ poly
                else:
                    crc = crc >> 1
            table.append(crc & 0xFFFFFFFF)
        cls._TABLE = table

    @classmethod
    def checksum(cls, data: bytes) -> int:
        cls._init_table()
        crc = 0xFFFFFFFF
        for b in data:
            crc = (crc >> 8) ^ cls._TABLE[(crc ^ b) & 0xFF]
        return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


class WireFrame:
    def __init__(self, opcode: int, flags: int, sequence_id: int, payload: bytes):
        self.opcode = opcode
        self.flags = flags
        self.sequence_id = sequence_id
        self.payload = payload
        self.checksum = None

    def encode(self) -> bytes:
        payload_len = len(self.payload)
        header_without_crc = struct.pack(
            ">4sBBHQI",
            MAGIC,
            VERSION,
            self.opcode,
            self.flags,
            self.sequence_id,
            payload_len,
        )
        crc = CRC32C.checksum(header_without_crc + self.payload)
        self.checksum = crc
        header = header_without_crc + struct.pack(">I", crc)
        return header + self.payload

    @classmethod
    def decode(cls, data: bytes) -> Tuple["WireFrame", int]:
        if len(data) < HEADER_SIZE:
            raise ValueError("Buffer underflow: insufficient header bytes")

        magic, ver, op, flags, seq, payload_len, crc = struct.unpack(
            ">4sBBHQII", data[:HEADER_SIZE]
        )
        if magic != MAGIC:
            raise ValueError(f"Invalid magic identifier: {magic}")
        if ver != VERSION:
            raise ValueError(f"Unsupported protocol version: {ver}")

        total_size = HEADER_SIZE + payload_len
        if len(data) < total_size:
            raise ValueError("Buffer underflow: incomplete payload")

        payload = data[HEADER_SIZE:total_size]
        calculated_crc = CRC32C.checksum(data[:20] + payload)
        if calculated_crc != crc:
            raise ValueError(f"CRC32C mismatch: expected {hex(crc)}, calculated {hex(calculated_crc)}")

        frame = cls(op, flags, seq, payload)
        frame.checksum = crc
        return frame, total_size
