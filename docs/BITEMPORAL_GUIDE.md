# Bitemporal Event Store and Time-Travel Query Guide

Lattice incorporates a bitemporal event-sourced storage engine. Rather than destructively overwriting object state in-place, every mutation is recorded as an immutable event with dual time coordinates.

---

## 1. Dual Time Coordinate System

Traditional databases track either only when a record was written (Transaction Time) or only when an event occurred (Valid Time). Bitemporal storage captures both simultaneously:

1. **Transaction Time (txTime)**: The physical wall-clock timestamp assigned by the Raft consensus leader when an event is appended to the Write-Ahead Log. This time is monotonic and immutable.
2. **Valid Time (validTime)**: The domain timestamp when the business fact occurred in reality.

```
+-----------------------------------------------------------------------------------+
| Bitemporal Coordinate Grid                                                        |
|                                                                                   |
| Valid Time (Reality)                                                              |
|       ^                                                                           |
| 14:00 |                                            * Event C: Postdated contract  |
|       |                                              (txTime=12:30, valid=14:00)  |
| 12:00 |                 * Event A: Trade executed                                 |
|       |                   (txTime=12:00, valid=12:00)                             |
| 10:00 |                                * Event B: Retroactive correction          |
|       |                                  (txTime=12:15, valid=10:00)              |
|       +----------------------------------------------------------------------->   |
|     10:00             12:00            12:30                        Transaction   |
|                                                                     Time (System) |
+-----------------------------------------------------------------------------------+
```

---

## 2. Event Log Layout

Events are serialized into append-only `.wal` segment files. Each record contains:
- 4 bytes: Record Length
- 1 byte: Record Type (1=Event, 2=Snapshot, 3=Checkpoint)
- 8 bytes: Sequence ID
- N bytes: Payload (encoded with `WireSerializer`)
- 4 bytes: Castagnoli CRC32C trailing checksum

If the process or physical host crashes mid-write, recovery truncates the uncommitted partial trailing bytes and restores the log to the last valid CRC32C record boundary.

---

## 3. Time-Travel Query Algebra

### 3.1 Historical System Knowledge (`asOfTransactionTime`)
Answers: *"What did the system believe at time Tx?"*

```smalltalk
"Retrieve document state as known to the cluster at transaction time 1000"
stateAtTx1000 := store rehydrateAggregate: 'doc-42'
                      asOfTransactionTime: 1000
                                    using: [ :state :evt | ... ].
```

### 3.2 Real-World Reality Snapshot (`asOfValidTime`)
Answers: *"What was the effective real-world state at time Tv?"*

```smalltalk
"Retrieve financial ledger state effective on October 1st"
stateAtValidTime := store rehydrateAggregate: 'acc-901'
                          asOfValidTime: 1727740800000
                                  using: [ :state :evt | ... ].
```

### 3.3 Dual-Axis Point Query
Answers: *"What did we believe the state at domain time Tv was, as of system time Tx?"*

```smalltalk
"Query retroactive correction state"
events := index eventsForAggregate: 'trade-800'
               asOfTransactionTime: 1215
                       asOfValidTime: 1000.
```

---

## 4. Snapshots and Delta Compression

To ensure state rehydration remains O(1) regardless of total event log size:
1. Every N events or upon grain passivation, `SnapshotManager` saves a full object graph checkpoint.
2. `LatticeStore` rehydrates an aggregate by loading the nearest snapshot prior to the target time and replaying only the differential events succeeding the snapshot sequence number.
3. Deltas between snapshots are computed as dictionary diffs, minimizing storage amplification.
