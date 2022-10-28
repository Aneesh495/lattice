"=============================================================================
 AdvancedTest: Unit Test Suite for BloomFilter, B+Tree, 2PC, CEP, ARC, and Trie
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: MockTxParticipant [
    | shouldVoteYes prepared committed aborted |

    onActivate [
        shouldVoteYes := true.
        prepared := false.
        committed := false.
        aborted := false.
    ]

    setVoteYes: aBoolean [
        shouldVoteYes := aBoolean.
    ]

    prepareTransaction: aTxId withMutations: aMutations [
        prepared := true.
        ^ shouldVoteYes
    ]

    commitTransaction: aTxId [
        committed := true.
        ^ self
    ]

    abortTransaction: aTxId [
        aborted := true.
        ^ self
    ]

    isCommitted [
        ^ committed
    ]

    isAborted [
        ^ aborted
    ]
]

LatticeTestCase subclass: AdvancedTest [

    testBloomFilterNoFalseNegatives [
        | bf |
        bf := BloomFilter expectedElements: 100 falsePositiveRate: 0.01.
        bf add: 'apple'; add: 'banana'; add: 'cherry'.

        self assert: (bf mightContain: 'apple').
        self assert: (bf mightContain: 'banana').
        self assert: (bf mightContain: 'cherry').
        self deny: (bf mightContain: 'dragonfruit_definitely_absent').
    ]

    testBPlusTreeInsertAndRangeScan [
        | tree range |
        tree := BPlusTree order: 4.
        tree put: 10 value: 'ten'.
        tree put: 20 value: 'twenty'.
        tree put: 5 value: 'five'.
        tree put: 15 value: 'fifteen'.
        tree put: 25 value: 'twenty-five'.
        tree put: 30 value: 'thirty'.

        self assert: (tree at: 10) equals: 'ten'.
        self assert: (tree at: 25) equals: 'twenty-five'.
        self assert: (tree at: 99) isNil.

        range := tree rangeFrom: 10 to: 25.
        self assert: range size equals: 4.
        self assert: ((range first) at: 'key') equals: 10.
        self assert: ((range last) at: 'key') equals: 25.
    ]

    testTwoPhaseCommitCoordination [
        | coord mgr gid1 gid2 p1 p2 tx success |
        coord := TransactionCoordinator new.
        mgr := GrainManager new.
        mgr registerGrainType: #MockTxParticipant class: MockTxParticipant.

        gid1 := GrainId type: #MockTxParticipant key: 'p1'.
        gid2 := GrainId type: #MockTxParticipant key: 'p2'.
        p1 := (mgr getOrCreateGrain: gid1) grainInstance.
        p2 := (mgr getOrCreateGrain: gid2) grainInstance.

        tx := coord beginTransaction.
        tx enlistParticipant: p1.
        tx enlistParticipant: p2.

        success := coord executeTransaction: tx.
        self assert: success.
        self assert: p1 isCommitted.
        self assert: p2 isCommitted.

        "Failure scenario: p2 votes NO"
        p2 setVoteYes: false.
        tx := coord beginTransaction.
        tx enlistParticipant: p1.
        tx enlistParticipant: p2.

        success := coord executeTransaction: tx.
        self deny: success.
        self assert: p1 isAborted.
        self assert: p2 isAborted.
    ]

    testCEPPatternMatching [
        | cep e1 e2 e3 matches |
        cep := CEPPatternEngine new.
        cep followedBy: #LoginFailed where: [ :e | true ].
        cep followedBy: #AccountLocked where: [ :e | true ].
        cep withinMilliseconds: 5000.

        e1 := BitemporalEvent aggregateId: 'u1' eventType: #LoginFailed sequenceNumber: 1 txTime: 100 validTime: 100 payload: Dictionary new.
        e2 := BitemporalEvent aggregateId: 'u1' eventType: #NormalActivity sequenceNumber: 2 txTime: 200 validTime: 200 payload: Dictionary new.
        e3 := BitemporalEvent aggregateId: 'u1' eventType: #AccountLocked sequenceNumber: 3 txTime: 300 validTime: 300 payload: Dictionary new.

        cep observeEvent: e1.
        cep observeEvent: e2.
        matches := cep observeEvent: e3.

        self assert: matches size equals: 1.
        self assert: (matches first) matchedEvents size equals: 2.
    ]

    testAdaptiveReplacementCacheHitAndEviction [
        | arc |
        arc := AdaptiveReplacementCache capacity: 4.
        arc put: 'k1' value: 100.
        arc put: 'k2' value: 200.
        arc put: 'k3' value: 300.
        arc put: 'k4' value: 400.

        self assert: (arc at: 'k1') equals: 100.
        self assert: (arc at: 'k2') equals: 200.

        "Adding 5th item causes eviction"
        arc put: 'k5' value: 500.
        self assert: arc size equals: 4.
        self assert: (arc at: 'k5') equals: 500.
    ]

    testMerklePatriciaTrieDeterministicRoots [
        | trie1 trie2 r1 r2 |
        trie1 := MerklePatriciaTrie new.
        trie1 put: 'account:alice' value: '1000' asByteArray.
        trie1 put: 'account:bob' value: '500' asByteArray.

        trie2 := MerklePatriciaTrie new.
        trie2 put: 'account:alice' value: '1000' asByteArray.
        trie2 put: 'account:bob' value: '500' asByteArray.

        r1 := trie1 rootHash.
        r2 := trie2 rootHash.
        self assert: r1 equals: r2.
        self deny: r1 equals: 0.

        "Avalanche effect: mutation changes root hash"
        trie2 put: 'account:bob' value: '501' asByteArray.
        self deny: trie1 rootHash equals: trie2 rootHash.
    ]
]
