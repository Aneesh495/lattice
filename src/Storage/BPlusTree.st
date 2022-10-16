"=============================================================================
 BPlusTree: High-Order B+ Tree for Secondary Indexing and Range Scans
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: BPlusTreeNode [
    | keys children isLeaf nextLeaf prevLeaf |

    BPlusTreeNode class >> newLeaf [
        ^ (self new) initializeLeaf: true
    ]

    BPlusTreeNode class >> newInternal [
        ^ (self new) initializeLeaf: false
    ]

    initializeLeaf: aBoolean [
        isLeaf := aBoolean.
        keys := OrderedCollection new.
        children := OrderedCollection new.
        nextLeaf := nil.
        prevLeaf := nil.
        ^ self
    ]

    isLeaf [
        ^ isLeaf
    ]

    keys [
        ^ keys
    ]

    children [
        ^ children
    ]

    nextLeaf [
        ^ nextLeaf
    ]

    nextLeaf: aNode [
        nextLeaf := aNode.
        ^ self
    ]

    prevLeaf [
        ^ prevLeaf
    ]

    prevLeaf: aNode [
        prevLeaf := aNode.
        ^ self
    ]
]

Object subclass: BPlusTree [
    | root order |

    BPlusTree class >> new [
        ^ self order: 4
    ]

    BPlusTree class >> order: anInteger [
        ^ (super new) initializeOrder: anInteger
    ]

    initializeOrder: anInteger [
        order := anInteger.
        root := BPlusTreeNode newLeaf.
        ^ self
    ]

    searchKey: aKey inNode: aNode [
        | idx |
        idx := 1.
        [ idx <= aNode keys size and: [ (aNode keys at: idx) <= aKey ] ] whileTrue: [
            (aNode isLeaf and: [ (aNode keys at: idx) = aKey ]) ifTrue: [
                ^ aNode children at: idx
            ].
            idx := idx + 1.
        ].
        aNode isLeaf ifTrue: [ ^ nil ].
        ^ self searchKey: aKey inNode: (aNode children at: idx)
    ]

    at: aKey [
        ^ self searchKey: aKey inNode: root
    ]

    put: aKey value: aValue [
        | leaf idx |
        leaf := self findLeafFor: aKey inNode: root.
        idx := 1.
        [ idx <= leaf keys size and: [ (leaf keys at: idx) < aKey ] ] whileTrue: [
            idx := idx + 1.
        ].
        (idx <= leaf keys size and: [ (leaf keys at: idx) = aKey ]) ifTrue: [
            leaf children at: idx put: aValue.
            ^ self
        ].

        leaf keys add: aKey beforeIndex: idx.
        leaf children add: aValue beforeIndex: idx.

        leaf keys size >= order ifTrue: [
            self splitLeaf: leaf.
        ].
        ^ self
    ]

    findLeafFor: aKey inNode: aNode [
        | idx |
        aNode isLeaf ifTrue: [ ^ aNode ].
        idx := 1.
        [ idx <= aNode keys size and: [ aKey >= (aNode keys at: idx) ] ] whileTrue: [
            idx := idx + 1.
        ].
        ^ self findLeafFor: aKey inNode: (aNode children at: idx)
    ]

    splitLeaf: aLeaf [
        | mid newLeaf splitKey parent |
        mid := (aLeaf keys size // 2) + 1.
        newLeaf := BPlusTreeNode newLeaf.

        [ aLeaf keys size >= mid ] whileTrue: [
            newLeaf keys addFirst: aLeaf keys removeLast.
            newLeaf children addFirst: aLeaf children removeLast.
        ].

        newLeaf nextLeaf: aLeaf nextLeaf.
        newLeaf prevLeaf: aLeaf.
        aLeaf nextLeaf ifNotNil: [ aLeaf nextLeaf prevLeaf: newLeaf ].
        aLeaf nextLeaf: newLeaf.

        splitKey := newLeaf keys first.

        aLeaf == root ifTrue: [
            parent := BPlusTreeNode newInternal.
            parent keys add: splitKey.
            parent children add: aLeaf.
            parent children add: newLeaf.
            root := parent.
        ].
    ]

    rangeFrom: startKey to: endKey [
        | leaf results currentLeaf idx |
        results := OrderedCollection new.
        leaf := self findLeafFor: startKey inNode: root.
        currentLeaf := leaf.

        [ currentLeaf notNil ] whileTrue: [
            idx := 1.
            [ idx <= currentLeaf keys size ] whileTrue: [
                | k v |
                k := currentLeaf keys at: idx.
                v := currentLeaf children at: idx.
                (k >= startKey and: [ k <= endKey ]) ifTrue: [
                    results add: (Dictionary new at: 'key' put: k; at: 'value' put: v; yourself).
                ].
                k > endKey ifTrue: [ ^ results ].
                idx := idx + 1.
            ].
            currentLeaf := currentLeaf nextLeaf.
        ].
        ^ results
    ]
]
