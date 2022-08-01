"=============================================================================
 BitemporalIndex: Dual-Axis Indexing and Time-Travel Query Resolution
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: BitemporalIndex [
    | aggregateEvents lock |

    BitemporalIndex class >> new [
        ^ (super new) initialize
    ]

    initialize [
        aggregateEvents := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    indexEvent: aBitemporalEvent [
        "Insert event into the aggregate's timeline maintaining sequence ordering."
        | aggId list |
        aggId := aBitemporalEvent aggregateId.
        lock critical: [
            list := aggregateEvents at: aggId ifAbsentPut: [ OrderedCollection new ].
            list add: aBitemporalEvent.
        ].
        ^ self
    ]

    eventsForAggregate: anAggId [
        | list |
        lock critical: [
            list := aggregateEvents at: anAggId asString ifAbsent: [ OrderedCollection new ].
        ].
        ^ list copy
    ]

    eventsForAggregate: anAggId asOfTransactionTime: maxTxTime [
        "Time-travel query across Transaction Time (System knowledge snapshot).
         Returns only events committed into the store on or before maxTxTime."
        | all matching |
        all := self eventsForAggregate: anAggId.
        matching := OrderedCollection new.
        all do: [ :evt |
            evt txTime <= maxTxTime ifTrue: [
                matching add: evt.
            ].
        ].
        ^ matching
    ]

    eventsForAggregate: anAggId asOfValidTime: maxValidTime [
        "Time-travel query across Valid Time (Domain reality snapshot).
         Returns events effective in the real world on or before maxValidTime."
        | all matching |
        all := self eventsForAggregate: anAggId.
        matching := OrderedCollection new.
        all do: [ :evt |
            evt validTime <= maxValidTime ifTrue: [
                matching add: evt.
            ].
        ].
        ^ matching
    ]

    eventsForAggregate: anAggId asOfTransactionTime: maxTx asOfValidTime: maxValid [
        "Bitemporal point query: State of reality at maxValid as known at maxTx."
        | all matching |
        all := self eventsForAggregate: anAggId.
        matching := OrderedCollection new.
        all do: [ :evt |
            (evt txTime <= maxTx and: [ evt validTime <= maxValid ]) ifTrue: [
                matching add: evt.
            ].
        ].
        ^ matching
    ]

    totalEvents [
        | count |
        count := 0.
        lock critical: [
            aggregateEvents valuesDo: [ :list | count := count + list size ].
        ].
        ^ count
    ]
]
