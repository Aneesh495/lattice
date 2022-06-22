/*
 * crc32c.c: Castagnoli CRC32C Implementation
 *
 * Implements CRC32C with generator polynomial 0x1EDC6F41 (reversed: 0x82F63B78).
 * Optimized with static 256-word lookup table and byte slicing.
 */

#include "latticenet.h"
#include <stdbool.h>

static uint32_t crc32c_table[256];
static bool crc32c_initialized = false;

static void init_crc32c_table(void) {
    uint32_t poly = 0x82F63B78U;
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 0; j < 8; j++) {
            if (crc & 1U) {
                crc = (crc >> 1) ^ poly;
            } else {
                crc = crc >> 1;
            }
        }
        crc32c_table[i] = crc;
    }
    crc32c_initialized = true;
}

uint32_t lattice_crc32c_update(uint32_t prev_crc, const uint8_t *data, size_t length) {
    if (!crc32c_initialized) {
        init_crc32c_table();
    }
    if (!data || length == 0) {
        return prev_crc;
    }

    uint32_t crc = prev_crc;
    for (size_t i = 0; i < length; i++) {
        uint8_t table_idx = (uint8_t)((crc ^ data[i]) & 0xFFU);
        crc = (crc >> 8) ^ crc32c_table[table_idx];
    }
    return crc;
}

uint32_t lattice_crc32c(const uint8_t *data, size_t length) {
    uint32_t crc = lattice_crc32c_update(0xFFFFFFFFU, data, length);
    return crc ^ 0xFFFFFFFFU;
}
