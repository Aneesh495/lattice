"=============================================================================
 SnapshotManager: Object Graph Checkpoints and State Delta Compression
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeSnapshot [
    | aggregateId sequenceNumber txTime stateData checksum |

    LatticeSnapshot class >> aggregateId: anAggId sequenceNumber: aSeq txTime: aTx state: aState [
        ^ (self new) initializeAggregateId: anAggId
                            sequenceNumber: aSeq
                                    txTime: aTx
                                     state: aState
    ]

    initializeAggregateId: anAggId sequenceNumber: aSeq txTime: aTx state: aState [
        aggregateId := anAggId asString.
        sequenceNumber := aSeq.
        txTime := aTx.
        stateData := aState copy.
        checksum := CRC32C checksum: (WireSerializer serialize: stateData).
        ^ self
    ]

    aggregateId [
        ^ aggregateId
    ]

    sequenceNumber [
        ^ sequenceNumber
    ]

    txTime [
        ^ txTime
    ]

    stateData [
        ^ stateData
    ]

    checksum [
        ^ checksum
    ]

    encode [
        | buf stateBytes |
        buf := ByteBuffer allocate: 64.
        buf writeString: aggregateId.
        buf writeUInt64: sequenceNumber.
        buf writeUInt64: txTime.
        stateBytes := WireSerializer serialize: stateData.
        buf writeUInt32: stateBytes size.
        buf writeBytes: stateBytes.
        buf writeUInt32: checksum.
        ^ buf asByteArray
    ]

    LatticeSnapshot class >> decodeFrom: aBuffer [
        | aggId seq tx len stateBytes expectedCrc calculatedCrc s |
        aggId := aBuffer readString.
        seq := aBuffer readUInt64.
        tx := aBuffer readUInt64.
        len := aBuffer readUInt32.
        stateBytes := aBuffer readBytes: len.
        expectedCrc := aBuffer readUInt32.

        calculatedCrc := CRC32C checksum: stateBytes.
        (calculatedCrc = expectedCrc) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'Snapshot CRC32C corruption'
        ].
        s := WireSerializer deserialize: stateBytes.
        ^ self aggregateId: aggId sequenceNumber: seq txTime: tx state: s
    ]
]

Object subclass: SnapshotManager [
    | snapshots lock |

    SnapshotManager class >> new [
        ^ (super new) initialize
    ]

    initialize [
        snapshots := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    saveSnapshot: aSnapshot [
        lock critical: [
            snapshots at: aSnapshot aggregateId put: aSnapshot.
        ].
        ^ aSnapshot
    ]

    latestSnapshotFor: anAggId [
        | snap |
        lock critical: [
            snap := snapshots at: anAggId asString ifAbsent: [ nil ].
        ].
        ^ snap
    ]

    computeDeltaBetween: baseSnapshot and: currentSnapshot [
        "Compute minimal dictionary diff between base state and current state."
        | baseDict currDict delta modified removed |
        baseDict := baseSnapshot stateData.
        currDict := currentSnapshot stateData.
        delta := Dictionary new.
        modified := Dictionary new.
        removed := OrderedCollection new.

        currDict keysAndValuesDo: [ :k :v |
            (baseDict at: k ifAbsent: [ nil ]) ~= v ifTrue: [
                modified at: k put: v.
            ].
        ].

        baseDict keysDo: [ :k |
            (currDict includesKey: k) ifFalse: [
                removed add: k.
            ].
        ].

        delta at: 'modified' put: modified.
        delta at: 'removed' put: removed.
        ^ delta
    ]

    applyDelta: aDelta onto: baseState [
        "Apply delta dictionary to produce updated state."
        | updated modified removed |
        updated := baseState copy.
        modified := aDelta at: 'modified' ifAbsent: [ Dictionary new ].
        removed := aDelta at: 'removed' ifAbsent: [ #() ].

        modified keysAndValuesDo: [ :k :v |
            updated at: k put: v.
        ].
        removed do: [ :k |
            updated removeKey: k ifAbsent: [ nil ].
        ].
        ^ updated
    ]
]
