"=============================================================================
 LatticeStore: Unified Bitemporal Event-Sourced Persistence Repository
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeStore [
    | dataDirectory currentWal bitemporalIndex snapshotManager monotonicSeq lock |

    LatticeStore class >> inDirectory: aPath [
        ^ (self new) initializeDirectory: aPath
    ]

    initializeDirectory: aPath [
        dataDirectory := aPath asString.
        Directory create: dataDirectory.
        bitemporalIndex := BitemporalIndex new.
        snapshotManager := SnapshotManager new.
        monotonicSeq := 0.
        lock := Semaphore forMutualExclusion.

        currentWal := WALSegment openPath: (dataDirectory , '/segment-0001.wal') segmentId: 1.
        ^ self
    ]

    bitemporalIndex [
        ^ bitemporalIndex
    ]

    snapshotManager [
        ^ snapshotManager
    ]

    appendEventFor: anAggId eventType: aType validTime: aValid payload: aPayload [
        "Append an event. Assigns monotonic transaction time and sequence number."
        | nowTx seq event encodedRec |
        lock critical: [
            monotonicSeq := monotonicSeq + 1.
            seq := monotonicSeq.
            nowTx := Time millisecondClockValue.

            event := BitemporalEvent aggregateId: anAggId
                                       eventType: aType
                                  sequenceNumber: seq
                                          txTime: nowTx
                                       validTime: aValid
                                         payload: aPayload.

            encodedRec := event encode.
            currentWal appendPayload: encodedRec type: 1 sequenceId: seq.
            bitemporalIndex indexEvent: event.
        ].
        ^ event
    ]

    takeSnapshotFor: anAggId state: aState [
        | lastSeq snap nowTx |
        lock critical: [
            nowTx := Time millisecondClockValue.
            lastSeq := monotonicSeq.
            snap := LatticeSnapshot aggregateId: anAggId sequenceNumber: lastSeq txTime: nowTx state: aState.
            snapshotManager saveSnapshot: snap.
        ].
        ^ snap
    ]

    rehydrateAggregate: anAggId using: anApplierBlock [
        "Rehydrate state by starting with the latest snapshot and replaying subsequent events."
        | snap startSeq state events |
        snap := snapshotManager latestSnapshotFor: anAggId.
        snap ifNotNil: [
            state := snap stateData copy.
            startSeq := snap sequenceNumber.
        ] ifNil: [
            state := Dictionary new.
            startSeq := 0.
        ].

        events := bitemporalIndex eventsForAggregate: anAggId.
        events do: [ :evt |
            evt sequenceNumber > startSeq ifTrue: [
                state := anApplierBlock value: state value: evt.
            ].
        ].
        ^ state
    ]

    rehydrateAggregate: anAggId asOfTransactionTime: maxTx using: anApplierBlock [
        "Historical state reconstruction as known to the system at transaction time maxTx."
        | state events |
        state := Dictionary new.
        events := bitemporalIndex eventsForAggregate: anAggId asOfTransactionTime: maxTx.
        events do: [ :evt |
            state := anApplierBlock value: state value: evt.
        ].
        ^ state
    ]

    rehydrateAggregate: anAggId asOfValidTime: maxValid using: anApplierBlock [
        "Historical state reconstruction as effective in the real world at valid time maxValid."
        | state events |
        state := Dictionary new.
        events := bitemporalIndex eventsForAggregate: anAggId asOfValidTime: maxValid.
        events do: [ :evt |
            state := anApplierBlock value: state value: evt.
        ].
        ^ state
    ]

    close [
        lock critical: [
            currentWal ifNotNil: [ currentWal close ].
        ].
        ^ self
    ]
]
