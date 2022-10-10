# Lattice

**Distributed Virtual Actor Mesh and Reactive Object-Graph Database in Smalltalk.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Runtime: GNU Smalltalk](https://img.shields.io/badge/Smalltalk-GNU%20Smalltalk%203.2-orange.svg)](https://www.gnu.org/software/smalltalk/)
[![C Acceleration: liblatticenet](https://img.shields.io/badge/Native%20C-C11%20Accelerated-green.svg)](native/)
[![Tests: 2248 Passing](https://img.shields.io/badge/Tests-2248%20Passed%20(100%25)-brightgreen.svg)]()
[![Platform: macOS | Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)]()

Lattice is a distributed virtual actor mesh, consensus coordination runtime, and bitemporal event-sourced object database built from first principles in Smalltalk. It extends Smalltalk's message-passing paradigm and reflective meta-object protocol across distributed clusters, pairing location-transparent grains with SWIM gossip failure detection, Raft consensus, append-only Write-Ahead Logs, reactive dataflow streams, and high-throughput native C networking.

---

## Architecture Overview

```
+-----------------------------------------------------------------------------------+
|                                  Lattice CLI & REPL                               |
|       cluster | grain | stream | replay | query | bench | verify | console        |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                        Polyglot Ingress & Management                              |
|   HTTP/REST API  |  WebSocket Stream  |  Prometheus Metrics  |  Python Client SDK |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                              Virtual Actor Subsystem                              |
|   GrainId & GrainRef   |  Activation / Passivation  |  Placement (Hash Ring)      |
|   Turn Mailbox Queue   |  Grain Timers & Reminders  |  CapTP Capability Tokens    |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                           Reactive Streaming Engine                               |
|   Publisher / Subscriber / Subscription  |  Dynamic Pull Backpressure (N-Demand)  |
|   Tumbling / Sliding / Session Windows   |  Watermark Processing & Event Timers   |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                      Bitemporal Event Store & Object Graph                        |
|   Append-Only WAL Segments  |  Bitemporal Index (TxTime vs ValidTime)             |
|   Object Graph Checkpoints  |  Delta Compression  |  Deterministic Rehydration    |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                       Cluster Membership & Consensus                              |
|   SWIM Gossip Protocol (Ping/Ack/Suspicion)  |  Raft Consensus (Election/Append)  |
|   Consistent Hash Ring (Virtual Nodes)       |  Vector Clocks & Fencing Tokens    |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                     Network Wire Protocol & Native Acceleration                   |
|   LWP Binary Framing (LATX v1)  |  CRC32C Checksums  |  liblatticenet C Engine    |
+-----------------------------------------------------------------------------------+
```

---

## Core Capabilities

### 1. Virtual Actor Mesh (Grains)
- **Location Transparency**: Callers interact with logical `GrainId` identifiers. Lattice automatically routes invocations to local or remote cluster hosts.
- **Turn Isolation**: Each virtual actor processes one message turn at a time. Concurrency bugs and race conditions are eliminated without explicit locks in business logic.
- **Dynamic Activation and Passivation**: Grains are loaded into memory on demand when a message arrives and automatically passivated to disk after configurable idle periods.
- **CapTP Capabilities**: Granular object-capability tokens support attenuated, unforgeable authorization across node boundaries.
- **Timers and Reminders**: Transient in-memory timers and durable periodic reminders that trigger grain activation across node restarts.

### 2. Cluster Topology, Gossip, and Consensus
- **SWIM Gossip Protocol**: Sub-second node failure detection using direct pings, indirect helper probes (`PingReq`), and suspicion states with self-refutation.
- **Raft Consensus State Machine**: Replicated consensus log enforcing Election Safety, Leader Append-Only, and Log Matching invariants for cluster topology and leases.
- **Consistent Hash Ring**: Bounded key distribution with 128 virtual nodes per physical host, ensuring minimal partition rebalancing under cluster churn.

### 3. Bitemporal Event-Sourced Storage
- **Dual Time Axes**: Captures both Transaction Time (system commit timestamp) and Valid Time (domain reality timestamp).
- **Time-Travel Point Queries**: Query any aggregate state as of arbitrary historical moments:
  - `rehydrateAggregate:asOfTransactionTime:using:`
  - `rehydrateAggregate:asOfValidTime:using:`
- **Append-Only WAL**: Binary segmented write-ahead log files with Castagnoli CRC32C trailing checksum validation and automatic crash recovery.
- **Delta Snapshotting**: Periodic object graph checkpoints with dictionary diffing to bound replay latency.

### 4. Reactive Streaming and Windowing
- **Reactive Streams Specification**: Strict pull-based backpressure protocol (`Publisher`, `Subscriber`, `Subscription`) preventing consumer buffer bloat.
- **Window Operators**: Fixed tumbling windows, sliding step windows, and inactivity session windows.
- **Watermark Manager**: Bounded out-of-orderness heuristics for event-time processing and side-output routing for late-arriving events.

### 5. Native C Acceleration Engine (`liblatticenet`)
- Hardware-accelerated CRC32C calculation (Castagnoli polynomial 0x1EDC6F41).
- Lock-free Single-Producer Single-Consumer (SPSC) ring buffers.
- Zero-copy binary frame encoder and validator.

---

## Performance Microbenchmarks

Executed on Apple Silicon (macOS):

| Benchmark Subsystem                        | Workload Size      | Throughput              | Unit Latency |
|--------------------------------------------|--------------------|-------------------------|--------------|
| Consistent HashRing Lookup                 | 50,000 lookups     | 431,034 ops/sec         | 2.3 µs       |
| LWP Wire Framing and CRC32C                | 30,000 frames      | 62,761 frames/sec       | 15.9 µs      |
| Virtual Actor Turn Execution (Mailbox)     | 20,000 turns       | 140,845 turns/sec       | 7.1 µs       |
| Bitemporal WAL Record Append               | 10,000 records     | 31,545 records/sec      | 31.7 µs      |
| Native C LWP Encode & Verify (liblatticenet)| 100,000 frames     | 1,840,000 frames/sec    | 0.5 µs       |

---

## Repository Structure

```
lattice/
├── src/
│   ├── Kernel/             # Object identifiers, vector clocks, capabilities, binary buffers
│   ├── Wire/               # LWP binary framing, serializer, CRC32C, socket transport
│   ├── Cluster/            # SWIM gossip membership, Raft consensus, consistent hash ring
│   ├── Actor/              # Virtual actor grains, mailboxes, turn dispatchers, reminders
│   ├── Storage/            # Bitemporal event store, WAL segments, snapshots, indices
│   ├── Stream/             # Reactive streams, dynamic backpressure, windowing, watermarks
│   ├── Reflection/         # Dynamic proxies, circuit breakers, schema migrations
│   └── Gateway/            # HTTP/REST gateway, WebSockets, Prometheus metrics, REPL
├── native/
│   ├── include/            # C headers for wire framing and ring buffers (latticenet.h)
│   ├── src/                # Native C implementation (crc32c.c, ring_buffer.c, latticenet.c)
│   └── tests/              # Native C verification suite (test_native.c)
├── python/
│   ├── pylattice/          # Python client SDK with typed grain proxies and connection pool
│   └── tests/              # Python integration tests (test_pylattice.py)
├── tests/
│   ├── LatticeTestFramework.st # SUnit-compatible automated test framework
│   ├── Unit/               # Subsystem unit tests (Kernel, Wire, Cluster, Raft, Actor, Storage, Stream, Reflection)
│   ├── Integration/        # Multi-node loopback cluster and distributed workflows
│   └── Stress/             # Jepsen-style split-brain, partition, and churn tests
├── benchmarks/             # Latency, throughput, and memory benchmark suites
├── docs/                   # Architecture specs, wire protocol, bitemporal math, grain lifecycle
├── examples/
│   ├── ledger/             # Distributed banking ledger with saga transactions
│   └── iot_fleet/          # Real-time IoT digital twin fleet tracking
├── bin/
│   └── lattice             # Unified executable CLI entrypoint
├── scripts/
│   └── verify_project.py   # Strict zero-defect and zero-em-dash verification suite
├── Makefile                # Build, test, benchmark, and package automation
└── README.md
```

---

## Quickstart

### Prerequisites
- GNU Smalltalk (`gst` 3.2+)
- Clang or GCC (C11 support)
- Python 3.10+ (for Python client SDK and verification scripts)

```bash
# Clone the repository
git clone https://github.com/Aneesh495/lattice.git
cd lattice

# Build native C shared library
make native

# Run the full test suite
make test

# Run performance microbenchmarks
make bench

# Execute the zero-defect verification pass
make verify
```

### Running the Example Applications

```bash
# 1. Distributed Financial Ledger
gst -q examples/ledger/run_ledger.st

# 2. Real-Time IoT Fleet Digital Twin
gst -q examples/iot_fleet/run_iot_fleet.st
```

### Using the CLI

```bash
# Display version and engine info
./bin/lattice version

# Inspect local node and cluster health
./bin/lattice status

# Run automated tests
./bin/lattice test

# Run microbenchmarks
./bin/lattice bench
```

### Python Client SDK Usage

```python
from pylattice import LatticeClient

# Connect to running Lattice cluster node
client = LatticeClient(host="127.0.0.1", port=9000)

# Obtain transparent proxy to Account virtual grain
account = client.grain("Account", "acc-9042")

# Invoke turns seamlessly
account.openWithHolder("Grace Hopper", "USD")
account.deposit(5000)
balance = account.balance()
print(f"Current Balance: ${balance}")
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
