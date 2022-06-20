/*
 * latticenet.h: Native C Acceleration Engine for Lattice Wire Protocol (LWP)
 *
 * High-performance binary frame serialization, hardware-accelerated CRC32C,
 * lock-free ring buffers, and non-blocking network socket primitives.
 * Conforms to C11 standard.
 */

#ifndef LATTICENET_H
#define LATTICENET_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LATTICE_MAGIC 0x4C415458U /* ASCII 'LATX' */
#define LATTICE_VERSION 1
#define LATTICE_HEADER_SIZE 24

/* Protocol Opcodes */
typedef enum {
    LATTICE_OP_HEARTBEAT          = 0x01,
    LATTICE_OP_PING_REQ           = 0x02,
    LATTICE_OP_ACK                = 0x03,
    LATTICE_OP_REQUEST_VOTE       = 0x10,
    LATTICE_OP_REQUEST_VOTE_REPLY = 0x11,
    LATTICE_OP_APPEND_ENTRIES     = 0x12,
    LATTICE_OP_APPEND_ENTRIES_REPLY = 0x13,
    LATTICE_OP_GRAIN_MESSAGE      = 0x20,
    LATTICE_OP_GRAIN_REPLY        = 0x21,
    LATTICE_OP_EVENT_BATCH        = 0x30,
    LATTICE_OP_STREAM_CHUNK       = 0x40
} lattice_opcode_t;

/* Frame Flags */
#define LATTICE_FLAG_COMPRESSED (1U << 0)
#define LATTICE_FLAG_ERROR      (1U << 1)
#define LATTICE_FLAG_ONEWAY     (1U << 2)

/* Packed 24-byte LWP header definition */
#pragma pack(push, 1)
typedef struct {
    uint32_t magic;           /* Big-endian 0x4C415458 */
    uint8_t  version;         /* Protocol version (1) */
    uint8_t  opcode;          /* Message opcode */
    uint16_t flags;           /* Bitmask flags */
    uint64_t sequence_id;     /* Monotonic sequence identifier */
    uint32_t payload_len;     /* Length of subsequent payload bytes */
    uint32_t checksum;        /* CRC32C over header (bytes 0..19) + payload */
} lattice_frame_header_t;
#pragma pack(pop)

/* Return Status Codes */
typedef enum {
    LATTICE_OK                   = 0,
    LATTICE_ERR_INVALID_ARG      = -1,
    LATTICE_ERR_BUFFER_OVERFLOW  = -2,
    LATTICE_ERR_BUFFER_UNDERFLOW = -3,
    LATTICE_ERR_MAGIC_MISMATCH   = -4,
    LATTICE_ERR_VERSION_MISMATCH = -5,
    LATTICE_ERR_CRC_MISMATCH     = -6,
    LATTICE_ERR_SOCKET           = -7,
    LATTICE_ERR_CLOSED           = -8
} lattice_status_t;

/*
 * CRC32C Functions (Castagnoli Polynomial 0x1EDC6F41)
 */
uint32_t lattice_crc32c(const uint8_t *data, size_t length);
uint32_t lattice_crc32c_update(uint32_t prev_crc, const uint8_t *data, size_t length);

/*
 * Lock-Free Single-Producer Single-Consumer (SPSC) Ring Buffer
 */
typedef struct {
    uint8_t *buffer;
    size_t capacity;
    size_t mask;
    _Atomic size_t head;
    _Atomic size_t tail;
} lattice_ring_buffer_t;

lattice_status_t lattice_ring_buffer_init(lattice_ring_buffer_t *rb, size_t capacity);
void lattice_ring_buffer_free(lattice_ring_buffer_t *rb);
size_t lattice_ring_buffer_available_read(const lattice_ring_buffer_t *rb);
size_t lattice_ring_buffer_available_write(const lattice_ring_buffer_t *rb);
size_t lattice_ring_buffer_write(lattice_ring_buffer_t *rb, const uint8_t *src, size_t len);
size_t lattice_ring_buffer_read(lattice_ring_buffer_t *rb, uint8_t *dst, size_t len);

/*
 * Frame Encoding and Parsing
 */
lattice_status_t lattice_frame_encode(
    uint8_t opcode,
    uint16_t flags,
    uint64_t sequence_id,
    const uint8_t *payload,
    uint32_t payload_len,
    uint8_t *out_buf,
    size_t out_cap,
    size_t *out_written
);

lattice_status_t lattice_frame_decode_header(
    const uint8_t *buf,
    size_t buf_len,
    lattice_frame_header_t *out_header
);

lattice_status_t lattice_frame_verify(
    const uint8_t *buf,
    size_t buf_len
);

#ifdef __cplusplus
}
#endif

#endif /* LATTICENET_H */
