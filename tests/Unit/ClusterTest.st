"=============================================================================
 ClusterTest: Comprehensive Unit Test Suite for HashRing and SWIM Gossip
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: ClusterTest [

    testHashRingVirtualNodeDistribution [
        | ring counts totalKeys |
        ring := HashRing virtualNodes: 128.
        ring addNode: 'node1'.
        ring addNode: 'node2'.
        ring addNode: 'node3'.
        ring addNode: 'node4'.

        self assert: ring nodeCount equals: 4.
        self assert: ring totalVnodes equals: 512.

        counts := Dictionary new.
        counts at: 'node1' put: 0.
        counts at: 'node2' put: 0.
        counts at: 'node3' put: 0.
        counts at: 'node4' put: 0.

        totalKeys := 1000.
        1 to: totalKeys do: [ :i |
            | key target current |
            key := 'grain/benchmark/key-' , i printString.
            target := ring nodeForKey: key.
            current := counts at: target.
            counts at: target put: (current + 1).
        ].

        "Ensure every node received a reasonable share (at least 5% of 1000 keys)"
        counts keysAndValuesDo: [ :node :cnt |
            self assert: (cnt >= 50) message: ('Node ' , node , ' underloaded: ' , cnt printString).
        ].
    ]

    testHashRingReplicaDistinctness [
        | ring replicas |
        ring := HashRing virtualNodes: 64.
        ring addNode: 'srv-alpha'.
        ring addNode: 'srv-beta'.
        ring addNode: 'srv-gamma'.

        replicas := ring nodesForKey: 'ledger/account/2048' count: 3.
        self assert: replicas size equals: 3.
        self assert: (replicas asSet size) equals: 3.
    ]

    testHashRingNodeRemoval [
        | ring key nodeBefore nodeAfter |
        ring := HashRing virtualNodes: 64.
        ring addNode: 'nodeA'.
        ring addNode: 'nodeB'.

        key := 'grain/state/user101'.
        nodeBefore := ring nodeForKey: key.
        self assert: (nodeBefore notNil).

        "Remove nodeBefore"
        ring removeNode: nodeBefore.
        self assert: ring nodeCount equals: 1.

        nodeAfter := ring nodeForKey: key.
        self deny: nodeAfter equals: nodeBefore.
    ]

    testSwimSuspicionLifecycleAndRefutation [
        | swim m2 |
        swim := SWIMMembership localId: 'localHost' address: '127.0.0.1:8000'.
        swim handleAliveMessageFor: 'remoteHost' address: '127.0.0.1:8001' incarnation: 1.

        m2 := swim member: 'remoteHost'.
        self assert: m2 notNil.
        self assert: m2 isAlive.
        self assert: m2 incarnation equals: 1.

        "Suspect remoteHost"
        swim handleSuspectMessageFor: 'remoteHost' incarnation: 1.
        self assert: m2 isSuspect.

        "Timeout to dead"
        swim checkSuspicionTimeouts: (Time millisecondClockValue + 5000).
        self assert: m2 isDead.

        "Local refutation"
        self assert: swim localIncarnation equals: 0.
        swim handleSuspectMessageFor: 'localHost' incarnation: 0.
        self assert: swim localIncarnation equals: 1.
    ]

    testClusterCoordinatorFailover [
        | n1 n2 coord key target |
        n1 := ClusterNode id: 'nodeA' host: '10.0.0.1' port: 7000.
        n2 := ClusterNode id: 'nodeB' host: '10.0.0.2' port: 7000.
        coord := ClusterCoordinator onNode: n1.
        coord registerPeerNode: n2.

        key := 'partition-42'.
        target := coord routeKey: key.
        self assert: (target = 'nodeA' or: [ target = 'nodeB' ]).

        coord handleNodeFailure: 'nodeB'.
        self assert: (coord routeKey: key) equals: 'nodeA'.
    ]
]
