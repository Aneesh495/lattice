"=============================================================================
 ClusterNode: Physical Cluster Node Descriptor and Topology Coordinator
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: ClusterNode [
    | nodeId host port capabilities activeGrains lastHeartbeatMs isDraining |

    ClusterNode class >> id: anId host: aHost port: aPort [
        ^ (self new) initializeId: anId host: aHost port: aPort
    ]

    initializeId: anId host: aHost port: aPort [
        nodeId := anId asString.
        host := aHost asString.
        port := aPort.
        capabilities := Set new.
        activeGrains := 0.
        lastHeartbeatMs := Time millisecondClockValue.
        isDraining := false.
        ^ self
    ]

    nodeId [
        ^ nodeId
    ]

    host [
        ^ host
    ]

    port [
        ^ port
    ]

    address [
        ^ host , ':' , port printString
    ]

    capabilities [
        ^ capabilities copy
    ]

    addCapability: aCap [
        capabilities add: aCap asSymbol.
        ^ self
    ]

    hasCapability: aCap [
        ^ capabilities includes: aCap asSymbol
    ]

    activeGrains [
        ^ activeGrains
    ]

    activeGrains: aCount [
        activeGrains := aCount.
        ^ self
    ]

    incrementGrainCount [
        activeGrains := activeGrains + 1.
        ^ self
    ]

    decrementGrainCount [
        activeGrains := (activeGrains - 1) max: 0.
        ^ self
    ]

    lastHeartbeatMs [
        ^ lastHeartbeatMs
    ]

    touchHeartbeat [
        lastHeartbeatMs := Time millisecondClockValue.
        ^ self
    ]

    isDraining [
        ^ isDraining
    ]

    setDraining: aBoolean [
        isDraining := aBoolean.
        ^ self
    ]
]

Object subclass: ClusterCoordinator [
    | localNode membership hashRing lock |

    ClusterCoordinator class >> onNode: aClusterNode [
        ^ (self new) initializeWithNode: aClusterNode
    ]

    initializeWithNode: aClusterNode [
        localNode := aClusterNode.
        membership := SWIMMembership localId: aClusterNode nodeId address: aClusterNode address.
        hashRing := HashRing virtualNodes: 128.
        hashRing addNode: aClusterNode nodeId.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    localNode [
        ^ localNode
    ]

    membership [
        ^ membership
    ]

    hashRing [
        ^ hashRing
    ]

    registerPeerNode: aPeerNode [
        "Register peer in both gossip membership and consistent hash ring."
        lock critical: [
            membership handleAliveMessageFor: aPeerNode nodeId
                                     address: aPeerNode address
                                 incarnation: 0.
            hashRing addNode: aPeerNode nodeId.
        ].
        ^ self
    ]

    handleNodeFailure: aFailedNodeId [
        "Evict failed node from consistent hash ring to trigger grain failover."
        lock critical: [
            membership handleDeadMessageFor: aFailedNodeId incarnation: 999999.
            hashRing removeNode: aFailedNodeId.
        ].
        ^ self
    ]

    routeKey: aGrainKey [
        "Lookup target node for given grain key using the synchronized hash ring."
        | target |
        lock critical: [
            target := hashRing nodeForKey: aGrainKey.
        ].
        ^ target
    ]

    isLocalKey: aGrainKey [
        ^ (self routeKey: aGrainKey) = localNode nodeId
    ]
]
