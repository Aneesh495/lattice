"=============================================================================
 ReactiveStream: Reactive Streams Specification (Publisher/Subscriber Contract)
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeSubscription [
    | subscriber publisher requestedCount isCancelled lock |

    LatticeSubscription class >> subscriber: aSub publisher: aPub [
        ^ (self new) initializeSubscriber: aSub publisher: aPub
    ]

    initializeSubscriber: aSub publisher: aPub [
        subscriber := aSub.
        publisher := aPub.
        requestedCount := 0.
        isCancelled := false.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    subscriber [
        ^ subscriber
    ]

    publisher [
        ^ publisher
    ]

    isCancelled [
        ^ isCancelled
    ]

    requestedCount [
        | c |
        lock critical: [ c := requestedCount ].
        ^ c
    ]

    request: n [
        "Signaling demand from subscriber to publisher."
        n <= 0 ifTrue: [
            subscriber onError: (SystemExceptions.InvalidArgument new: 'Demand request must be positive').
            ^ self
        ].
        lock critical: [
            isCancelled ifFalse: [
                requestedCount := requestedCount + n.
            ].
        ].
        publisher onDemandSignaled: self.
        ^ self
    ]

    decrementDemand [
        | hasDemand |
        lock critical: [
            hasDemand := (requestedCount > 0 and: [ isCancelled not ]).
            hasDemand ifTrue: [ requestedCount := requestedCount - 1 ].
        ].
        ^ hasDemand
    ]

    cancel [
        lock critical: [
            isCancelled := true.
            requestedCount := 0.
        ].
        publisher onSubscriptionCancelled: self.
        ^ self
    ]
]

Object subclass: LatticePublisher [
    | subscribers lock |

    LatticePublisher class >> new [
        ^ (super new) initialize
    ]

    initialize [
        subscribers := OrderedCollection new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    subscribe: aSubscriber [
        | subscription |
        subscription := LatticeSubscription subscriber: aSubscriber publisher: self.
        lock critical: [
            subscribers add: subscription.
        ].
        aSubscriber onSubscribe: subscription.
        ^ subscription
    ]

    onDemandSignaled: aSubscription [
        "Hook called when a subscriber requests demand"
    ]

    onSubscriptionCancelled: aSubscription [
        lock critical: [
            subscribers remove: aSubscription ifAbsent: [ nil ].
        ].
    ]

    broadcastNext: anItem [
        | activeSubs |
        lock critical: [ activeSubs := subscribers copy ].
        activeSubs do: [ :sub |
            (sub decrementDemand) ifTrue: [
                sub subscriber onNext: anItem.
            ].
        ].
    ]

    broadcastComplete [
        | activeSubs |
        lock critical: [ activeSubs := subscribers copy ].
        activeSubs do: [ :sub |
            sub subscriber onComplete.
        ].
    ]

    broadcastError: anError [
        | activeSubs |
        lock critical: [ activeSubs := subscribers copy ].
        activeSubs do: [ :sub |
            sub subscriber onError: anError.
        ].
    ]
]

Object subclass: LatticeSubscriber [
    | subscription receivedItems completed error |

    LatticeSubscriber class >> new [
        ^ (super new) initialize
    ]

    initialize [
        subscription := nil.
        receivedItems := OrderedCollection new.
        completed := false.
        error := nil.
        ^ self
    ]

    receivedItems [
        ^ receivedItems copy
    ]

    isCompleted [
        ^ completed
    ]

    hasError [
        ^ error notNil
    ]

    error [
        ^ error
    ]

    onSubscribe: aSubscription [
        subscription := aSubscription.
    ]

    requestDemand: n [
        subscription ifNotNil: [ subscription request: n ].
    ]

    onNext: anItem [
        receivedItems add: anItem.
    ]

    onComplete [
        completed := true.
    ]

    onError: anError [
        error := anError.
    ]
]
