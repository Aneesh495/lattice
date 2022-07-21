"=============================================================================
 GrainTimer: Transient Timers and Durable Reminders for Virtual Actors
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: GrainTimer [
    | timerId targetContext selector arguments periodMs isCancelled process lock |

    GrainTimer class >> forContext: aContext selector: aSelector periodMs: aMs [
        ^ self forContext: aContext selector: aSelector arguments: #() periodMs: aMs
    ]

    GrainTimer class >> forContext: aContext selector: aSelector arguments: anArgs periodMs: aMs [
        ^ (self new) initializeContext: aContext selector: aSelector arguments: anArgs periodMs: aMs
    ]

    initializeContext: aContext selector: aSelector arguments: anArgs periodMs: aMs [
        timerId := LatticeId generate.
        targetContext := aContext.
        selector := aSelector asSymbol.
        arguments := anArgs.
        periodMs := aMs.
        isCancelled := false.
        lock := Semaphore forMutualExclusion.
        self schedule.
        ^ self
    ]

    schedule [
        process := [
            [
                (Delay forMilliseconds: periodMs) wait.
                lock critical: [
                    isCancelled ifFalse: [
                        | turn |
                        turn := GrainMessageTurn selector: selector arguments: arguments.
                        targetContext mailbox enqueue: turn priority: 15.
                    ].
                ].
            ] repeat.
        ] fork.
    ]

    cancel [
        lock critical: [
            isCancelled := true.
            process ifNotNil: [ process terminate ].
        ].
        ^ self
    ]

    isCancelled [
        ^ isCancelled
    ]
]

Object subclass: GrainReminder [
    | reminderId grainId reminderName dueTimeMs periodMs selector isCancelled |

    GrainReminder class >> grainId: aGrainId name: aName dueTimeMs: aDue periodMs: aPeriod selector: aSel [
        ^ (self new) initializeGrainId: aGrainId name: aName dueTimeMs: aDue periodMs: aPeriod selector: aSel
    ]

    initializeGrainId: aGrainId name: aName dueTimeMs: aDue periodMs: aPeriod selector: aSel [
        reminderId := LatticeId generate.
        grainId := aGrainId.
        reminderName := aName asString.
        dueTimeMs := aDue.
        periodMs := aPeriod.
        selector := aSel asSymbol.
        isCancelled := false.
        ^ self
    ]

    id [
        ^ reminderId
    ]

    grainId [
        ^ grainId
    ]

    name [
        ^ reminderName
    ]

    dueTimeMs [
        ^ dueTimeMs
    ]

    periodMs [
        ^ periodMs
    ]

    selector [
        ^ selector
    ]

    isCancelled [
        ^ isCancelled
    ]

    cancel [
        isCancelled := true.
        ^ self
    ]

    shouldFireAt: nowMs [
        isCancelled ifTrue: [ ^ false ].
        ^ nowMs >= dueTimeMs
    ]

    advanceNextDueTime: nowMs [
        "Advance due time to next future tick period"
        dueTimeMs := nowMs + periodMs.
        ^ self
    ]
]
