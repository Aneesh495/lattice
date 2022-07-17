"=============================================================================
 GrainManager: Lifecycle, Registry, and Idle Eviction Manager for Grains
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: GrainManager [
    | activeGrains grainClasses defaultTtlMs lock |

    GrainManager class >> new [
        ^ self ttlMilliseconds: 300000 "5 minutes default TTL"
    ]

    GrainManager class >> ttlMilliseconds: anInteger [
        ^ (super new) initializeWithTtl: anInteger
    ]

    initializeWithTtl: anInteger [
        activeGrains := Dictionary new.
        grainClasses := Dictionary new.
        defaultTtlMs := anInteger.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    registerGrainType: aTypeSymbol class: aClass [
        lock critical: [
            grainClasses at: aTypeSymbol asSymbol put: aClass.
        ].
        ^ self
    ]

    grainClassFor: aTypeSymbol [
        ^ grainClasses at: aTypeSymbol asSymbol ifAbsent: [
            SystemExceptions.NotFound signal: 'No registered grain class for type: ', aTypeSymbol asString
        ]
    ]

    activeCount [
        | c |
        lock critical: [ c := activeGrains size ].
        ^ c
    ]

    isActive: aGrainId [
        | active |
        lock critical: [
            active := activeGrains includesKey: aGrainId.
        ].
        ^ active
    ]

    getOrCreateGrain: aGrainId [
        "Return active context or activate lazily if not currently present in memory."
        | context grainClass |
        lock critical: [
            context := activeGrains at: aGrainId ifAbsent: [ nil ].
            context ifNotNil: [
                context touch.
                ^ context
            ].

            "Lazy Activation"
            grainClass := self grainClassFor: aGrainId grainType.
            context := GrainContext forGrainId: aGrainId grainClass: grainClass.
            context activate.
            activeGrains at: aGrainId put: context.
        ].
        ^ context
    ]

    passivateGrain: aGrainId [
        | context |
        lock critical: [
            context := activeGrains at: aGrainId ifAbsent: [ nil ].
            context ifNotNil: [
                context passivate.
                activeGrains removeKey: aGrainId.
            ].
        ].
        ^ context
    ]

    passivateIdleGrainsOlderThan: ttlMs [
        "Scan active grains and passivate any whose idle time exceeds ttlMs."
        | now toEvict count |
        now := Time millisecondClockValue.
        toEvict := OrderedCollection new.

        lock critical: [
            activeGrains keysAndValuesDo: [ :gid :ctx |
                (now - ctx lastAccessTimeMs) >= ttlMs ifTrue: [
                    toEvict add: gid.
                ].
            ].
        ].

        count := 0.
        toEvict do: [ :gid |
            self passivateGrain: gid.
            count := count + 1.
        ].
        ^ count
    ]

    passivateAll [
        | keys |
        lock critical: [ keys := activeGrains keys copy ].
        keys do: [ :gid | self passivateGrain: gid ].
        ^ self
    ]
]
