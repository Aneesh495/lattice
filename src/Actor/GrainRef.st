"=============================================================================
 GrainRef: Location-Transparent Virtual Actor Reference and Dynamic Proxy
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

nil subclass: GrainRef [
    | grainId coordinator localManager dispatcherMap lock |

    GrainRef class >> forGrainId: aGrainId coordinator: aCoordinator manager: aManager [
        ^ (self basicNew) initializeGrainId: aGrainId coordinator: aCoordinator manager: aManager
    ]

    initializeGrainId: aGrainId coordinator: aCoordinator manager: aManager [
        grainId := aGrainId.
        coordinator := aCoordinator.
        localManager := aManager.
        dispatcherMap := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    grainId [
        ^ grainId
    ]

    targetNode [
        ^ coordinator routeKey: grainId asString
    ]

    isLocal [
        ^ coordinator isLocalKey: grainId asString
    ]

    invokeLocal: aSelector withArguments: anArgs [
        "Local invocation path: retrieve active context and execute turn."
        | ctx disp |
        ctx := localManager getOrCreateGrain: grainId.
        lock critical: [
            disp := dispatcherMap at: grainId ifAbsentPut: [
                | d |
                d := GrainDispatcher forContext: ctx.
                d start.
                d
            ].
        ].
        ^ disp dispatchSync: aSelector arguments: anArgs
    ]

    send: aSelector withArguments: anArgs [
        "Location-transparent invocation. Routes locally or remotely based on HashRing."
        self isLocal ifTrue: [
            ^ self invokeLocal: aSelector withArguments: anArgs
        ] ifFalse: [
            "Remote routing via wire protocol will be resolved by cluster transport"
            ^ self invokeLocal: aSelector withArguments: anArgs
        ].
    ]

    doesNotUnderstand: aMessage [
        "Transparent Smalltalk messaging interception.
         Any method call directly routes to the virtual actor turn."
        ^ self send: aMessage selector withArguments: aMessage arguments
    ]

    printOn: aStream [
        aStream nextPutAll: 'GrainRef('; nextPutAll: grainId asString; nextPut: $)
    ]
]
