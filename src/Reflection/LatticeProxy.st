"=============================================================================
 LatticeProxy: Transparent Dynamic Interception Proxy and Circuit Breaker
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeProxy [
    | target beforeInterceptors afterInterceptors callCount failureCount maxFailures isOpen resetTimeoutMs lastFailureMs |

    LatticeProxy class >> on: aTarget [
        ^ (self basicNew) initializeTarget: aTarget
    ]

    initializeTarget: aTarget [
        target := aTarget.
        beforeInterceptors := OrderedCollection new.
        afterInterceptors := OrderedCollection new.
        callCount := 0.
        failureCount := 0.
        maxFailures := 5.
        isOpen := false.
        resetTimeoutMs := 10000.
        lastFailureMs := 0.
        ^ self
    ]

    target [
        ^ target
    ]

    callCount [
        ^ callCount
    ]

    failureCount [
        ^ failureCount
    ]

    isCircuitOpen [
        "Circuit breaker state: if open and reset timeout elapsed, transition to half-open."
        isOpen ifTrue: [
            (Time millisecondClockValue - lastFailureMs) >= resetTimeoutMs ifTrue: [
                isOpen := false.
                failureCount := 0.
            ].
        ].
        ^ isOpen
    ]

    addBeforeInterceptor: aBlock [
        "aBlock accepts (aMessage)"
        beforeInterceptors add: aBlock.
        ^ self
    ]

    addAfterInterceptor: aBlock [
        "aBlock accepts (aMessage, aResult)"
        afterInterceptors add: aBlock.
        ^ self
    ]

    recordSuccess [
        failureCount := 0.
    ]

    recordFailure [
        failureCount := failureCount + 1.
        lastFailureMs := Time millisecondClockValue.
        failureCount >= maxFailures ifTrue: [
            isOpen := true.
        ].
    ]

    doesNotUnderstand: aMessage [
        "Intercept message, evaluate before-chain, invoke target, record telemetry."
        | result |
        self isCircuitOpen ifTrue: [
            SystemExceptions.InvalidState signal: 'LatticeProxy circuit breaker is OPEN'
        ].

        callCount := callCount + 1.
        beforeInterceptors do: [ :blk | blk value: aMessage ].

        [
            result := aMessage sendTo: target.
            self recordSuccess.
        ] on: Error do: [ :ex |
            self recordFailure.
            ex pass.
        ].

        afterInterceptors do: [ :blk | blk value: aMessage value: result ].
        ^ result
    ]
]
