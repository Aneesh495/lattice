"=============================================================================
 BloomFilter: Probabilistic Membership Filter for Storage Fast-Paths
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: BloomFilter [
    | bitArray sizeInBits hashCount count |

    BloomFilter class >> expectedElements: n falsePositiveRate: p [
        | m k |
        "Calculate optimal m = -(n * ln(p)) / (ln(2)^2)"
        "Calculate optimal k = (m / n) * ln(2)"
        m := ((n negated * (p ln)) / (0.69314718056 * 0.69314718056)) rounded max: 64.
        k := (((m asFloat / n asFloat) * 0.69314718056) rounded max: 1) min: 16.
        ^ (self new) initializeBits: m hashCount: k
    ]

    initializeBits: m hashCount: k [
        sizeInBits := m.
        hashCount := k.
        bitArray := ByteArray new: ((sizeInBits + 7) // 8).
        count := 0.
        ^ self
    ]

    sizeInBits [
        ^ sizeInBits
    ]

    hashCount [
        ^ hashCount
    ]

    count [
        ^ count
    ]

    hash1: aString [
        "FNV-1a 32-bit"
        | h bytes |
        h := 2166136261.
        bytes := aString asByteArray.
        1 to: bytes size do: [ :i |
            h := (h bitXor: (bytes at: i)) * 16777619.
            h := h bitAnd: 16rFFFFFFFF.
        ].
        ^ h
    ]

    hash2: aString [
        "Murmur-style rotational hash"
        | h bytes |
        h := 0.
        bytes := aString asByteArray.
        1 to: bytes size do: [ :i |
            h := ((h bitShift: 5) bitOr: (h bitShift: -27)) bitXor: (bytes at: i).
            h := (h * 16r5BD1E995) bitAnd: 16rFFFFFFFF.
        ].
        ^ h
    ]

    add: anItem [
        | s h1 h2 |
        s := anItem asString.
        h1 := self hash1: s.
        h2 := self hash2: s.

        1 to: hashCount do: [ :i |
            | combinedBit byteIdx bitOffset |
            combinedBit := (h1 + (i * h2)) \\ sizeInBits.
            byteIdx := (combinedBit // 8) + 1.
            bitOffset := combinedBit \\ 8.
            bitArray at: byteIdx put: ((bitArray at: byteIdx) bitOr: (1 bitShift: bitOffset)).
        ].
        count := count + 1.
        ^ self
    ]

    mightContain: anItem [
        | s h1 h2 |
        s := anItem asString.
        h1 := self hash1: s.
        h2 := self hash2: s.

        1 to: hashCount do: [ :i |
            | combinedBit byteIdx bitOffset |
            combinedBit := (h1 + (i * h2)) \\ sizeInBits.
            byteIdx := (combinedBit // 8) + 1.
            bitOffset := combinedBit \\ 8.
            ((bitArray at: byteIdx) bitAnd: (1 bitShift: bitOffset)) = 0 ifTrue: [
                ^ false
            ].
        ].
        ^ true
    ]
]
