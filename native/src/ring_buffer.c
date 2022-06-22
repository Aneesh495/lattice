/*
 * ring_buffer.c: Lock-free Single-Producer Single-Consumer (SPSC) Ring Buffer
 *
 * Implements bounded circular FIFO queue utilizing memory barriers and
 * power-of-two modulo masking for optimal zero-copy streaming.
 */

#include "latticenet.h"
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

static size_t next_power_of_two(size_t n) {
    if (n < 2) return 2;
    size_t val = 1;
    while (val < n) {
        val <<= 1;
    }
    return val;
}

lattice_status_t lattice_ring_buffer_init(lattice_ring_buffer_t *rb, size_t capacity) {
    if (!rb) return LATTICE_ERR_INVALID_ARG;
    size_t cap = next_power_of_two(capacity < 64 ? 64 : capacity);
    rb->buffer = (uint8_t *)malloc(cap);
    if (!rb->buffer) {
        return LATTICE_ERR_BUFFER_OVERFLOW;
    }
    rb->capacity = cap;
    rb->mask = cap - 1;
    atomic_init(&rb->head, 0);
    atomic_init(&rb->tail, 0);
    return LATTICE_OK;
}

void lattice_ring_buffer_free(lattice_ring_buffer_t *rb) {
    if (rb && rb->buffer) {
        free(rb->buffer);
        rb->buffer = NULL;
        rb->capacity = 0;
        rb->mask = 0;
    }
}

size_t lattice_ring_buffer_available_read(const lattice_ring_buffer_t *rb) {
    if (!rb) return 0;
    size_t head = atomic_load_explicit(&rb->head, memory_order_acquire);
    size_t tail = atomic_load_explicit(&rb->tail, memory_order_acquire);
    return head - tail;
}

size_t lattice_ring_buffer_available_write(const lattice_ring_buffer_t *rb) {
    if (!rb) return 0;
    size_t head = atomic_load_explicit(&rb->head, memory_order_acquire);
    size_t tail = atomic_load_explicit(&rb->tail, memory_order_acquire);
    return rb->capacity - (head - tail);
}

size_t lattice_ring_buffer_write(lattice_ring_buffer_t *rb, const uint8_t *src, size_t len) {
    if (!rb || !src || len == 0) return 0;
    size_t avail = lattice_ring_buffer_available_write(rb);
    size_t to_write = len < avail ? len : avail;
    if (to_write == 0) return 0;

    size_t head = atomic_load_explicit(&rb->head, memory_order_relaxed);
    size_t offset = head & rb->mask;
    size_t first_part = rb->capacity - offset;

    if (to_write <= first_part) {
        memcpy(rb->buffer + offset, src, to_write);
    } else {
        memcpy(rb->buffer + offset, src, first_part);
        memcpy(rb->buffer, src + first_part, to_write - first_part);
    }

    atomic_store_explicit(&rb->head, head + to_write, memory_order_release);
    return to_write;
}

size_t lattice_ring_buffer_read(lattice_ring_buffer_t *rb, uint8_t *dst, size_t len) {
    if (!rb || !dst || len == 0) return 0;
    size_t avail = lattice_ring_buffer_available_read(rb);
    size_t to_read = len < avail ? len : avail;
    if (to_read == 0) return 0;

    size_t tail = atomic_load_explicit(&rb->tail, memory_order_relaxed);
    size_t offset = tail & rb->mask;
    size_t first_part = rb->capacity - offset;

    if (to_read <= first_part) {
        memcpy(dst, rb->buffer + offset, to_read);
    } else {
        memcpy(dst, rb->buffer + offset, first_part);
        memcpy(dst + first_part, rb->buffer, to_read - first_part);
    }

    atomic_store_explicit(&rb->tail, tail + to_read, memory_order_release);
    return to_read;
}
