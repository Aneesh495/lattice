# Lattice Wire Protocol (LWP) Binary Framing Specification

The Lattice Wire Protocol (LWP) is a low-latency, compact binary framing format designed for inter-node communication, virtual actor remoting, consensus log replication, and polyglot client ingress.

All integers are encoded in Big-Endian (network byte order).

---

## 1. Frame Header Layout

Every LWP frame starts with a fixed 24-byte header:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Magic (0x4C415458)                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|    Version    |     Opcode    |             Flags             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
+                     Sequence ID (64-bit)                      +
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Payload Length                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       CRC32C Checksum                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Payload Bytes ...                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 1.1 Header Fields

| Field Name     | Offset (Bytes) | Length (Bytes) | Type      | Description                                                    |
|----------------|----------------|----------------|-----------|----------------------------------------------------------------|
| Magic          | 0              | 4              | uint32    | Fixed ASCII bytes 'LATX' (0x4C415458). Identifies LWP streams. |
| Version        | 4              | 1              | uint8     | Protocol version number. Current version is 1.                 |
| Opcode         | 5              | 1              | uint8     | Identifies message classification and dispatch target.         |
| Flags          | 6              | 2              | uint16    | Bitmask controlling compression, error status, and delivery.   |
| Sequence ID    | 8              | 8              | uint64    | Monotonically increasing identifier for RPC request matching.  |
| Payload Length | 16             | 4              | uint32    | Length of subsequent payload bytes (0 to 16,777,216 bytes).    |
| Checksum       | 20             | 4              | uint32    | Castagnoli CRC32C over header (bytes 0..19) + payload.         |

---

## 2. Opcode Enumeration

| Opcode | Hex  | Symbol                | Subsystem  | Semantics                                              |
|--------|------|-----------------------|------------|--------------------------------------------------------|
| 1      | 0x01 | HEARTBEAT             | Cluster    | SWIM direct ping message to monitor node health.       |
| 2      | 0x02 | PING_REQ              | Cluster    | SWIM indirect probe request routed through helper.     |
| 3      | 0x03 | ACK                   | Cluster    | SWIM acknowledgment reply to direct or indirect ping.  |
| 16     | 0x10 | REQUEST_VOTE          | Consensus  | Raft leader election ballot request.                   |
| 17     | 0x11 | REQUEST_VOTE_REPLY    | Consensus  | Raft vote ballot response (granted or denied).         |
| 18     | 0x12 | APPEND_ENTRIES        | Consensus  | Raft log replication and heartbeat message.            |
| 19     | 0x13 | APPEND_ENTRIES_REPLY  | Consensus  | Raft log replication response with matchIndex.         |
| 32     | 0x20 | GRAIN_MESSAGE         | Virtual AC | Remote virtual actor method turn invocation.           |
| 33     | 0x21 | GRAIN_REPLY           | Virtual AC | Virtual actor turn completion result or exception.     |
| 48     | 0x30 | EVENT_BATCH           | Storage    | Replicated batch of bitemporal event store records.    |
| 64     | 0x40 | STREAM_CHUNK          | Streams    | Reactive stream window chunk with backpressure token.  |

---

## 3. Frame Flags Bitmask

- `0x0001` (`LATTICE_FLAG_COMPRESSED`): Payload is compressed with Zstandard / Deflate.
- `0x0002` (`LATTICE_FLAG_ERROR`): Indicates an execution failure or error response.
- `0x0004` (`LATTICE_FLAG_ONEWAY`): Fire-and-forget message; receiver emits no reply.

---

## 4. CRC32C Checksum Calculation

LWP enforces data integrity using the Castagnoli 32-bit polynomial:
`P(x) = 0x1EDC6F41` (Reflected polynomial: `0x82F63B78`).

Standard test vector:
Input bytes: `"123456789"` (ASCII 0x31..0x39)
Expected Checksum: `0xE3069283`

The checksum covers the first 20 bytes of the frame header concatenated with the payload bytes. Byte 20..23 in the transmitted frame contain this checksum.
