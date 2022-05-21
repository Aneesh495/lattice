"=============================================================================
 LatticeId: 128-bit Universally Unique Identifier (RFC 4122 UUIDv4)
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeId [
    | rawBytes cachedString cachedHash |

    LatticeId class >> generate [
        "Generate a cryptographically randomized RFC 4122 variant 1, version 4 UUID.
         Bytes 7 is set to version 4 (0100xxxx), and byte 9 is set to variant 1 (10xxxxxx)."
        | bytes r |
        bytes := ByteArray new: 16.
        r := Random new.
        1 to: 16 do: [ :i |
            bytes at: i put: (r next * 256) truncated.
        ].
        "Set Version 4 in high nibble of octet 7"
        bytes at: 7 put: (((bytes at: 7) bitAnd: 16r0F) bitOr: 16r40).
        "Set Variant 1 in high bits of octet 9"
        bytes at: 9 put: (((bytes at: 9) bitAnd: 16r3F) bitOr: 16r80).
        ^ self fromBytes: bytes
    ]

    LatticeId class >> fromBytes: aByteArray [
        "Construct an identifier from a 16-byte array."
        (aByteArray size = 16) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'LatticeId requires exactly 16 bytes'
        ].
        ^ (self new) initializeWithBytes: aByteArray
    ]

    LatticeId class >> fromString: aString [
        "Parse a canonical 36-character hexadecimal UUID string.
         Format: 8-4-4-4-12 (e.g., 550e8400-e29b-41d4-a716-446655440000)."
        | clean hexBytes byteIdx |
        (aString size = 36) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'Invalid UUID string length: ', aString size printString
        ].
        clean := aString copyWithout: $-.
        (clean size = 32) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'Malformed UUID string format'
        ].
        hexBytes := ByteArray new: 16.
        byteIdx := 1.
        1 to: 31 by: 2 do: [ :i |
            | high low b |
            high := self hexValueFor: (clean at: i).
            low := self hexValueFor: (clean at: i + 1).
            b := (high bitShift: 4) bitOr: low.
            hexBytes at: byteIdx put: b.
            byteIdx := byteIdx + 1.
        ].
        ^ self fromBytes: hexBytes
    ]

    LatticeId class >> hexValueFor: aChar [
        | code |
        code := aChar asInteger.
        "Digits 0-9"
        (code >= 48 and: [ code <= 57 ]) ifTrue: [ ^ code - 48 ].
        "Lowercase a-f"
        (code >= 97 and: [ code <= 102 ]) ifTrue: [ ^ code - 87 ].
        "Uppercase A-F"
        (code >= 65 and: [ code <= 70 ]) ifTrue: [ ^ code - 55 ].
        SystemExceptions.InvalidArgument signal: 'Invalid hexadecimal character: ', aChar asString
    ]

    initializeWithBytes: aByteArray [
        rawBytes := aByteArray copy.
        cachedString := nil.
        cachedHash := nil.
        ^ self
    ]

    bytes [
        "Return the 16-byte raw byte array representation."
        ^ rawBytes copy
    ]

    asString [
        "Return canonical 36-character string representation."
        cachedString ifNil: [
            | stream hexTable |
            stream := WriteStream on: (String new: 36).
            hexTable := '0123456789abcdef'.
            1 to: 16 do: [ :i |
                | b |
                b := rawBytes at: i.
                stream nextPut: (hexTable at: ((b bitShift: -4) + 1)).
                stream nextPut: (hexTable at: ((b bitAnd: 16r0F) + 1)).
                (i = 4 or: [ i = 6 or: [ i = 8 or: [ i = 10 ] ] ]) ifTrue: [
                    stream nextPut: $-
                ].
            ].
            cachedString := stream contents.
        ].
        ^ cachedString
    ]

    printOn: aStream [
        aStream nextPutAll: 'LatticeId('; nextPutAll: self asString; nextPut: $)
    ]

    = anObject [
        (anObject isKindOf: LatticeId) ifFalse: [ ^ false ].
        ^ rawBytes = anObject bytes
    ]

    hash [
        cachedHash ifNil: [
            | h |
            h := 2166136261. "FNV-1a 32-bit offset basis"
            1 to: 16 do: [ :i |
                h := (h bitXor: (rawBytes at: i)) * 16777619.
                h := h bitAnd: 16r7FFFFFFF.
            ].
            cachedHash := h.
        ].
        ^ cachedHash
    ]

    < anObject [
        "Lexicographical ordering across the 16 raw bytes."
        | otherBytes |
        otherBytes := anObject bytes.
        1 to: 16 do: [ :i |
            | b1 b2 |
            b1 := rawBytes at: i.
            b2 := otherBytes at: i.
            (b1 < b2) ifTrue: [ ^ true ].
            (b1 > b2) ifTrue: [ ^ false ].
        ].
        ^ false
    ]
]
