"=============================================================================
 WatermarkManager: Event-Time Progress and Bounded Out-of-Order Tracking
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: WatermarkManager [
    | maxOutOfOrdernessMs currentMaxTimestamp currentWatermark lateEvents lock |

    WatermarkManager class >> maxOutOfOrdernessMs: aMs [
        ^ (self new) initializeOutOfOrderness: aMs
    ]

    initializeOutOfOrderness: aMs [
        maxOutOfOrdernessMs := aMs.
        currentMaxTimestamp := 0.
        currentWatermark := 0.
        lateEvents := OrderedCollection new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    currentWatermark [
        | w |
        lock critical: [ w := currentWatermark ].
        ^ w
    ]

    observeEvent: anItem atTime: aTimestamp [
        "Observe an event timestamp. Returns true if on-time, false if late."
        | isOnTime |
        lock critical: [
            aTimestamp < currentWatermark ifTrue: [
                lateEvents add: anItem.
                isOnTime := false.
            ] ifFalse: [
                currentMaxTimestamp := currentMaxTimestamp max: aTimestamp.
                currentWatermark := (currentMaxTimestamp - maxOutOfOrdernessMs) max: currentWatermark.
                isOnTime := true.
            ].
        ].
        ^ isOnTime
    ]

    drainLateEvents [
        | drained |
        lock critical: [
            drained := lateEvents copy.
            lateEvents := OrderedCollection new.
        ].
        ^ drained
    ]

    lateCount [
        | c |
        lock critical: [ c := lateEvents size ].
        ^ c
    ]
]
