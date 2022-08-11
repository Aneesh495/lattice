"=============================================================================
 WindowOperator: Tumbling, Sliding, and Session Windowing Primitives
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: TimeWindow [
    | windowStart windowEnd elements |

    TimeWindow class >> start: aStart end: anEnd [
        ^ (self new) initializeStart: aStart end: anEnd
    ]

    initializeStart: aStart end: anEnd [
        windowStart := aStart.
        windowEnd := anEnd.
        elements := OrderedCollection new.
        ^ self
    ]

    start [
        ^ windowStart
    ]

    end [
        ^ windowEnd
    ]

    elements [
        ^ elements copy
    ]

    add: anItem [
        elements add: anItem.
        ^ self
    ]

    size [
        ^ elements size
    ]

    containsTimestamp: aTimestamp [
        ^ aTimestamp >= windowStart and: [ aTimestamp < windowEnd ]
    ]

    printOn: aStream [
        aStream nextPutAll: 'TimeWindow([';
                nextPutAll: windowStart printString;
                nextPutAll: ', ';
                nextPutAll: windowEnd printString;
                nextPutAll: '), count=';
                nextPutAll: elements size printString;
                nextPut: $)
    ]
]

Object subclass: TumblingWindowOperator [
    | windowSizeMs activeWindows lock |

    TumblingWindowOperator class >> ofSize: aSizeMs [
        ^ (self new) initializeSize: aSizeMs
    ]

    initializeSize: aSizeMs [
        windowSizeMs := aSizeMs.
        activeWindows := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    assignWindowStartFor: aTimestamp [
        ^ aTimestamp - (aTimestamp \\ windowSizeMs)
    ]

    add: anItem atTime: aTimestamp [
        | wStart wEnd win |
        wStart := self assignWindowStartFor: aTimestamp.
        wEnd := wStart + windowSizeMs.
        lock critical: [
            win := activeWindows at: wStart ifAbsentPut: [ TimeWindow start: wStart end: wEnd ].
            win add: anItem.
        ].
        ^ win
    ]

    triggerUpTo: aWatermarkTime using: anAggregatorBlock [
        "Emit and purge all windows whose windowEnd <= aWatermarkTime."
        | toEmit results |
        toEmit := OrderedCollection new.
        results := OrderedCollection new.

        lock critical: [
            activeWindows keysAndValuesDo: [ :start :win |
                win end <= aWatermarkTime ifTrue: [
                    toEmit add: win.
                ].
            ].
            toEmit do: [ :win |
                activeWindows removeKey: win start.
            ].
        ].

        toEmit do: [ :win |
            | aggregated |
            aggregated := anAggregatorBlock value: win.
            results add: aggregated.
        ].
        ^ results
    ]
]

Object subclass: SessionWindowOperator [
    | inactivityGapMs currentSessionStart lastActivityTime currentElements lock |

    SessionWindowOperator class >> inactivityGap: aGapMs [
        ^ (self new) initializeGap: aGapMs
    ]

    initializeGap: aGapMs [
        inactivityGapMs := aGapMs.
        currentSessionStart := nil.
        lastActivityTime := nil.
        currentElements := OrderedCollection new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    add: anItem atTime: aTimestamp [
        lock critical: [
            currentSessionStart ifNil: [
                currentSessionStart := aTimestamp.
                lastActivityTime := aTimestamp.
                currentElements add: anItem.
            ] ifNotNil: [
                (aTimestamp - lastActivityTime) <= inactivityGapMs ifTrue: [
                    lastActivityTime := aTimestamp.
                    currentElements add: anItem.
                ] ifFalse: [
                    "Gap exceeded: new session starts"
                    currentSessionStart := aTimestamp.
                    lastActivityTime := aTimestamp.
                    currentElements := OrderedCollection new.
                    currentElements add: anItem.
                ].
            ].
        ].
        ^ self
    ]

    activeCount [
        | c |
        lock critical: [ c := currentElements size ].
        ^ c
    ]
]
