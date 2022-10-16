"=============================================================================
 TransactionCoordinator: Two-Phase Commit (2PC) Distributed Transaction Engine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: TransactionContext [
    | txId participants mutations status startTimeMs lock |

    TransactionContext class >> id: anId [
        ^ (self new) initializeId: anId
    ]

    initializeId: anId [
        txId := anId.
        participants := OrderedCollection new.
        mutations := Dictionary new.
        status := #active.
        startTimeMs := Time millisecondClockValue.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    txId [
        ^ txId
    ]

    status [
        ^ status
    ]

    participants [
        ^ participants copy
    ]

    enlistParticipant: aGrainRef [
        lock critical: [
            (participants includes: aGrainRef) ifFalse: [
                participants add: aGrainRef.
            ].
        ].
        ^ self
    ]

    recordMutationFor: aGrainRef mutations: aDict [
        lock critical: [
            mutations at: aGrainRef put: aDict.
        ].
        ^ self
    ]

    mutationsFor: aGrainRef [
        ^ mutations at: aGrainRef ifAbsent: [ Dictionary new ]
    ]

    setStatus: aStatus [
        lock critical: [ status := aStatus ].
        ^ self
    ]
]

Object subclass: TransactionCoordinator [
    | activeTransactions lock |

    TransactionCoordinator class >> new [
        ^ (super new) initialize
    ]

    initialize [
        activeTransactions := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    beginTransaction [
        | txId tx |
        txId := LatticeId generate.
        tx := TransactionContext id: txId.
        lock critical: [
            activeTransactions at: txId put: tx.
        ].
        ^ tx
    ]

    executeTransaction: aTxContext [
        "Two-Phase Commit Protocol Execution:
         Phase 1: Prepare all enlisted participants.
         Phase 2: If all succeed, commit all; otherwise abort all."
        | allPrepared |
        aTxContext setStatus: #preparing.
        allPrepared := true.

        "Phase 1: Prepare"
        aTxContext participants do: [ :grainRef |
            | res |
            res := [
                grainRef prepareTransaction: aTxContext txId
                              withMutations: (aTxContext mutationsFor: grainRef)
            ] on: Error do: [ :ex | false ].
            res == true ifFalse: [ allPrepared := false ].
        ].

        "Phase 2: Decision"
        allPrepared ifTrue: [
            aTxContext setStatus: #committed.
            aTxContext participants do: [ :grainRef |
                [ grainRef commitTransaction: aTxContext txId ] on: Error do: [ :ex | nil ].
            ].
            lock critical: [ activeTransactions removeKey: aTxContext txId ifAbsent: [ nil ] ].
            ^ true
        ] ifFalse: [
            aTxContext setStatus: #aborted.
            aTxContext participants do: [ :grainRef |
                [ grainRef abortTransaction: aTxContext txId ] on: Error do: [ :ex | nil ].
            ].
            lock critical: [ activeTransactions removeKey: aTxContext txId ifAbsent: [ nil ] ].
            ^ false
        ].
    ]
]
