"=============================================================================
 ByteBuffer: Dynamic Big-Endian Binary Buffer for Wire and Storage Serialization
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: ByteBuffer [
    | storage readerIdx writerIdx |

    ByteBuffer class >> allocate: capacity [
        ^ (self new) initializeCapacity: capacity
    ]

    ByteBuffer class >> wrap: aByteArray [
        ^ (self new) initializeWithBytes: aByteArray
    ]

    initializeCapacity: capacity [
        storage := ByteArray new: (capacity max: 16).
        readerIdx := 1.
        writerIdx := 1.
        ^ self
    ]

    initializeWithBytes: aByteArray [
        storage := aByteArray copy.
        readerIdx := 1.
        writerIdx := storage size + 1.
        ^ self
    ]

    capacity [
        ^ storage size
    ]

    readerIndex [
        ^ readerIdx
    ]

    readerIndex: anIndex [
        readerIdx := anIndex.
        ^ self
    ]

    writerIndex [
        ^ writerIdx
    ]

    writerIndex: anIndex [
        writerIdx := anIndex.
        ^ self
    ]

    readableBytes [
        ^ (writerIdx - readerIdx) max: 0
    ]

    ensureWritable: requiredBytes [
        | needed minCap newCap newStorage |
        needed := (writerIdx + requiredBytes) - 1.
        needed <= storage size ifTrue: [ ^ self ].
        minCap := needed.
        newCap := storage size * 2 max: minCap.
        newStorage := ByteArray new: newCap.
        newStorage replaceFrom: 1 to: storage size with: storage startingAt: 1.
        storage := newStorage.
        ^ self
    ]

    "-------------------------------------------------------------------------
     Write Operations (Big-Endian Network Byte Order)
    -------------------------------------------------------------------------"

    writeUInt8: aByte [
        self ensureWritable: 1.
        storage at: writerIdx put: (aByte bitAnd: 16rFF).
        writerIdx := writerIdx + 1.
        ^ self
    ]

    writeInt8: anInt [
        | b |
        b := anInt < 0 ifTrue: [ 256 + anInt ] ifFalse: [ anInt ].
        ^ self writeUInt8: b
    ]

    writeUInt16: anInt [
        self ensureWritable: 2.
        storage at: writerIdx put: ((anInt bitShift: -8) bitAnd: 16rFF).
        storage at: writerIdx + 1 put: (anInt bitAnd: 16rFF).
        writerIdx := writerIdx + 2.
        ^ self
    ]

    writeInt16: anInt [
        | val |
        val := anInt < 0 ifTrue: [ 65536 + anInt ] ifFalse: [ anInt ].
        ^ self writeUInt16: val
    ]

    writeUInt32: anInt [
        self ensureWritable: 4.
        storage at: writerIdx put: ((anInt bitShift: -24) bitAnd: 16rFF).
        storage at: writerIdx + 1 put: ((anInt bitShift: -16) bitAnd: 16rFF).
        storage at: writerIdx + 2 put: ((anInt bitShift: -8) bitAnd: 16rFF).
        storage at: writerIdx + 3 put: (anInt bitAnd: 16rFF).
        writerIdx := writerIdx + 4.
        ^ self
    ]

    writeInt32: anInt [
        | val |
        val := anInt < 0 ifTrue: [ 4294967296 + anInt ] ifFalse: [ anInt ].
        ^ self writeUInt32: val
    ]

    writeUInt64: anInt [
        "Write 64-bit unsigned integer split into two 32-bit words."
        | high low |
        high := (anInt bitShift: -32) bitAnd: 16rFFFFFFFF.
        low := anInt bitAnd: 16rFFFFFFFF.
        self writeUInt32: high.
        self writeUInt32: low.
        ^ self
    ]

    writeInt64: anInt [
        | val |
        val := anInt < 0 ifTrue: [ (1 bitShift: 64) + anInt ] ifFalse: [ anInt ].
        ^ self writeUInt64: val
    ]

    writeBytes: aByteArray [
        | len |
        len := aByteArray size.
        self ensureWritable: len.
        storage replaceFrom: writerIdx to: writerIdx + len - 1 with: aByteArray startingAt: 1.
        writerIdx := writerIdx + len.
        ^ self
    ]

    writeString: aString [
        "Length-prefixed UTF-8 string: 32-bit unsigned length followed by bytes."
        | bytes |
        bytes := aString asByteArray.
        self writeUInt32: bytes size.
        self writeBytes: bytes.
        ^ self
    ]

    "-------------------------------------------------------------------------
     Read Operations (Big-Endian Network Byte Order)
    -------------------------------------------------------------------------"

    readUInt8 [
        | b |
        (self readableBytes < 1) ifTrue: [ SystemExceptions.InvalidArgument signal: 'Underflow reading UInt8' ].
        b := storage at: readerIdx.
        readerIdx := readerIdx + 1.
        ^ b
    ]

    readInt8 [
        | b |
        b := self readUInt8.
        ^ b >= 128 ifTrue: [ b - 256 ] ifFalse: [ b ]
    ]

    readUInt16 [
        | b0 b1 |
        (self readableBytes < 2) ifTrue: [ SystemExceptions.InvalidArgument signal: 'Underflow reading UInt16' ].
        b0 := storage at: readerIdx.
        b1 := storage at: readerIdx + 1.
        readerIdx := readerIdx + 2.
        ^ (b0 bitShift: 8) bitOr: b1
    ]

    readInt16 [
        | val |
        val := self readUInt16.
        ^ val >= 32768 ifTrue: [ val - 65536 ] ifFalse: [ val ]
    ]

    readUInt32 [
        | b0 b1 b2 b3 |
        (self readableBytes < 4) ifTrue: [ SystemExceptions.InvalidArgument signal: 'Underflow reading UInt32' ].
        b0 := storage at: readerIdx.
        b1 := storage at: readerIdx + 1.
        b2 := storage at: readerIdx + 2.
        b3 := storage at: readerIdx + 3.
        readerIdx := readerIdx + 4.
        ^ (((b0 bitShift: 24) bitOr: (b1 bitShift: 16)) bitOr: (b2 bitShift: 8)) bitOr: b3
    ]

    readInt32 [
        | val |
        val := self readUInt32.
        ^ val >= 2147483648 ifTrue: [ val - 4294967296 ] ifFalse: [ val ]
    ]

    readUInt64 [
        | high low |
        high := self readUInt32.
        low := self readUInt32.
        ^ (high bitShift: 32) bitOr: low
    ]

    readInt64 [
        | val |
        val := self readUInt64.
        ^ val >= (1 bitShift: 63) ifTrue: [ val - (1 bitShift: 64) ] ifFalse: [ val ]
    ]

    readBytes: count [
        | slice |
        (self readableBytes < count) ifTrue: [ SystemExceptions.InvalidArgument signal: 'Underflow reading bytes' ].
        slice := storage copyFrom: readerIdx to: readerIdx + count - 1.
        readerIdx := readerIdx + count.
        ^ slice
    ]

    readString [
        | len bytes |
        len := self readUInt32.
        bytes := self readBytes: len.
        ^ bytes asString
    ]

    asByteArray [
        "Return the written slice from 1 to writerIdx - 1."
        ^ storage copyFrom: 1 to: writerIdx - 1
    ]

    readableByteArray [
        "Return only the remaining unread slice."
        ^ storage copyFrom: readerIdx to: writerIdx - 1
    ]

    reset [
        readerIdx := 1.
        writerIdx := 1.
        ^ self
    ]
]
