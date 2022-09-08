"""
test_pylattice.py: Unit and Wire Integration Tests for Python Client SDK
"""

import unittest
from pylattice.wire import CRC32C, WireFrame, Opcode
from pylattice.proxy import GrainProxy


class DummyClient:
    def __init__(self):
        self.seq = 0
        self.last_sent_frame = None

    def next_sequence(self):
        self.seq += 1
        return self.seq

    def send_frame(self, frame):
        self.last_sent_frame = frame
        # Return mock grain reply
        return WireFrame(
            opcode=Opcode.GRAIN_REPLY,
            flags=0,
            sequence_id=frame.sequence_id,
            payload=b'{"balance": 500, "status": "ok"}',
        )


class TestPyLattice(unittest.TestCase):

    def test_crc32c_standard_rfc_vector(self):
        data = b"123456789"
        crc = CRC32C.checksum(data)
        self.assertEqual(crc, 0xE3069283)

    def test_crc32c_corruption_detection(self):
        data = b"Lattice Distributed Object Graph"
        crc1 = CRC32C.checksum(data)
        corrupted = bytearray(data)
        corrupted[0] ^= 0x01
        crc2 = CRC32C.checksum(bytes(corrupted))
        self.assertNotEqual(crc1, crc2)

    def test_wire_frame_encode_decode(self):
        payload = b"Hello from Python client"
        frame = WireFrame(
            opcode=Opcode.GRAIN_MESSAGE,
            flags=0,
            sequence_id=42000,
            payload=payload,
        )
        encoded = frame.encode()
        self.assertEqual(len(encoded), 24 + len(payload))

        decoded, consumed = WireFrame.decode(encoded)
        self.assertEqual(consumed, len(encoded))
        self.assertEqual(decoded.opcode, Opcode.GRAIN_MESSAGE)
        self.assertEqual(decoded.sequence_id, 42000)
        self.assertEqual(decoded.payload, payload)
        self.assertEqual(decoded.checksum, frame.checksum)

    def test_wire_frame_corruption_rejected(self):
        payload = b"Immutable state"
        frame = WireFrame(Opcode.HEARTBEAT, 0, 1, payload)
        encoded = bytearray(frame.encode())
        # Corrupt one payload byte
        encoded[-1] ^= 0xFF
        with self.assertRaises(ValueError):
            WireFrame.decode(bytes(encoded))

    def test_grain_proxy_dynamic_invocation(self):
        client = DummyClient()
        proxy = GrainProxy(client, "BankAccount", "acc-500")

        res = proxy.deposit(200)
        self.assertEqual(res, {"balance": 500, "status": "ok"})
        self.assertEqual(client.last_sent_frame.opcode, Opcode.GRAIN_MESSAGE)
        self.assertIn(b"BankAccount", client.last_sent_frame.payload)
        self.assertIn(b"deposit", client.last_sent_frame.payload)


if __name__ == "__main__":
    unittest.main()
