"=============================================================================
 StreamTest: Comprehensive Unit Test Suite for Reactive Streams and Windowing
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: StreamTest [

    testReactiveStreamsDemandBackpressure [
        | pub sub |
        pub := LatticePublisher new.
        sub := LatticeSubscriber new.

        pub subscribe: sub.
        self assert: sub receivedItems size equals: 0.

        "Request 2 items"
        sub requestDemand: 2.
        pub broadcastNext: 'Item1'.
        pub broadcastNext: 'Item2'.
        pub broadcastNext: 'Item3'. "Should NOT be delivered because demand was 2"

        self assert: sub receivedItems size equals: 2.
        self assert: (sub receivedItems at: 1) equals: 'Item1'.
        self assert: (sub receivedItems at: 2) equals: 'Item2'.

        "Request 1 more item"
        sub requestDemand: 1.
        pub broadcastNext: 'Item4'.
        self assert: sub receivedItems size equals: 3.
        self assert: (sub receivedItems at: 3) equals: 'Item4'.
    ]

    testDemandControllerDropHeadStrategy [
        | c |
        c := DemandController capacity: 3 strategy: #dropHead.
        c push: 1; push: 2; push: 3.
        self assert: c size equals: 3.

        "Pushing 4 drops oldest (1)"
        c push: 4.
        self assert: c size equals: 3.
        self assert: c droppedCount equals: 1.

        self assert: c pull equals: 2.
        self assert: c pull equals: 3.
        self assert: c pull equals: 4.
        self assert: c pull isNil.
    ]

    testDemandControllerDropTailStrategy [
        | c |
        c := DemandController capacity: 2 strategy: #dropTail.
        c push: 'A'; push: 'B'.

        "Pushing 'C' drops 'C'"
        c push: 'C'.
        self assert: c droppedCount equals: 1.

        self assert: c pull equals: 'A'.
        self assert: c pull equals: 'B'.
        self assert: c pull isNil.
    ]

    testTumblingWindowAggregationAndTrigger [
        | op results |
        op := TumblingWindowOperator ofSize: 1000.

        op add: 'metric1' atTime: 100.
        op add: 'metric2' atTime: 400.
        op add: 'metric3' atTime: 1200.

        "Trigger up to watermark 500: window [0, 1000) not yet closed"
        results := op triggerUpTo: 500 using: [ :win | win size ].
        self assert: results size equals: 0.

        "Trigger up to watermark 1000: closes window [0, 1000) with 2 elements"
        results := op triggerUpTo: 1000 using: [ :win | win size ].
        self assert: results size equals: 1.
        self assert: (results at: 1) equals: 2.

        "Trigger up to watermark 2000: closes window [1000, 2000) with 1 element"
        results := op triggerUpTo: 2000 using: [ :win | win size ].
        self assert: results size equals: 1.
        self assert: (results at: 1) equals: 1.
    ]

    testWatermarkProgressAndLateEvents [
        | wm |
        wm := WatermarkManager maxOutOfOrdernessMs: 200.

        "First event at 500 -> watermark = 300"
        self assert: (wm observeEvent: 'e1' atTime: 500).
        self assert: wm currentWatermark equals: 300.

        "In-order event at 600 -> watermark = 400"
        self assert: (wm observeEvent: 'e2' atTime: 600).
        self assert: wm currentWatermark equals: 400.

        "Out-of-order but on-time event at 450 (>= watermark 400)"
        self assert: (wm observeEvent: 'e3' atTime: 450).
        self assert: wm lateCount equals: 0.

        "Late arriving event at 250 (< watermark 400)"
        self deny: (wm observeEvent: 'eLate' atTime: 250).
        self assert: wm lateCount equals: 1.
        self assert: ((wm drainLateEvents) at: 1) equals: 'eLate'.
    ]
]
