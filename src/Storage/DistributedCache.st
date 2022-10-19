"=============================================================================
 DistributedCache: Adaptive Replacement Cache (ARC) In-Memory Object Grid
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: AdaptiveReplacementCache [
    | capacity p t1 t2 b1 b2 cacheData lock hits misses |

    AdaptiveReplacementCache class >> capacity: aCapacity [
        ^ (self new) initializeCapacity: aCapacity
    ]

    initializeCapacity: aCapacity [
        capacity := aCapacity max: 4.
        p := 0.
        t1 := OrderedCollection new. "Recent cache"
        t2 := OrderedCollection new. "Frequent cache"
        b1 := OrderedCollection new. "Recent ghost history"
        b2 := OrderedCollection new. "Frequent ghost history"
        cacheData := Dictionary new.
        hits := 0.
        misses := 0.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    at: aKey [
        lock critical: [
            (cacheData includesKey: aKey) ifTrue: [
                hits := hits + 1.
                (t1 includes: aKey) ifTrue: [
                    t1 remove: aKey.
                    t2 addLast: aKey.
                ] ifFalse: [
                    (t2 includes: aKey) ifTrue: [
                        t2 remove: aKey.
                        t2 addLast: aKey.
                    ].
                ].
                ^ cacheData at: aKey
            ].
            misses := misses + 1.
            ^ nil
        ].
    ]

    put: aKey value: aValue [
        lock critical: [
            (cacheData includesKey: aKey) ifTrue: [
                cacheData at: aKey put: aValue.
                self at: aKey. "Promote"
                ^ self
            ].

            (b1 includes: aKey) ifTrue: [
                | delta |
                delta := b1 size >= b2 size ifTrue: [ 1 ] ifFalse: [ (b2 size asFloat / b1 size asFloat) rounded max: 1 ].
                p := (p + delta) min: capacity.
                self replaceFor: aKey.
                b1 remove: aKey.
                t2 addLast: aKey.
                cacheData at: aKey put: aValue.
                ^ self
            ].

            (b2 includes: aKey) ifTrue: [
                | delta |
                delta := b2 size >= b1 size ifTrue: [ 1 ] ifFalse: [ (b1 size asFloat / b2 size asFloat) rounded max: 1 ].
                p := (p - delta) max: 0.
                self replaceFor: aKey.
                b2 remove: aKey.
                t2 addLast: aKey.
                cacheData at: aKey put: aValue.
                ^ self
            ].

            "Case 4: Complete miss"
            (t1 size + b1 size = capacity) ifTrue: [
                t1 size < capacity ifTrue: [
                    b1 removeFirst.
                    self replaceFor: aKey.
                ] ifFalse: [
                    | evKey |
                    evKey := t1 removeFirst.
                    cacheData removeKey: evKey ifAbsent: [ nil ].
                ].
            ] ifFalse: [
                (t1 size + t2 size + b1 size + b2 size >= capacity) ifTrue: [
                    (t1 size + t2 size + b1 size + b2 size = (2 * capacity)) ifTrue: [
                        b2 removeFirst.
                    ].
                    self replaceFor: aKey.
                ].
            ].

            t1 addLast: aKey.
            cacheData at: aKey put: aValue.
        ].
        ^ self
    ]

    replaceFor: aKey [
        | isKeyInB2 |
        isKeyInB2 := b2 includes: aKey.
        (t1 notEmpty and: [ (t1 size > p) or: [ isKeyInB2 and: [ t1 size = p ] ] ]) ifTrue: [
            | evKey |
            evKey := t1 removeFirst.
            b1 addLast: evKey.
            cacheData removeKey: evKey ifAbsent: [ nil ].
        ] ifFalse: [
            t2 notEmpty ifTrue: [
                | evKey |
                evKey := t2 removeFirst.
                b2 addLast: evKey.
                cacheData removeKey: evKey ifAbsent: [ nil ].
            ].
        ].
    ]

    size [
        | s |
        lock critical: [ s := cacheData size ].
        ^ s
    ]

    hitRate [
        | total |
        total := hits + misses.
        total = 0 ifTrue: [ ^ 0.0 ].
        ^ hits asFloat / total asFloat
    ]
]
