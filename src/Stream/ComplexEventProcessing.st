"=============================================================================
 ComplexEventProcessing: NFA-Based Pattern Matching Engine for Event Streams
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: PatternCondition [
    | eventType predicate |

    PatternCondition class >> type: aType predicate: aBlock [
        ^ (self new) initializeType: aType predicate: aBlock
    ]

    initializeType: aType predicate: aBlock [
        eventType := aType asSymbol.
        predicate := aBlock.
        ^ self
    ]

    matches: anEvent [
        (anEvent eventType = eventType) ifFalse: [ ^ false ].
        predicate ifNil: [ ^ true ].
        ^ predicate value: anEvent
    ]
]

Object subclass: PatternMatchRun [
    | matchedEvents startTimeMs isComplete |

    PatternMatchRun class >> startWith: anEvent [
        ^ (self new) initializeWith: anEvent
    ]

    initializeWith: anEvent [
        matchedEvents := OrderedCollection with: anEvent.
        startTimeMs := Time millisecondClockValue.
        isComplete := false.
        ^ self
    ]

    matchedEvents [
        ^ matchedEvents copy
    ]

    startTimeMs [
        ^ startTimeMs
    ]

    addEvent: anEvent [
        matchedEvents add: anEvent.
        ^ self
    ]

    size [
        ^ matchedEvents size
    ]

    isComplete [
        ^ isComplete
    ]

    markComplete [
        isComplete := true.
        ^ self
    ]
]

Object subclass: CEPPatternEngine [
    | conditions windowMs activeRuns matchedPatterns lock |

    CEPPatternEngine class >> new [
        ^ (super new) initialize
    ]

    initialize [
        conditions := OrderedCollection new.
        windowMs := 10000.
        activeRuns := OrderedCollection new.
        matchedPatterns := OrderedCollection new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    followedBy: anEventType where: aPredicateBlock [
        conditions add: (PatternCondition type: anEventType predicate: aPredicateBlock).
        ^ self
    ]

    withinMilliseconds: aMs [
        windowMs := aMs.
        ^ self
    ]

    observeEvent: anEvent [
        "Process new event against active partial pattern runs and first stage condition."
        | now surviving completed |
        now := Time millisecondClockValue.
        surviving := OrderedCollection new.
        completed := OrderedCollection new.

        lock critical: [
            "Check ongoing runs"
            activeRuns do: [ :run |
                (now - run startTimeMs) <= windowMs ifTrue: [
                    | nextStageIdx cond |
                    nextStageIdx := run size + 1.
                    nextStageIdx <= conditions size ifTrue: [
                        cond := conditions at: nextStageIdx.
                        (cond matches: anEvent) ifTrue: [
                            run addEvent: anEvent.
                            nextStageIdx = conditions size ifTrue: [
                                run markComplete.
                                completed add: run.
                            ] ifFalse: [
                                surviving add: run.
                            ].
                        ] ifFalse: [
                            surviving add: run.
                        ].
                    ].
                ].
            ].

            "Check if event triggers a new run (stage 1 match)"
            conditions notEmpty ifTrue: [
                (conditions first matches: anEvent) ifTrue: [
                    conditions size = 1 ifTrue: [
                        | r |
                        r := PatternMatchRun startWith: anEvent.
                        r markComplete.
                        completed add: r.
                    ] ifFalse: [
                        surviving add: (PatternMatchRun startWith: anEvent).
                    ].
                ].
            ].

            activeRuns := surviving.
            completed do: [ :c | matchedPatterns add: c ].
        ].
        ^ completed
    ]

    drainedMatches [
        | res |
        lock critical: [
            res := matchedPatterns copy.
            matchedPatterns := OrderedCollection new.
        ].
        ^ res
    ]

    matchCount [
        | c |
        lock critical: [ c := matchedPatterns size ].
        ^ c
    ]
]
