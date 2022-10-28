"=============================================================================
 Lattice BPlusTree: High-Order B+ Tree for Secondary Indexing and Range Scans
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: BPlusTreeNode [
    | keys children isLeaf nextLeaf prevLeaf parent |

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
        parent := nil.
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

    parent [
        ^ parent
    ]

    parent: aNode [
        parent := aNode.
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
        aNode isLeaf ifTrue: [
            idx := 1.
            [ idx <= aNode keys size ] whileTrue: [
                (aNode keys at: idx) = aKey ifTrue: [
                    ^ aNode children at: idx
                ].
                idx := idx + 1.
            ].
            ^ nil
        ].
        idx := 1.
        [ idx <= aNode keys size and: [ aKey >= (aNode keys at: idx) ] ] whileTrue: [
            idx := idx + 1.
        ].
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
        | mid newLeaf splitKey p idx |
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
        p := aLeaf parent.

        p isNil ifTrue: [
            p := BPlusTreeNode newInternal.
            p keys add: splitKey.
            p children add: aLeaf.
            p children add: newLeaf.
            aLeaf parent: p.
            newLeaf parent: p.
            root := p.
        ] ifFalse: [
            newLeaf parent: p.
            idx := p children indexOf: aLeaf.
            p keys add: splitKey beforeIndex: idx.
            p children add: newLeaf beforeIndex: (idx + 1).
            p keys size >= order ifTrue: [
                self splitInternal: p.
            ].
        ].
    ]

    splitInternal: aNode [
        | mid upKey newNode p idx |
        mid := (aNode keys size // 2) + 1.
        upKey := aNode keys at: mid.
        newNode := BPlusTreeNode newInternal.

        [ aNode keys size > mid ] whileTrue: [
            newNode keys addFirst: aNode keys removeLast.
        ].
        aNode keys removeLast.

        [ aNode children size > mid ] whileTrue: [
            | child |
            child := aNode children removeLast.
            child parent: newNode.
            newNode children addFirst: child.
        ].

        p := aNode parent.
        p isNil ifTrue: [
            p := BPlusTreeNode newInternal.
            p keys add: upKey.
            p children add: aNode.
            p children add: newNode.
            aNode parent: p.
            newNode parent: p.
            root := p.
        ] ifFalse: [
            newNode parent: p.
            idx := p children indexOf: aNode.
            p keys add: upKey beforeIndex: idx.
            p children add: newNode beforeIndex: (idx + 1).
            p keys size >= order ifTrue: [
                self splitInternal: p.
            ].
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
