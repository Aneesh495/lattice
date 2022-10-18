"=============================================================================
 GraphActor: Pregel Bulk Synchronous Parallel (BSP) Graph Processing Engine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: VertexGrain [
    | vertexId vertexValue outEdges incomingMessages isHalted |

    onActivate [
        vertexValue := 1.0. "Initial PageRank or value"
        outEdges := OrderedCollection new.
        incomingMessages := OrderedCollection new.
        isHalted := false.
    ]

    setVertexId: anId [
        vertexId := anId asString.
    ]

    addEdgeTo: aTargetVertexId [
        outEdges add: aTargetVertexId asString.
        ^ self
    ]

    receiveMessage: aValue [
        incomingMessages add: aValue.
        isHalted := false.
        ^ self
    ]

    computePageRankWithDamping: dampingFactor [
        "Pregel vertex compute step for distributed PageRank"
        | sum outWeight outMsg |
        incomingMessages notEmpty ifTrue: [
            sum := 0.0.
            incomingMessages do: [ :msg | sum := sum + msg ].
            vertexValue := (1.0 - dampingFactor) + (dampingFactor * sum).
        ].
        incomingMessages := OrderedCollection new.

        outEdges notEmpty ifTrue: [
            outWeight := vertexValue / outEdges size asFloat.
            outMsg := Dictionary new
                at: 'outEdges' put: outEdges copy;
                at: 'weight' put: outWeight;
                yourself.
            ^ outMsg
        ] ifFalse: [
            isHalted := true.
            ^ nil
        ].
    ]

    voteToHalt [
        isHalted := true.
        ^ self
    ]

    isHalted [
        ^ isHalted
    ]

    vertexValue [
        ^ vertexValue
    ]

    outEdges [
        ^ outEdges copy
    ]
]

Object subclass: PregelCoordinator [
    | vertices lock currentSuperstep isConverged |

    PregelCoordinator class >> new [
        ^ (super new) initialize
    ]

    initialize [
        vertices := Dictionary new.
        currentSuperstep := 0.
        isConverged := false.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    registerVertex: aVertexId grainRef: aRef [
        lock critical: [
            vertices at: aVertexId asString put: aRef.
        ].
        ^ self
    ]

    executeSuperstep [
        "Execute one Pregel BSP superstep with synchronization barrier."
        | outgoingMessages allHalted |
        currentSuperstep := currentSuperstep + 1.
        outgoingMessages := OrderedCollection new.
        allHalted := true.

        "Compute phase"
        vertices keysAndValuesDo: [ :vId :ref |
            | outMsg |
            outMsg := ref computePageRankWithDamping: 0.85.
            outMsg ifNotNil: [
                outgoingMessages add: outMsg.
                allHalted := false.
            ].
        ].

        "Message exchange barrier phase"
        outgoingMessages do: [ :msg |
            | targets weight |
            targets := msg at: 'outEdges'.
            weight := msg at: 'weight'.
            targets do: [ :targetId |
                | targetRef |
                targetRef := vertices at: targetId ifAbsent: [ nil ].
                targetRef ifNotNil: [
                    targetRef receiveMessage: weight.
                ].
            ].
        ].

        allHalted ifTrue: [ isConverged := true ].
        ^ isConverged
    ]

    runUntilConvergence: maxSupersteps [
        1 to: maxSupersteps do: [ :s |
            self executeSuperstep ifTrue: [ ^ s ].
        ].
        ^ maxSupersteps
    ]

    superstep [
        ^ currentSuperstep
    ]
]
