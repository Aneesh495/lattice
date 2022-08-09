"=============================================================================
 StorageTest: Comprehensive Unit Test Suite for Bitemporal Storage Engine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: StorageTest [

    testWalRecordEncodeDecode [
        | payload rec encoded buf decoded |
        payload := 'Event payload record #42' asByteArray.
        rec := WALRecord type: 1 sequenceId: 1049 payload: payload.

        encoded := rec encode.
        buf := ByteBuffer wrap: encoded.
        decoded := WALRecord decodeFrom: buf.

        self assert: decoded recordType equals: 1.
        self assert: decoded sequenceId equals: 1049.
        self assert: decoded payload asString equals: payload asString.
        self assert: decoded checksum equals: (CRC32C checksum: payload).
    ]

    testBitemporalEventSerialization [
        | p evt encoded buf decoded |
        p := Dictionary new.
        p at: 'action' put: 'transfer'; at: 'amount' put: 500.

        evt := BitemporalEvent aggregateId: 'Account/acc-99'
                                 eventType: #FundsTransferred
                            sequenceNumber: 3
                                    txTime: 100000
                                 validTime: 95000
                                   payload: p.

        encoded := evt encode.
        buf := ByteBuffer wrap: encoded.
        decoded := BitemporalEvent decodeFrom: buf.

        self assert: decoded aggregateId equals: 'Account/acc-99'.
        self assert: decoded eventType equals: #FundsTransferred.
        self assert: decoded sequenceNumber equals: 3.
        self assert: decoded txTime equals: 100000.
        self assert: decoded validTime equals: 95000.
        self assert: (decoded payload at: 'amount') equals: 500.
    ]

    testBitemporalIndexDualAxisQueries [
        | idx e1 e2 e3 qTx qValid qBoth |
        idx := BitemporalIndex new.

        "e1: Tx=100, Valid=100"
        e1 := BitemporalEvent aggregateId: 'doc-1' eventType: #Created sequenceNumber: 1 txTime: 100 validTime: 100 payload: Dictionary new.
        "e2: Tx=200, Valid=150 (backdated retroactive fact)"
        e2 := BitemporalEvent aggregateId: 'doc-1' eventType: #Amended sequenceNumber: 2 txTime: 200 validTime: 150 payload: Dictionary new.
        "e3: Tx=300, Valid=400 (postdated future fact)"
        e3 := BitemporalEvent aggregateId: 'doc-1' eventType: #Scheduled sequenceNumber: 3 txTime: 300 validTime: 400 payload: Dictionary new.

        idx indexEvent: e1; indexEvent: e2; indexEvent: e3.

        "Query as of Tx 150 (before e2 was known to the system)"
        qTx := idx eventsForAggregate: 'doc-1' asOfTransactionTime: 150.
        self assert: qTx size equals: 1.
        self assert: (qTx at: 1) sequenceNumber equals: 1.

        "Query as of Valid 200 (should include e1 and retroactive e2, but not postdated e3)"
        qValid := idx eventsForAggregate: 'doc-1' asOfValidTime: 200.
        self assert: qValid size equals: 2.

        "Point query: as of Tx 150 and Valid 200"
        qBoth := idx eventsForAggregate: 'doc-1' asOfTransactionTime: 150 asOfValidTime: 200.
        self assert: qBoth size equals: 1.
    ]

    testSnapshotDeltaComputation [
        | mgr s1 s2 snap1 snap2 delta patched |
        mgr := SnapshotManager new.

        s1 := Dictionary new.
        s1 at: 'balance' put: 100; at: 'status' put: 'active'; at: 'temp' put: 'deleteMe'.
        snap1 := LatticeSnapshot aggregateId: 'acc-1' sequenceNumber: 10 txTime: 1000 state: s1.

        s2 := Dictionary new.
        s2 at: 'balance' put: 250; at: 'status' put: 'active'; at: 'tier' put: 'gold'.
        snap2 := LatticeSnapshot aggregateId: 'acc-1' sequenceNumber: 15 txTime: 2000 state: s2.

        delta := mgr computeDeltaBetween: snap1 and: snap2.
        self assert: ((delta at: 'modified') at: 'balance') equals: 250.
        self assert: ((delta at: 'modified') at: 'tier') equals: 'gold'.
        self assert: ((delta at: 'removed') includes: 'temp').

        patched := mgr applyDelta: delta onto: s1.
        self assert: (patched at: 'balance') equals: 250.
        self assert: (patched at: 'tier') equals: 'gold'.
        self deny: (patched includesKey: 'temp').
    ]

    testLatticeStoreStateRehydration [
        | store applier finalState |
        store := LatticeStore inDirectory: '/tmp/lattice_test_store'.

        applier := [ :state :evt |
            | amt |
            amt := evt payload at: 'amount'.
            evt eventType = #Deposit ifTrue: [
                state at: 'balance' put: ((state at: 'balance' ifAbsent: [ 0 ]) + amt).
            ].
            state
        ].

        store appendEventFor: 'acc-wallet' eventType: #Deposit validTime: 1000 payload: (Dictionary new at: 'amount' put: 50; yourself).
        store appendEventFor: 'acc-wallet' eventType: #Deposit validTime: 2000 payload: (Dictionary new at: 'amount' put: 150; yourself).

        "Take snapshot at balance=200"
        store takeSnapshotFor: 'acc-wallet' state: (Dictionary new at: 'balance' put: 200; yourself).

        "Subsequent event"
        store appendEventFor: 'acc-wallet' eventType: #Deposit validTime: 3000 payload: (Dictionary new at: 'amount' put: 75; yourself).

        finalState := store rehydrateAggregate: 'acc-wallet' using: applier.
        self assert: (finalState at: 'balance') equals: 275.

        store close.
    ]
]
