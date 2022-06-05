"=============================================================================
 KernelTest: Comprehensive Unit Test Suite for Lattice Kernel Primitives
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: KernelTest [

    testLatticeIdGenerationAndFormat [
        | id str id2 |
        id := LatticeId generate.
        self assert: (id bytes size = 16).
        str := id asString.
        self assert: (str size = 36).
        "Check hyphen placements"
        self assert: ((str at: 9) = $-).
        self assert: ((str at: 14) = $-).
        self assert: ((str at: 19) = $-).
        self assert: ((str at: 24) = $-).
        "Check version 4"
        self assert: ((str at: 15) = $4).
        "Check roundtrip parsing"
        id2 := LatticeId fromString: str.
        self assert: id equals: id2.
        self assert: id hash equals: id2 hash.
    ]

    testLatticeIdOrderingAndEquality [
        | b1 b2 id1 id2 |
        b1 := ByteArray new: 16.
        b1 at: 16 put: 1.
        b2 := ByteArray new: 16.
        b2 at: 16 put: 2.
        id1 := LatticeId fromBytes: b1.
        id2 := LatticeId fromBytes: b2.
        self assert: (id1 < id2).
        self deny: (id2 < id1).
        self deny: (id1 = id2).
    ]

    testVectorClockCausality [
        | cA cB cC |
        cA := VectorClock new.
        cA tick: 'node1'.
        cA tick: 'node1'.
        cB := VectorClock new.
        cB tick: 'node2'.

        "Concurrent divergence"
        self assert: (cA concurrentWith: cB).
        self deny: (cA dominates: cB).
        self deny: (cB dominates: cA).

        "Causal join"
        cC := cA merge: cB.
        self assert: (cC dominates: cA).
        self assert: (cC dominates: cB).
        self assert: (cC at: 'node1') equals: 2.
        self assert: (cC at: 'node2') equals: 1.
    ]

    testCapabilityAttenuationAndExpiry [
        | cap child now |
        cap := Capability forResource: 'grain/order/100'
                          operations: #('read' 'write' 'cancel')
                          ttlMilliseconds: 5000.
        self assert: (cap isValidFor: 'read' on: 'grain/order/100').
        self assert: (cap isValidFor: 'write' on: 'grain/order/100').
        self deny: (cap isValidFor: 'admin' on: 'grain/order/100').

        "Attenuate permissions to read-only"
        child := cap attenuate: #('read').
        self assert: (child isValidFor: 'read' on: 'grain/order/100').
        self deny: (child isValidFor: 'write' on: 'grain/order/100').

        "Simulate expiration"
        now := Time millisecondClockValue + 10000.
        self assert: (cap isExpiredAt: now).
        self deny: (cap isValidFor: 'read' on: 'grain/order/100' at: now).

        "Revocation"
        cap revoke.
        self assert: cap isRevoked.
        self deny: (cap isValidFor: 'read' on: 'grain/order/100').
    ]

    testByteBufferReadWritePrimitives [
        | buf |
        buf := ByteBuffer allocate: 64.
        buf writeUInt8: 128.
        buf writeInt8: -42.
        buf writeUInt16: 65530.
        buf writeInt16: -10000.
        buf writeUInt32: 3735928559. "0xDEADBEEF"
        buf writeInt32: -2147483640.
        buf writeUInt64: 9223372036854775807.
        buf writeString: 'Lattice Protocol Engine'.

        self assert: buf readUInt8 equals: 128.
        self assert: buf readInt8 equals: -42.
        self assert: buf readUInt16 equals: 65530.
        self assert: buf readInt16 equals: -10000.
        self assert: buf readUInt32 equals: 3735928559.
        self assert: buf readInt32 equals: -2147483640.
        self assert: buf readUInt64 equals: 9223372036854775807.
        self assert: buf readString equals: 'Lattice Protocol Engine'.
        self assert: buf readableBytes equals: 0.
    ]

    testPriorityQueueAndMailboxFairness [
        | pq mb |
        pq := PriorityQueue new.
        pq push: 'A' priority: 10.
        pq push: 'B' priority: 50.
        pq push: 'C' priority: 30.
        pq push: 'D' priority: 100.
        pq push: 'E' priority: 2.

        self assert: pq pop equals: 'D'.
        self assert: pq pop equals: 'B'.
        self assert: pq pop equals: 'C'.
        self assert: pq pop equals: 'A'.
        self assert: pq pop equals: 'E'.
        self assert: pq isEmpty.

        mb := Mailbox new.
        mb enqueue: 'normal' priority: 10.
        mb enqueue: 'critical' priority: 100.
        self assert: mb dequeue equals: 'critical'.
        self assert: mb dequeue equals: 'normal'.

        mb stash: 'deferred1'.
        mb stash: 'deferred2'.
        self assert: mb stashSize equals: 2.
        mb unstashAll.
        self assert: mb stashSize equals: 0.
        self assert: mb dequeue equals: 'deferred1'.
        self assert: mb dequeue equals: 'deferred2'.
    ]
]
