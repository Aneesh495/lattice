"=============================================================================
 GrainDispatcher: Single-Threaded Turn Execution and Message Resolution
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: GrainMessageTurn [
    | selector arguments capability correlationId completionSem result exception isCompleted |

    GrainMessageTurn class >> selector: aSelector arguments: anArray [
        ^ self selector: aSelector arguments: anArray capability: nil
    ]

    GrainMessageTurn class >> selector: aSelector arguments: anArray capability: aCap [
        ^ (self new) initializeSelector: aSelector arguments: anArray capability: aCap
    ]

    initializeSelector: aSelector arguments: anArray capability: aCap [
        selector := aSelector asSymbol.
        arguments := anArray ifNil: [ #() ] ifNotNil: [ anArray copy ].
        capability := aCap.
        correlationId := LatticeId generate.
        completionSem := Semaphore new.
        result := nil.
        exception := nil.
        isCompleted := false.
        ^ self
    ]

    selector [
        ^ selector
    ]

    arguments [
        ^ arguments
    ]

    capability [
        ^ capability
    ]

    correlationId [
        ^ correlationId
    ]

    result [
        ^ result
    ]

    exception [
        ^ exception
    ]

    isCompleted [
        ^ isCompleted
    ]

    hasError [
        ^ exception notNil
    ]

    completeWithResult: aResult [
        result := aResult.
        isCompleted := true.
        completionSem signal.
        ^ self
    ]

    completeWithException: anException [
        exception := anException.
        isCompleted := true.
        completionSem signal.
        ^ self
    ]

    waitResult [
        completionSem wait.
        exception ifNotNil: [
            SystemExceptions.InvalidState signal: ('Grain turn failed: ' , exception messageText)
        ].
        ^ result
    ]

    waitResultTimeoutMs: timeoutMs [
        | delay sem |
        sem := Semaphore new.
        delay := Delay forMilliseconds: timeoutMs.
        [
            completionSem wait.
            sem signal.
        ] fork.
        [
            delay wait.
            sem signal.
        ] fork.

        sem wait.
        isCompleted ifFalse: [
            SystemExceptions.Timeout signal: 'Grain turn timed out awaiting reply'
        ].
        exception ifNotNil: [
            SystemExceptions.InvalidState signal: ('Grain turn failed: ' , exception messageText)
        ].
        ^ result
    ]
]

Object subclass: GrainDispatcher [
    | grainContext isRunning workerProcess lock |

    GrainDispatcher class >> forContext: aGrainContext [
        ^ (self new) initializeContext: aGrainContext
    ]

    initializeContext: aGrainContext [
        grainContext := aGrainContext.
        isRunning := false.
        workerProcess := nil.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    start [
        lock critical: [
            isRunning ifTrue: [ ^ self ].
            isRunning := true.
            workerProcess := [ self runLoop ] fork.
        ].
        ^ self
    ]

    stop [
        lock critical: [
            isRunning := false.
            grainContext mailbox close.
        ].
        ^ self
    ]

    runLoop [
        [ isRunning ] whileTrue: [
            | turn |
            turn := grainContext mailbox dequeueWait.
            (turn notNil and: [ isRunning ]) ifTrue: [
                self executeTurn: turn.
            ].
        ].
    ]

    executeTurn: aTurn [
        | grainInst res |
        grainInst := grainContext grainInstance.
        grainContext touch.

        [
            "Perform message dispatch with arguments"
            res := grainInst perform: aTurn selector withArguments: aTurn arguments.
            aTurn completeWithResult: res.
        ] on: Error do: [ :ex |
            aTurn completeWithException: ex.
        ].
    ]

    dispatchSync: aSelector arguments: anArray [
        | turn |
        turn := GrainMessageTurn selector: aSelector arguments: anArray.
        grainContext mailbox enqueue: turn.
        self ensureRunning.
        ^ turn waitResult
    ]

    dispatchSyncTurn: aTurn [
        grainContext mailbox enqueue: aTurn.
        self ensureRunning.
        ^ aTurn waitResult
    ]

    ensureRunning [
        lock critical: [
            isRunning ifFalse: [ self start ].
        ].
    ]
]
