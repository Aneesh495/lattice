# Lattice top-level Makefile
# Distributed Virtual Actor Mesh and Reactive Object-Graph Database

CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -Werror -pedantic -std=c11 -fPIC -I./native/include
LDFLAGS ?= -shared

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    DYNLIB_EXT := dylib
    DYNLIB_FLAGS := -dynamiclib
else
    DYNLIB_EXT := so
    DYNLIB_FLAGS := -shared
endif

LIB_DIR = lib
NATIVE_LIB = $(LIB_DIR)/liblatticenet.$(DYNLIB_EXT)
NATIVE_TEST_BIN = bin/test_native

NATIVE_SRCS = native/src/crc32c.c \
              native/src/ring_buffer.c \
              native/src/latticenet.c

NATIVE_OBJS = $(patsubst native/src/%.c, build/%.o, $(NATIVE_SRCS))

GST = gst
GST_FLAGS = -q

.PHONY: all native test test-unit test-native test-integration test-stress test-python bench verify clean

all: native test-unit

$(LIB_DIR):
	mkdir -p $(LIB_DIR)

build:
	mkdir -p build

build/%.o: native/src/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

native: $(NATIVE_LIB)

$(NATIVE_LIB): $(NATIVE_OBJS) | $(LIB_DIR)
	$(CC) $(DYNLIB_FLAGS) -o $@ $(NATIVE_OBJS)

test-native: $(NATIVE_LIB)
	$(CC) $(CFLAGS) -o $(NATIVE_TEST_BIN) native/tests/test_native.c -L$(LIB_DIR) -llatticenet
	DYLD_LIBRARY_PATH=$(LIB_DIR):$$DYLD_LIBRARY_PATH LD_LIBRARY_PATH=$(LIB_DIR):$$LD_LIBRARY_PATH ./$(NATIVE_TEST_BIN)

test-unit:
	@echo "Running Lattice Smalltalk Unit Test Suite..."
	@$(GST) $(GST_FLAGS) tests/run_unit_tests.st

test-integration:
	@echo "Running Lattice Multi-Node Integration Test Suite..."
	@$(GST) $(GST_FLAGS) tests/run_integration_tests.st

test-stress:
	@echo "Running Lattice Fault-Injection & Stress Test Suite..."
	@$(GST) $(GST_FLAGS) tests/run_stress_tests.st

test-python:
	@echo "Running Lattice Python Client Test Suite..."
	@PYTHONPATH=python python3 -m unittest discover -s python/tests

test: test-native test-unit test-integration test-stress test-python

bench: native
	@echo "Running Lattice Performance Benchmarks..."
	@$(GST) $(GST_FLAGS) benchmarks/run_benchmarks.st

verify:
	@echo "Executing hard verification pass..."
	@python3 scripts/verify_project.py

clean:
	rm -rf build $(LIB_DIR) $(NATIVE_TEST_BIN) data
