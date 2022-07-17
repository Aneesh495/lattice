"=============================================================================
 GrainContext: Virtual Actor Activation Context and Base Grain Protocol
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeGrain [
    | grainId context state |

    initializeId: anId context: aContext [
        grainId := anId.
        context := aContext.
        state := Dictionary new.
        ^ self
    ]

    id [
        ^ grainId
    ]

    context [
        ^ context
    ]

    state [
        ^ state
    ]

    state: aDictionary [
        state := aDictionary.
        ^ self
    ]

    onActivate [
        "Subclass hook called when grain is activated into memory."
    ]

    onPassivate [
        "Subclass hook called before grain is passivated to disk."
    ]

    onDeactivate [
        "Subclass hook called on graceful termination."
    ]
]

Object subclass: GrainContext [
    | grainId grainInstance mailbox status lastAccessTimeMs lock |

    GrainContext class >> forGrainId: aGrainId grainClass: aClass [
        ^ (self new) initializeForGrainId: aGrainId grainClass: aClass
    ]

    initializeForGrainId: aGrainId grainClass: aClass [
        grainId := aGrainId.
        mailbox := Mailbox new.
        status := #inactive.
        lastAccessTimeMs := Time millisecondClockValue.
        lock := Semaphore forMutualExclusion.

        grainInstance := aClass new initializeId: aGrainId context: self.
        ^ self
    ]

    grainId [
        ^ grainId
    ]

    grainInstance [
        ^ grainInstance
    ]

    mailbox [
        ^ mailbox
    ]

    status [
        ^ status
    ]

    isActive [
        ^ status = #active
    ]

    isPassivating [
        ^ status = #passivating
    ]

    lastAccessTimeMs [
        ^ lastAccessTimeMs
    ]

    touch [
        lastAccessTimeMs := Time millisecondClockValue.
        ^ self
    ]

    activate [
        lock critical: [
            status := #activating.
            grainInstance onActivate.
            status := #active.
            self touch.
        ].
        ^ self
    ]

    passivate [
        lock critical: [
            status := #passivating.
            grainInstance onPassivate.
            mailbox close.
            status := #inactive.
        ].
        ^ self
    ]
]
