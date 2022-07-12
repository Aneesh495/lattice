"=============================================================================
 GrainId: Logical Virtual Actor Identity (Type and Partition Key)
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: GrainId [
    | grainType key cachedString cachedHash |

    GrainId class >> type: aType key: aKey [
        ^ (self new) initializeType: aType key: aKey
    ]

    GrainId class >> fromString: aString [
        "Parse canonical 'Type/Key' string format (e.g., 'Account/acc-1049')."
        | slashIdx t k |
        slashIdx := aString indexOf: $/.
        (slashIdx < 2 or: [ slashIdx >= aString size ]) ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Invalid GrainId format; expected Type/Key'
        ].
        t := (aString copyFrom: 1 to: slashIdx - 1) asSymbol.
        k := aString copyFrom: slashIdx + 1 to: aString size.
        ^ self type: t key: k
    ]

    initializeType: aType key: aKey [
        grainType := aType asSymbol.
        key := aKey asString.
        cachedString := nil.
        cachedHash := nil.
        ^ self
    ]

    grainType [
        ^ grainType
    ]

    key [
        ^ key
    ]

    asString [
        cachedString ifNil: [
            cachedString := grainType asString , '/' , key.
        ].
        ^ cachedString
    ]

    printOn: aStream [
        aStream nextPutAll: 'GrainId('; nextPutAll: self asString; nextPut: $)
    ]

    = anObject [
        (anObject isKindOf: GrainId) ifFalse: [ ^ false ].
        ^ (grainType = anObject grainType) and: [ key = anObject key ]
    ]

    hash [
        cachedHash ifNil: [
            cachedHash := (grainType hash bitXor: key hash) bitAnd: 16r7FFFFFFF.
        ].
        ^ cachedHash
    ]

    < anObject [
        (grainType = anObject grainType) ifTrue: [
            ^ key < anObject key
        ].
        ^ grainType asString < anObject grainType asString
    ]
]
