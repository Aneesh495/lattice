# Lattice Architecture Specification

Lattice is a distributed virtual actor mesh and reactive object-graph database engineered in Smalltalk, featuring native C network acceleration, Raft consensus, SWIM gossip membership, and bitemporal event sourcing.

```
+-----------------------------------------------------------------------------------+
|                                  Lattice CLI & REPL                               |
|       cluster | grain | stream | replay | query | bench | verify | console        |
+-----------------------------------------------------------------------------------+
                                         |
+-----------------------------------------------------------------------------------+
|                        Polyglot Ingress & Management                              |
|   HTTP/REST API  |  WebSocket Stream  |  Prometheus Metrics  |  Python SDK        |
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

## 1. System Design and Philosophy

Classical Smalltalk was built on the premise that computing is the communication between independent, reflective objects communicating purely via asynchronous messages. However, traditional Smalltalk images were isolated single-workstation universes.

Lattice extends the Smalltalk object space across an arbitrary cluster of distributed nodes, uniting:
1. **Virtual Actors (Grains)**: Logical identities that exist perpetually without physical node pinning, auto-activating on demand.
2. **Deterministic Single-Threaded Turns**: Each virtual actor processes one message at a time, eliminating locks, mutexes, and race conditions from domain logic.
3. **Decentralized Membership**: Scalable Weakly-consistent Infection-style Process Group Membership (SWIM) protocol with suspicion mechanics to detect failures in sub-second time without O(N^2) broadcast overhead.
4. **Linearizable Consensus**: A Raft consensus engine for global state changes, leader leases, and grain placement coordination.
5. **Bitemporal Object-Graph Storage**: An append-only Write-Ahead Log (WAL) recording state mutations along dual time axes: Transaction Time (system commit horizon) and Valid Time (domain reality horizon).
6. **Reactive Stream Processing**: Full compliance with the Reactive Streams specification with dynamic demand signaling, tumbling/sliding/session windows, and watermark heuristics.

---

## 2. Virtual Actor Runtime (Grains)

### 2.1 Grain Identity and Addressing
Grains are addressed by `GrainId`, composed of a grain type symbol (e.g., `#Account`, `#DeviceTracker`) and a partition key string (e.g., `'acc-1049'`).

```
+--------------------------------------------------------+
|                      GrainId                           |
|   Type: #Account             Key: "acc-9042"           |
|   Canonical String: "Account/acc-9042"                 |
|   32-bit FNV-1a Hash: 0x7E3A9104                       |
+--------------------------------------------------------+
```

### 2.2 Lifecycle State Transitions

A grain transitions through four distinct lifecycle states:

```
    [ Inactive on Disk / Storage ]
                  |
         Message Arrival (send:)
                  v
           [ Activating ]
                  |
             onActivate
                  v
             [ Active ] <-------+
            /          \        |
   Turn Dispatch   Idle Timeout | New Message
          /              \      |
    executeTurn           v     |
                         [ Passivating ]
                                |
                           onPassivate
                                v
                   [ Inactive on Disk / Storage ]
```

1. **Inactive**: The grain resides purely as historical events and snapshots in the bitemporal store. No memory or execution resources are allocated.
2. **Activating**: When a message targets the grain, the `GrainManager` allocates a `GrainContext`, invokes `onActivate`, and rehydrates state from the latest snapshot plus subsequent WAL events.
3. **Active**: The grain resides in memory. Its `GrainDispatcher` continuously pulls messages from its priority `Mailbox` and executes turns sequentially.
4. **Passivating**: If no messages arrive within `ttlMilliseconds`, the manager initiates passivation: invokes `onPassivate`, persists an updated checkpoint delta, closes the mailbox, and evicts the instance from memory.

---

## 3. Consensus and Cluster Membership

### 3.1 Consistent Hash Ring
Lattice distributes grain partition keys across physical nodes using a consistent hash ring with virtual nodes (default: 128 virtual points per physical node).

```
                      Physical Node A (vnodes 0..127)
                                 *  *  *
                            *               *
                       *                         *
     Physical Node C                                   Physical Node B
    (vnodes 256..383)                                 (vnodes 128..255)
                       *                         *
                            *               *
                                 *  *  *
```

- **Lookup Complexity**: O(log(V * N)) via binary search across sorted ring points.
- **Failover**: When a physical node fails, only 1/N of the ring keys are remapped to successor nodes. The remaining (N-1)/N keys remain untouched.

### 3.2 SWIM Gossip Failure Detector
The cluster monitors node availability using the SWIM protocol:
1. **Direct Ping**: Every protocol period T, a node randomly selects a peer and transmits a `LATTICE_OP_HEARTBEAT` frame.
2. **Indirect PingReq**: If no `Ack` arrives within round-trip timeout, the node requests k helper nodes to ping the target via `LATTICE_OP_PING_REQ`.
3. **Suspicion Mechanism**: If indirect pings fail, the target is marked `#suspect`. A suspicion timer starts. If the suspect node does not refute the suspicion with an incremented incarnation number before the timer expires, it is marked `#dead`.
4. **Self-Refutation**: If a node discovers it is being suspected by peers, it increments its local incarnation number and broadcasts an `#alive` announcement to refute the false suspicion.

### 3.3 Raft Consensus State Machine
Critical cluster metadata (membership transitions, lease grants) is replicated using Raft consensus:
- **Election Safety**: At most one leader can be elected per term.
- **Leader Append-Only**: A leader never overwrites or truncates its own log entries.
- **Log Matching**: If two logs contain an entry with the same index and term, then the logs are identical in all entries up through the given index.
- **Quorum Commitment**: An entry is committed once replicated across (N // 2) + 1 cluster nodes.

---

## 4. Bitemporal Event Store & Object Graph

### 4.1 Dual Time Dimensions
Every state mutation records two immutable timestamps:
1. **Transaction Time (txTime)**: System time when the event was appended to the Write-Ahead Log. Assigned by consensus leader. Monotonically increasing.
2. **Valid Time (validTime)**: Real-world domain time when the fact occurred or became effective.

```
       Valid Time (Domain Reality)
           ^
           |              (Event 3: Scheduled future change)
           |                  txTime=300, validTime=500
           |
           |    (Event 1: Created)
           |        txTime=100, validTime=100
           |
           |              (Event 2: Retroactive amendment)
           |                  txTime=200, validTime=80
           +----------------------------------------------> Transaction Time (System Horizon)
```

### 4.2 Time-Travel Queries
- `asOfTransactionTime(Tx)`: Answers "What did the system believe at time Tx?"
- `asOfValidTime(Tv)`: Answers "What was the real-world state at time Tv?"
- `asOfTransactionTime(Tx, Tv)`: Answers "What did we believe the state at time Tv was, as of system time Tx?"

---

## 5. Reactive Streams & Dynamic Dataflow

The stream subsystem provides push-pull stream transformations:
- **Demand Contract**: Consumers signal capacity via `request(n)`. Producers must never emit more than n items without further demand.
- **Tumbling Windows**: Fixed, contiguous, non-overlapping time intervals.
- **Sliding Windows**: Overlapping time intervals advancing by configurable slide steps.
- **Session Windows**: Dynamic windows bounded by inactivity gap periods.
- **Watermark Manager**: Tracks event-time progress and directs late-arriving events to side outputs without stalling pipelines.
