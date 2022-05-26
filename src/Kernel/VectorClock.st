"=============================================================================
 VectorClock: Causality Tracking and Partial Ordering for Distributed State
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: VectorClock [
    | entries |

    VectorClock class >> new [
        ^ (super new) initialize
    ]

    VectorClock class >> fromDictionary: aDictionary [
        | clock |
        clock := self new.
        aDictionary keysAndValuesDo: [ :k :v |
            clock set: k asString value: v.
        ].
        ^ clock
    ]

    initialize [
        entries := Dictionary new.
        ^ self
    ]

    entries [
        ^ entries
    ]

    at: aNodeId [
        "Return the logical counter for a given node, default 0."
        ^ entries at: aNodeId asString ifAbsent: [ 0 ]
    ]

    set: aNodeId value: anInteger [
        entries at: aNodeId asString put: anInteger.
        ^ self
    ]

    tick: aNodeId [
        "Increment the logical timestamp for the specified node ID."
        | current |
        current := self at: aNodeId.
        entries at: aNodeId asString put: (current + 1).
        ^ self
    ]

    merge: aVectorClock [
        "Produce a new VectorClock representing the least upper bound (causal join)
         by taking the component-wise maximum across all node identifiers."
        | merged allKeys |
        merged := VectorClock new.
        allKeys := Set new.
        allKeys addAll: entries keys.
        allKeys addAll: aVectorClock entries keys.

        allKeys do: [ :key |
            | val1 val2 |
            val1 := self at: key.
            val2 := aVectorClock at: key.
            merged set: key value: (val1 max: val2).
        ].
        ^ merged
    ]

    dominatesOrEquals: aVectorClock [
        "Return true if every counter in self is greater than or equal to
         the corresponding counter in aVectorClock."
        aVectorClock entries keysAndValuesDo: [ :key :val |
            (self at: key) < val ifTrue: [ ^ false ].
        ].
        ^ true
    ]

    dominates: aVectorClock [
        "Strict dominance: dominatesOrEquals is true and at least one component is strictly greater."
        (self dominatesOrEquals: aVectorClock) ifFalse: [ ^ false ].
        ^ (self = aVectorClock) not
    ]

    descendsFrom: aVectorClock [
        "Synonym for strict dominance: this clock causally succeeds aVectorClock."
        ^ self dominates: aVectorClock
    ]

    concurrentWith: aVectorClock [
        "Return true if neither clock causally dominates the other, indicating
         independent concurrent mutations requiring application resolution."
        ^ (self dominatesOrEquals: aVectorClock) not and: [ (aVectorClock dominatesOrEquals: self) not ]
    ]

    = anObject [
        | allKeys |
        (anObject isKindOf: VectorClock) ifFalse: [ ^ false ].
        allKeys := Set new.
        allKeys addAll: entries keys.
        allKeys addAll: anObject entries keys.
        allKeys do: [ :key |
            (self at: key) = (anObject at: key) ifFalse: [ ^ false ].
        ].
        ^ true
    ]

    hash [
        | h |
        h := 17.
        entries keysAndValuesDo: [ :k :v |
            h := (h + (k hash bitXor: v hash)) bitAnd: 16r7FFFFFFF.
        ].
        ^ h
    ]

    asDictionary [
        ^ entries copy
    ]

    printOn: aStream [
        aStream nextPutAll: 'VectorClock('.
        entries keysAndValuesDo: [ :k :v |
            aStream nextPutAll: k; nextPut: $:; nextPutAll: v printString; nextPutAll: ', '.
        ].
        aStream nextPut: $)
    ]
]
