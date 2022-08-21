"=============================================================================
 ReflectionTest: Unit Test Suite for Dynamic Proxies and Schema Migrations
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: CalculationService [
    multiply: a by: b [
        ^ a * b
    ]

    failingMethod [
        SystemExceptions.InvalidState signal: 'Target failure'
    ]
]

LatticeTestCase subclass: ReflectionTest [

    testDynamicProxyInterception [
        | target proxy res beforeFired afterFired |
        target := CalculationService new.
        proxy := LatticeProxy on: target.

        beforeFired := false.
        afterFired := false.

        proxy addBeforeInterceptor: [ :msg | beforeFired := true ].
        proxy addAfterInterceptor: [ :msg :result | afterFired := true ].

        res := proxy multiply: 6 by: 7.
        self assert: res equals: 42.
        self assert: beforeFired.
        self assert: afterFired.
        self assert: proxy callCount equals: 1.
    ]

    testProxyCircuitBreakerTrip [
        | target proxy |
        target := CalculationService new.
        proxy := LatticeProxy on: target.

        "Trigger failures up to threshold 5"
        1 to: 5 do: [ :i |
            [ proxy failingMethod ] on: Error do: [ :ex | "ignore" ].
        ].

        self assert: proxy isCircuitOpen.
        self should: [ proxy multiply: 2 by: 2 ] raise: SystemExceptions.InvalidState.
    ]

    testSchemaMigrationChain [
        | reg v1State v3State |
        reg := SchemaRegistry new.

        "Migration 1 -> 2: split 'fullName' into 'firstName' and 'lastName'"
        reg registerMigration: (SchemaMigration class: #UserGrain from: 1 to: 2 using: [ :state |
            | full parts |
            full := state at: 'fullName'.
            parts := full subStrings: ' '.
            state removeKey: 'fullName'.
            state at: 'firstName' put: (parts at: 1).
            state at: 'lastName' put: (parts at: 2).
            state
        ]).

        "Migration 2 -> 3: add default 'tier' = 'standard'"
        reg registerMigration: (SchemaMigration class: #UserGrain from: 2 to: 3 using: [ :state |
            state at: 'tier' put: 'standard'.
            state
        ]).

        v1State := Dictionary new.
        v1State at: 'fullName' put: 'Grace Hopper'.
        v1State at: 'score' put: 99.

        v3State := reg migrateState: v1State fromVersion: 1 toVersion: 3 forClass: #UserGrain.

        self assert: (v3State at: 'firstName') equals: 'Grace'.
        self assert: (v3State at: 'lastName') equals: 'Hopper'.
        self assert: (v3State at: 'tier') equals: 'standard'.
        self assert: (v3State at: 'score') equals: 99.
        self deny: (v3State includesKey: 'fullName').
    ]
]
