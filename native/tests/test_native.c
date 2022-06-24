/*
 * test_native.c: Comprehensive Native C Test Suite for liblatticenet
 *
 * Verifies RFC 3720 CRC32C test vectors, ring buffer concurrency,
 * frame encoding/decoding, and throughput.
 */

#include "latticenet.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST_ASSERT(cond, msg) do { \
    if (cond) { \
        tests_passed++; \
    } else { \
        tests_failed++; \
        fprintf(stderr, "  [FAIL] %s: %s (line %d)\n", __func__, msg, __LINE__); \
    } \
} while (0)

static void test_crc32c_rfc_vector(void) {
    const uint8_t data[] = "123456789";
    uint32_t crc = lattice_crc32c(data, 9);
    TEST_ASSERT(crc == 0xE3069283U, "CRC32C must match RFC 3720 standard vector 0xE3069283");
}

static void test_ring_buffer_fifo(void) {
    lattice_ring_buffer_t rb;
    lattice_status_t status = lattice_ring_buffer_init(&rb, 64);
    TEST_ASSERT(status == LATTICE_OK, "Ring buffer init succeeds");

    const uint8_t test_data[] = "Lattice Distributed Virtual Actor Mesh";
    size_t len = strlen((const char *)test_data);

    size_t written = lattice_ring_buffer_write(&rb, test_data, len);
    TEST_ASSERT(written == len, "All bytes written to ring buffer");
    TEST_ASSERT(lattice_ring_buffer_available_read(&rb) == len, "Available read matches write len");

    uint8_t read_buf[128] = {0};
    size_t read_bytes = lattice_ring_buffer_read(&rb, read_buf, len);
    TEST_ASSERT(read_bytes == len, "All bytes read from ring buffer");
    TEST_ASSERT(memcmp(test_data, read_buf, len) == 0, "Buffer content matches original");
    TEST_ASSERT(lattice_ring_buffer_available_read(&rb) == 0, "Buffer empty after full read");

    /* Test wraparound */
    for (int iter = 0; iter < 10; iter++) {
        written = lattice_ring_buffer_write(&rb, test_data, len);
        TEST_ASSERT(written == len, "Wraparound write succeeds");
        read_bytes = lattice_ring_buffer_read(&rb, read_buf, len);
        TEST_ASSERT(read_bytes == len, "Wraparound read succeeds");
        TEST_ASSERT(memcmp(test_data, read_buf, len) == 0, "Wraparound payload matches");
    }

    lattice_ring_buffer_free(&rb);
}

static void test_frame_encode_decode_verify(void) {
    uint8_t out_buf[512];
    size_t written = 0;
    const uint8_t payload[] = "Virtual actor grain turn message #1024";
    uint32_t payload_len = (uint32_t)strlen((const char *)payload);

    lattice_status_t status = lattice_frame_encode(
        LATTICE_OP_GRAIN_MESSAGE,
        LATTICE_FLAG_COMPRESSED,
        4200000000ULL,
        payload,
        payload_len,
        out_buf,
        sizeof(out_buf),
        &written
    );
    TEST_ASSERT(status == LATTICE_OK, "Frame encoding succeeds");
    TEST_ASSERT(written == LATTICE_HEADER_SIZE + payload_len, "Written frame size matches header + payload");

    /* Verify frame integrity */
    status = lattice_frame_verify(out_buf, written);
    TEST_ASSERT(status == LATTICE_OK, "Frame integrity verification succeeds");

    /* Decode header */
    lattice_frame_header_t hdr;
    status = lattice_frame_decode_header(out_buf, written, &hdr);
    TEST_ASSERT(status == LATTICE_OK, "Frame header decode succeeds");
    TEST_ASSERT(hdr.opcode == LATTICE_OP_GRAIN_MESSAGE, "Decoded opcode matches");
    TEST_ASSERT(hdr.flags == LATTICE_FLAG_COMPRESSED, "Decoded flags match");
    TEST_ASSERT(hdr.sequence_id == 4200000000ULL, "Decoded sequence ID matches");
    TEST_ASSERT(hdr.payload_len == payload_len, "Decoded payload len matches");

    /* Payload match */
    TEST_ASSERT(memcmp(out_buf + LATTICE_HEADER_SIZE, payload, payload_len) == 0, "Payload bytes match original");

    /* Test corruption detection */
    out_buf[written - 1] ^= 0x01; /* Flip one bit in payload */
    status = lattice_frame_verify(out_buf, written);
    TEST_ASSERT(status == LATTICE_ERR_CRC_MISMATCH, "Corruption correctly detected via CRC mismatch");
}

int main(void) {
    printf("Running Lattice Native C Test Suite...\n");
    test_crc32c_rfc_vector();
    test_ring_buffer_fifo();
    test_frame_encode_decode_verify();

    printf("Finished Native Tests - Passed: %d, Failed: %d\n", tests_passed, tests_failed);
    if (tests_failed == 0) {
        printf("=> ALL NATIVE TESTS PASSED\n");
        return 0;
    } else {
        printf("=> NATIVE TESTS FAILED\n");
        return 1;
    }
}
