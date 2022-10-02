"=============================================================================
 ClusterIntegrationTest: Multi-Node Loopback Cluster & Failover Integration
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: PersistentUserGrain [
    | name score store |

    onActivate [
        name := 'unknown'.
        score := 0.
    ]

    setStore: aStore [
        store := aStore.
    ]

    updateName: aName score: aScore [
        name := aName.
        score := aScore.
        store ifNotNil: [
            store appendEventFor: grainId asString
                       eventType: #UserUpdated
                       validTime: Time millisecondClockValue
                         payload: (Dictionary new at: 'name' put: aName; at: 'score' put: aScore; yourself).
        ].
        ^ score
    ]

    score [
        ^ score
    ]

    name [
        ^ name
    ]
]

LatticeTestCase subclass: ClusterIntegrationTest [

    setUp [
        | f |
        f := File name: '/tmp/lattice_integ_store/segment-0001.wal'.
        f exists ifTrue: [ [ f remove ] on: Error do: [ :ex | nil ] ].
    ]

    testMultiNodeGossipAndFailoverRebalancing [
        | n1 n2 n3 coord ring target1 target2 |
        n1 := ClusterNode id: 'cluster-node-1' host: '127.0.0.1' port: 8001.
        n2 := ClusterNode id: 'cluster-node-2' host: '127.0.0.1' port: 8002.
        n3 := ClusterNode id: 'cluster-node-3' host: '127.0.0.1' port: 8003.

        coord := ClusterCoordinator onNode: n1.
        coord registerPeerNode: n2.
        coord registerPeerNode: n3.

        self assert: coord hashRing nodeCount equals: 3.
        self assert: coord membership aliveMembers size equals: 3.

        "Route keys across cluster"
        target1 := coord routeKey: 'grain/session/101'.
        self assert: (target1 notNil).

        "Simulate failure of Node 2"
        coord handleNodeFailure: 'cluster-node-2'.
        self assert: coord hashRing nodeCount equals: 2.

        target2 := coord routeKey: 'grain/session/101'.
        self assert: (target2 ~= 'cluster-node-2').
        self assert: (target2 = 'cluster-node-1' or: [ target2 = 'cluster-node-3' ]).
    ]

    testDistributedConsensusLogReplicationFlow [
        | s1 s2 s3 rVote2 rVote3 entry appEntries2 appEntries3 |
        s1 := RaftServer id: 'nodeA' peers: #('nodeB' 'nodeC').
        s2 := RaftServer id: 'nodeB' peers: #('nodeA' 'nodeC').
        s3 := RaftServer id: 'nodeC' peers: #('nodeA' 'nodeB').

        "Election turn"
        s1 startElection.
        rVote2 := s2 handleRequestVoteTerm: 1 candidateId: 'nodeA' lastLogIndex: 0 lastLogTerm: 0.
        rVote3 := s3 handleRequestVoteTerm: 1 candidateId: 'nodeA' lastLogIndex: 0 lastLogTerm: 0.

        s1 recordVoteFrom: 'nodeB' granted: (rVote2 at: 'voteGranted').
        s1 recordVoteFrom: 'nodeC' granted: (rVote3 at: 'voteGranted').
        self assert: s1 isLeader.

        "Leader proposes state machine change"
        entry := s1 log appendEntryWithTerm: 1 command: 'rebalance grain/order/99 to nodeC'.
        self assert: s1 log size equals: 1.

        appEntries2 := s2 handleAppendEntriesTerm: 1
                                         leaderId: 'nodeA'
                                     prevLogIndex: 0
                                      prevLogTerm: 0
                                          entries: (OrderedCollection with: entry)
                                     leaderCommit: 0.

        appEntries3 := s3 handleAppendEntriesTerm: 1
                                         leaderId: 'nodeA'
                                     prevLogIndex: 0
                                      prevLogTerm: 0
                                          entries: (OrderedCollection with: entry)
                                     leaderCommit: 0.

        self assert: (appEntries2 at: 'success').
        self assert: (appEntries3 at: 'success').

        s1 setMatchIndexFor: 'nodeB' to: 1.
        s1 setMatchIndexFor: 'nodeC' to: 1.
        s1 advanceLeaderCommitIndex.

        self assert: s1 commitIndex equals: 1.
    ]

    testGrainRehydrationAfterNodeMigration [
        | store1 store2 mgr1 mgr2 gid ctx1 disp1 ctx2 finalState |
        store1 := LatticeStore inDirectory: '/tmp/lattice_integ_store'.

        mgr1 := GrainManager new.
        mgr1 registerGrainType: #PersistentUser class: PersistentUserGrain.

        gid := GrainId type: #PersistentUser key: 'user-777'.
        ctx1 := mgr1 getOrCreateGrain: gid.
        ctx1 grainInstance setStore: store1.

        disp1 := GrainDispatcher forContext: ctx1.
        disp1 start.
        disp1 dispatchSync: #updateName:score: arguments: #('Ada Lovelace' 9800).
        disp1 stop.

        "Take snapshot and close Node 1 store"
        store1 takeSnapshotFor: gid asString state: (Dictionary new at: 'name' put: 'Ada Lovelace'; at: 'score' put: 9800; yourself).
        store1 close.

        "Node 2 starts up, activates migrated grain from store"
        store2 := LatticeStore inDirectory: '/tmp/lattice_integ_store'.
        mgr2 := GrainManager new.
        mgr2 registerGrainType: #PersistentUser class: PersistentUserGrain.

        ctx2 := mgr2 getOrCreateGrain: gid.
        ctx2 grainInstance setStore: store2.

        finalState := store2 rehydrateAggregate: gid asString using: [ :st :evt |
            evt payload
        ].

        self assert: (finalState at: 'name') equals: 'Ada Lovelace'.
        self assert: (finalState at: 'score') equals: 9800.
        store2 close.
    ]
]
