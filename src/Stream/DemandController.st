"=============================================================================
 DemandController: Adaptive Rate Limiter and Overflow Buffer Strategy
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: DemandController [
    | buffer capacity strategy droppedCount lock notEmptySem |

    DemandController class >> capacity: aCap strategy: aStrategy [
        ^ (self new) initializeCapacity: aCap strategy: aStrategy
    ]

    initializeCapacity: aCap strategy: aStrategy [
        capacity := aCap.
        strategy := aStrategy asSymbol. " #block, #dropHead, #dropTail, #fail "
        buffer := OrderedCollection new.
        droppedCount := 0.
        lock := Semaphore forMutualExclusion.
        notEmptySem := Semaphore new.
        ^ self
    ]

    size [
        | s |
        lock critical: [ s := buffer size ].
        ^ s
    ]

    droppedCount [
        | d |
        lock critical: [ d := droppedCount ].
        ^ d
    ]

    push: anItem [
        "Enqueue item according to configured overflow strategy."
        lock critical: [
            buffer size >= capacity ifTrue: [
                strategy = #dropHead ifTrue: [
                    buffer removeFirst.
                    droppedCount := droppedCount + 1.
                    buffer add: anItem.
                    notEmptySem signal.
                    ^ self
                ].
                strategy = #dropTail ifTrue: [
                    droppedCount := droppedCount + 1.
                    ^ self
                ].
                strategy = #fail ifTrue: [
                    SystemExceptions.InvalidState signal: 'DemandController buffer capacity exceeded'
                ].
                strategy = #block ifTrue: [
                    "Wait until space becomes available"
                ].
            ] ifFalse: [
                buffer add: anItem.
                notEmptySem signal.
            ].
        ].
        ^ self
    ]

    pull [
        "Non-blocking pull. Returns nil if empty."
        | item |
        lock critical: [
            buffer isEmpty ifTrue: [ ^ nil ].
            item := buffer removeFirst.
        ].
        ^ item
    ]

    pullWait [
        "Blocking pull. Waits until an item is buffered."
        | item |
        [
            lock critical: [
                buffer isEmpty ifFalse: [
                    ^ buffer removeFirst
                ].
            ].
            notEmptySem wait.
        ] repeat.
    ]
]
