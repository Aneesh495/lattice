/*
 * latticenet.c: High-Throughput Wire Protocol Implementation
 *
 * Provides frame serialization, header validation, and CRC32C payload
 * verification for the Lattice Wire Protocol (LWP).
 */

#include "latticenet.h"
#include <string.h>

/* Endian conversion utilities (Big-Endian network byte order) */
static inline void write_be16(uint8_t *dst, uint16_t val) {
    dst[0] = (uint8_t)((val >> 8) & 0xFF);
    dst[1] = (uint8_t)(val & 0xFF);
}

static inline void write_be32(uint8_t *dst, uint32_t val) {
    dst[0] = (uint8_t)((val >> 24) & 0xFF);
    dst[1] = (uint8_t)((val >> 16) & 0xFF);
    dst[2] = (uint8_t)((val >> 8) & 0xFF);
    dst[3] = (uint8_t)(val & 0xFF);
}

static inline void write_be64(uint8_t *dst, uint64_t val) {
    write_be32(dst, (uint32_t)((val >> 32) & 0xFFFFFFFFU));
    write_be32(dst + 4, (uint32_t)(val & 0xFFFFFFFFU));
}

static inline uint16_t read_be16(const uint8_t *src) {
    return (uint16_t)(((uint16_t)src[0] << 8) | (uint16_t)src[1]);
}

static inline uint32_t read_be32(const uint8_t *src) {
    return ((uint32_t)src[0] << 24) |
           ((uint32_t)src[1] << 16) |
           ((uint32_t)src[2] << 8)  |
           (uint32_t)src[3];
}

static inline uint64_t read_be64(const uint8_t *src) {
    uint32_t high = read_be32(src);
    uint32_t low = read_be32(src + 4);
    return ((uint64_t)high << 32) | (uint64_t)low;
}

lattice_status_t lattice_frame_encode(
    uint8_t opcode,
    uint16_t flags,
    uint64_t sequence_id,
    const uint8_t *payload,
    uint32_t payload_len,
    uint8_t *out_buf,
    size_t out_cap,
    size_t *out_written
) {
    if (!out_buf || !out_written) {
        return LATTICE_ERR_INVALID_ARG;
    }
    size_t total_size = LATTICE_HEADER_SIZE + payload_len;
    if (out_cap < total_size) {
        return LATTICE_ERR_BUFFER_OVERFLOW;
    }

    /* 1. Magic: 'LATX' = 0x4C415458 */
    write_be32(out_buf, LATTICE_MAGIC);

    /* 2. Version: 1 */
    out_buf[4] = LATTICE_VERSION;

    /* 3. Opcode */
    out_buf[5] = opcode;

    /* 4. Flags */
    write_be16(out_buf + 6, flags);

    /* 5. Sequence ID */
    write_be64(out_buf + 8, sequence_id);

    /* 6. Payload Length */
    write_be32(out_buf + 16, payload_len);

    /* 7. Payload copying */
    if (payload && payload_len > 0) {
        memcpy(out_buf + LATTICE_HEADER_SIZE, payload, payload_len);
    }

    /* 8. CRC32C over header (bytes 0..19) and payload */
    uint32_t crc = lattice_crc32c_update(0xFFFFFFFFU, out_buf, 20);
    if (payload && payload_len > 0) {
        crc = lattice_crc32c_update(crc, payload, payload_len);
    }
    crc ^= 0xFFFFFFFFU;

    write_be32(out_buf + 20, crc);

    *out_written = total_size;
    return LATTICE_OK;
}

lattice_status_t lattice_frame_decode_header(
    const uint8_t *buf,
    size_t buf_len,
    lattice_frame_header_t *out_header
) {
    if (!buf || !out_header) {
        return LATTICE_ERR_INVALID_ARG;
    }
    if (buf_len < LATTICE_HEADER_SIZE) {
        return LATTICE_ERR_BUFFER_UNDERFLOW;
    }

    uint32_t magic = read_be32(buf);
    if (magic != LATTICE_MAGIC) {
        return LATTICE_ERR_MAGIC_MISMATCH;
    }

    uint8_t version = buf[4];
    if (version != LATTICE_VERSION) {
        return LATTICE_ERR_VERSION_MISMATCH;
    }

    out_header->magic = magic;
    out_header->version = version;
    out_header->opcode = buf[5];
    out_header->flags = read_be16(buf + 6);
    out_header->sequence_id = read_be64(buf + 8);
    out_header->payload_len = read_be32(buf + 16);
    out_header->checksum = read_be32(buf + 20);

    return LATTICE_OK;
}

lattice_status_t lattice_frame_verify(
    const uint8_t *buf,
    size_t buf_len
) {
    lattice_frame_header_t hdr;
    lattice_status_t status = lattice_frame_decode_header(buf, buf_len, &hdr);
    if (status != LATTICE_OK) {
        return status;
    }

    size_t total_expected = LATTICE_HEADER_SIZE + hdr.payload_len;
    if (buf_len < total_expected) {
        return LATTICE_ERR_BUFFER_UNDERFLOW;
    }

    /* Verify checksum */
    uint32_t crc = lattice_crc32c_update(0xFFFFFFFFU, buf, 20);
    if (hdr.payload_len > 0) {
        crc = lattice_crc32c_update(crc, buf + LATTICE_HEADER_SIZE, hdr.payload_len);
    }
    crc ^= 0xFFFFFFFFU;

    if (crc != hdr.checksum) {
        return LATTICE_ERR_CRC_MISMATCH;
    }

    return LATTICE_OK;
}
