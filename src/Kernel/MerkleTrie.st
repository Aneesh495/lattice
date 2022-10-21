"=============================================================================
 MerkleTrie: Merkle Patricia Trie for Verifiable Object Graph State Roots
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: TrieNode [
    rootHash [
        ^ 0
    ]
]

TrieNode subclass: TrieLeafNode [
    | path value |

    TrieLeafNode class >> path: aPath value: aVal [
        ^ (self new) initializePath: aPath value: aVal
    ]

    initializePath: aPath value: aVal [
        path := aPath.
        value := aVal.
        ^ self
    ]

    path [
        ^ path
    ]

    value [
        ^ value
    ]

    rootHash [
        | buf |
        buf := ByteBuffer allocate: 32.
        buf writeString: path.
        buf writeBytes: value.
        ^ CRC32C checksum: buf asByteArray
    ]
]

TrieNode subclass: TrieBranchNode [
    | children value |

    TrieBranchNode class >> new [
        ^ (super new) initialize
    ]

    initialize [
        children := Array new: 16.
        value := nil.
        ^ self
    ]

    childAt: aNibble [
        ^ children at: (aNibble + 1)
    ]

    childAt: aNibble put: aNode [
        children at: (aNibble + 1) put: aNode.
        ^ self
    ]

    value [
        ^ value
    ]

    value: aVal [
        value := aVal.
        ^ self
    ]

    rootHash [
        | buf |
        buf := ByteBuffer allocate: 68.
        1 to: 16 do: [ :i |
            | child |
            child := children at: i.
            child ifNotNil: [
                buf writeUInt32: child rootHash.
            ] ifNil: [
                buf writeUInt32: 0.
            ].
        ].
        value ifNotNil: [ buf writeBytes: value ].
        ^ CRC32C checksum: buf asByteArray
    ]
]

Object subclass: MerklePatriciaTrie [
    | root |

    MerklePatriciaTrie class >> new [
        ^ (super new) initialize
    ]

    initialize [
        root := nil.
        ^ self
    ]

    put: aKeyString value: aByteArray [
        "Insert key-value pair using hex nibble path."
        | valBytes |
        valBytes := aByteArray asByteArray.
        root ifNil: [
            root := TrieLeafNode path: aKeyString value: valBytes.
            ^ self
        ].

        (root isKindOf: TrieLeafNode) ifTrue: [
            root path = aKeyString ifTrue: [
                root := TrieLeafNode path: aKeyString value: valBytes.
                ^ self
            ] ifFalse: [
                | b |
                b := TrieBranchNode new.
                self insertIntoBranch: b path: root path value: root value.
                self insertIntoBranch: b path: aKeyString value: valBytes.
                root := b.
                ^ self
            ].
        ].

        (root isKindOf: TrieBranchNode) ifTrue: [
            self insertIntoBranch: root path: aKeyString value: valBytes.
        ].
        ^ self
    ]

    insertIntoBranch: aBranch path: aPath value: aVal [
        | nibble subPath existing |
        aPath isEmpty ifTrue: [
            aBranch value: aVal.
            ^ self
        ].

        nibble := (aPath at: 1) asInteger \\ 16.
        subPath := aPath size > 1 ifTrue: [ aPath copyFrom: 2 to: aPath size ] ifFalse: [ '' ].
        existing := aBranch childAt: nibble.

        existing ifNil: [
            aBranch childAt: nibble put: (TrieLeafNode path: subPath value: aVal).
        ] ifNotNil: [
            (existing isKindOf: TrieLeafNode) ifTrue: [
                existing path = subPath ifTrue: [
                    aBranch childAt: nibble put: (TrieLeafNode path: subPath value: aVal).
                ] ifFalse: [
                    | childBranch |
                    childBranch := TrieBranchNode new.
                    self insertIntoBranch: childBranch path: existing path value: existing value.
                    self insertIntoBranch: childBranch path: subPath value: aVal.
                    aBranch childAt: nibble put: childBranch.
                ].
            ] ifFalse: [
                self insertIntoBranch: existing path: subPath value: aVal.
            ].
        ].
    ]

    at: aKeyString [
        root ifNil: [ ^ nil ].
        (root isKindOf: TrieLeafNode) ifTrue: [
            ^ root path = aKeyString ifTrue: [ root value ] ifFalse: [ nil ]
        ].
        ^ self searchInBranch: root path: aKeyString
    ]

    searchInBranch: aBranch path: aPath [
        | nibble subPath child |
        aPath isEmpty ifTrue: [ ^ aBranch value ].
        nibble := (aPath at: 1) asInteger \\ 16.
        subPath := aPath size > 1 ifTrue: [ aPath copyFrom: 2 to: aPath size ] ifFalse: [ '' ].
        child := aBranch childAt: nibble.
        child ifNil: [ ^ nil ].
        (child isKindOf: TrieLeafNode) ifTrue: [
            ^ child path = subPath ifTrue: [ child value ] ifFalse: [ nil ]
        ].
        ^ self searchInBranch: child path: subPath
    ]

    rootHash [
        root ifNil: [ ^ 0 ].
        ^ root rootHash
    ]
]
