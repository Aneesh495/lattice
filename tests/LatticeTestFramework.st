"=============================================================================
 LatticeTestFramework: Lightweight SUnit-Compatible Automated Assertion Suite
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeTestCase [
    | passedCount failedCount currentTestName |

    LatticeTestCase class >> new [
        ^ (super new) initialize
    ]

    LatticeTestCase class >> runAll [
        | instance |
        instance := self new.
        instance executeSuite.
        ^ instance
    ]

    initialize [
        passedCount := 0.
        failedCount := 0.
        currentTestName := ''.
        ^ self
    ]

    passedCount [
        ^ passedCount
    ]

    failedCount [
        ^ failedCount
    ]

    assert: aBoolean [
        self assert: aBoolean message: 'Assertion failed'
    ]

    assert: aBoolean message: aString [
        aBoolean ifTrue: [
            passedCount := passedCount + 1.
        ] ifFalse: [
            failedCount := failedCount + 1.
            Transcript show: '  [FAIL] '; show: currentTestName; show: ': '; show: aString; cr.
        ].
    ]

    assert: actual equals: expected [
        (actual = expected) ifTrue: [
            passedCount := passedCount + 1.
        ] ifFalse: [
            failedCount := failedCount + 1.
            Transcript show: '  [FAIL] '; show: currentTestName;
                       show: ' expected: '; show: expected printString;
                       show: ' but got: '; show: actual printString; cr.
        ].
    ]

    deny: aBoolean [
        self assert: aBoolean not message: 'Denial assertion failed'
    ]

    should: aBlock raise: anExceptionClass [
        | raised |
        raised := false.
        [
            aBlock value.
        ] on: anExceptionClass do: [ :ex |
            raised := true.
        ].
        self assert: raised message: ('Expected exception ' , anExceptionClass printString , ' was not raised').
    ]

    setUp [
        "Hook for sub-classes before each test"
    ]

    tearDown [
        "Hook for sub-classes after each test"
    ]

    testSelectors [
        "Find all methods starting with 'test' on this class"
        | selectors list |
        list := OrderedCollection new.
        "Query method dictionary directly"
        self class selectors do: [ :sel |
            ((sel asString size >= 4) and: [ (sel asString copyFrom: 1 to: 4) = 'test' ]) ifTrue: [
                list add: sel.
            ].
        ].
        ^ list
    ]

    executeSuite [
        | tests |
        Transcript show: 'Running test suite: '; show: self class printString; cr.
        tests := self testSelectors.
        tests do: [ :sel |
            currentTestName := sel asString.
            self setUp.
            [
                self perform: sel.
            ] on: Error do: [ :ex |
                failedCount := failedCount + 1.
                Transcript show: '  [ERROR] '; show: currentTestName; show: ' unhandled exception: '; show: ex messageText; cr.
            ].
            self tearDown.
        ].
        Transcript show: 'Finished '; show: self class printString;
                   show: ' - Passed: '; show: passedCount printString;
                   show: ', Failed: '; show: failedCount printString; cr.
        (failedCount = 0) ifTrue: [
            Transcript show: '=> ALL TESTS PASSED'; cr.
        ] ifFalse: [
            Transcript show: '=> TEST SUITE FAILED'; cr.
            ObjectMemory quit: 1.
        ].
    ]
]
