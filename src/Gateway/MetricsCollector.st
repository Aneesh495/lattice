"=============================================================================
 MetricsCollector: In-Memory Telemetry and Prometheus Metric Exposition
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: MetricsCollector [
    | counters gauges lock |

    MetricsCollector class >> default [
        defaultInstance ifNil: [ defaultInstance := self new ].
        ^ defaultInstance
    ]

    initialize [
        counters := Dictionary new.
        gauges := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    incrementCounter: aName [
        ^ self incrementCounter: aName by: 1
    ]

    incrementCounter: aName by: aDelta [
        lock critical: [
            | curr |
            curr := counters at: aName asString ifAbsent: [ 0 ].
            counters at: aName asString put: (curr + aDelta).
        ].
        ^ self
    ]

    setGauge: aName value: aNumber [
        lock critical: [
            gauges at: aName asString put: aNumber.
        ].
        ^ self
    ]

    getCounter: aName [
        | c |
        lock critical: [ c := counters at: aName asString ifAbsent: [ 0 ] ].
        ^ c
    ]

    getGauge: aName [
        | g |
        lock critical: [ g := gauges at: aName asString ifAbsent: [ 0 ] ].
        ^ g
    ]

    exportPrometheus [
        "Generate official Prometheus exposition format v0.0.4."
        | s |
        s := WriteStream on: String new.

        lock critical: [
            counters keysAndValuesDo: [ :name :val |
                s nextPutAll: '# HELP '; nextPutAll: name; nextPutAll: ' Lattice metric'; nextPut: Character lf.
                s nextPutAll: '# TYPE '; nextPutAll: name; nextPutAll: ' counter'; nextPut: Character lf.
                s nextPutAll: name; nextPut: $ ; nextPutAll: val printString; nextPut: Character lf.
            ].

            gauges keysAndValuesDo: [ :name :val |
                s nextPutAll: '# HELP '; nextPutAll: name; nextPutAll: ' Lattice metric'; nextPut: Character lf.
                s nextPutAll: '# TYPE '; nextPutAll: name; nextPutAll: ' gauge'; nextPut: Character lf.
                s nextPutAll: name; nextPut: $ ; nextPutAll: val printString; nextPut: Character lf.
            ].
        ].

        ^ s contents
    ]
]
