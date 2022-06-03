"=============================================================================
 PriorityQueue: Binary Heap Priority Queue for Actor Message Prioritization
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: PriorityQueue [
    | elements priorities count |

    PriorityQueue class >> new [
        ^ self capacity: 32
    ]

    PriorityQueue class >> capacity: initialCap [
        ^ (super new) initializeCapacity: initialCap
    ]

    initializeCapacity: initialCap [
        elements := Array new: (initialCap max: 16).
        priorities := Array new: (initialCap max: 16).
        count := 0.
        ^ self
    ]

    size [
        ^ count
    ]

    isEmpty [
        ^ count = 0
    ]

    ensureCapacity [
        count >= elements size ifTrue: [
            | newCap newElems newPrios |
            newCap := elements size * 2.
            newElems := Array new: newCap.
            newPrios := Array new: newCap.
            1 to: count do: [ :i |
                newElems at: i put: (elements at: i).
                newPrios at: i put: (priorities at: i).
            ].
            elements := newElems.
            priorities := newPrios.
        ].
        ^ self
    ]

    push: anObject priority: anInteger [
        "Insert an element with integer priority (higher integer = higher priority).
         Maintains max-heap invariant via sift-up."
        | idx parentIdx done |
        self ensureCapacity.
        count := count + 1.
        idx := count.
        done := false.

        [ (idx > 1) and: [ done not ] ] whileTrue: [
            parentIdx := idx // 2.
            (anInteger > (priorities at: parentIdx)) ifTrue: [
                elements at: idx put: (elements at: parentIdx).
                priorities at: idx put: (priorities at: parentIdx).
                idx := parentIdx.
            ] ifFalse: [
                done := true.
            ].
        ].

        elements at: idx put: anObject.
        priorities at: idx put: anInteger.
        ^ self
    ]

    pop [
        "Remove and return the highest priority element via sift-down."
        | result lastElem lastPrio idx childIdx done |
        count = 0 ifTrue: [ ^ nil ].
        result := elements at: 1.
        lastElem := elements at: count.
        lastPrio := priorities at: count.
        elements at: count put: nil.
        priorities at: count put: nil.
        count := count - 1.

        count > 0 ifTrue: [
            idx := 1.
            done := false.
            [ ((idx * 2) <= count) and: [ done not ] ] whileTrue: [
                childIdx := idx * 2.
                ((childIdx < count) and: [ (priorities at: childIdx + 1) > (priorities at: childIdx) ]) ifTrue: [
                    childIdx := childIdx + 1.
                ].
                (lastPrio < (priorities at: childIdx)) ifTrue: [
                    elements at: idx put: (elements at: childIdx).
                    priorities at: idx put: (priorities at: childIdx).
                    idx := childIdx.
                ] ifFalse: [
                    done := true.
                ].
            ].
            elements at: idx put: lastElem.
            priorities at: idx put: lastPrio.
        ].

        ^ result
    ]

    peek [
        count = 0 ifTrue: [ ^ nil ].
        ^ elements at: 1
    ]
]
