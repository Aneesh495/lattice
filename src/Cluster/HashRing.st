"=============================================================================
 HashRing: Consistent Hash Ring with Virtual Nodes for Grain Placement
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: HashRing [
    | vnodeCount ringKeys ringNodes physicalNodes |

    HashRing class >> new [
        ^ self virtualNodes: 128
    ]

    HashRing class >> virtualNodes: anInteger [
        ^ (super new) initializeVirtualNodes: anInteger
    ]

    initializeVirtualNodes: anInteger [
        vnodeCount := anInteger.
        ringKeys := OrderedCollection new.
        ringNodes := OrderedCollection new.
        physicalNodes := Set new.
        ^ self
    ]

    hashKey: aString [
        "FNV-1a 32-bit hash function yielding unsigned 32-bit integer [0, 4294967295]."
        | h bytes |
        h := 2166136261.
        bytes := aString asByteArray.
        1 to: bytes size do: [ :i |
            h := (h bitXor: (bytes at: i)) * 16777619.
            h := h bitAnd: 16rFFFFFFFF.
        ].
        ^ h
    ]

    addNode: aNodeId [
        "Add a physical node and generate vnodeCount virtual points across the ring."
        | nodeStr |
        nodeStr := aNodeId asString.
        (physicalNodes includes: nodeStr) ifTrue: [ ^ self ].
        physicalNodes add: nodeStr.

        0 to: vnodeCount - 1 do: [ :i |
            | vKey point idx |
            vKey := nodeStr , '#vnode:' , i printString.
            point := self hashKey: vKey.
            idx := self binarySearchIndexFor: point.
            ringKeys add: point beforeIndex: idx.
            ringNodes add: nodeStr beforeIndex: idx.
        ].
        ^ self
    ]

    removeNode: aNodeId [
        "Remove all virtual nodes associated with a physical node identifier."
        | nodeStr newKeys newNodes |
        nodeStr := aNodeId asString.
        (physicalNodes includes: nodeStr) ifFalse: [ ^ self ].
        physicalNodes remove: nodeStr.

        newKeys := OrderedCollection new.
        newNodes := OrderedCollection new.
        1 to: ringNodes size do: [ :i |
            (ringNodes at: i) ~= nodeStr ifTrue: [
                newKeys add: (ringKeys at: i).
                newNodes add: (ringNodes at: i).
            ].
        ].
        ringKeys := newKeys.
        ringNodes := newNodes.
        ^ self
    ]

    binarySearchIndexFor: aPoint [
        "Binary search to locate insertion index to maintain ringKeys sorted order."
        | low high |
        low := 1.
        high := ringKeys size.
        [ low <= high ] whileTrue: [
            | mid midVal |
            mid := (low + high) // 2.
            midVal := ringKeys at: mid.
            midVal < aPoint ifTrue: [
                low := mid + 1.
            ] ifFalse: [
                high := mid - 1.
            ].
        ].
        ^ low
    ]

    nodeForKey: aKey [
        "Return the primary physical node responsible for a given grain or partition key."
        | targetPoint idx |
        ringKeys isEmpty ifTrue: [ ^ nil ].
        targetPoint := self hashKey: aKey asString.
        idx := self binarySearchIndexFor: targetPoint.
        "If point is greater than largest ring point, wrap around to index 1"
        idx > ringKeys size ifTrue: [ idx := 1 ].
        ^ ringNodes at: idx
    ]

    nodesForKey: aKey count: replicaCount [
        "Return replicaCount distinct physical successor nodes along the ring."
        | targetPoint idx replicas seen countToFind total |
        ringKeys isEmpty ifTrue: [ ^ OrderedCollection new ].
        replicas := OrderedCollection new.
        seen := Set new.
        countToFind := replicaCount min: physicalNodes size.
        targetPoint := self hashKey: aKey asString.
        idx := self binarySearchIndexFor: targetPoint.
        idx > ringKeys size ifTrue: [ idx := 1 ].
        total := ringKeys size.

        [ replicas size < countToFind ] whileTrue: [
            | candidate |
            candidate := ringNodes at: idx.
            (seen includes: candidate) ifFalse: [
                seen add: candidate.
                replicas add: candidate.
            ].
            idx := (idx \\ total) + 1.
        ].
        ^ replicas
    ]

    nodeCount [
        ^ physicalNodes size
    ]

    totalVnodes [
        ^ ringKeys size
    ]

    nodes [
        ^ physicalNodes copy
    ]
]
