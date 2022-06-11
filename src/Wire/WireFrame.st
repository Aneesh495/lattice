"=============================================================================
 WireFrame: Lattice Wire Protocol (LWP) Binary Framing Specification
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: WireFrame [
    | opcode flags sequenceId payload checksum |

    WireFrame class >> magicBytes [
        "ASCII 'LATX' = 16r4C 16r41 16r54 16r58"
        ^ #[16r4C 16r41 16r54 16r58]
    ]

    WireFrame class >> protocolVersion [
        ^ 1
    ]

    "Opcode Enumeration"
    WireFrame class >> opHeartbeat         [ ^ 16r01 ]
    WireFrame class >> opPingReq           [ ^ 16r02 ]
    WireFrame class >> opAck               [ ^ 16r03 ]
    WireFrame class >> opRequestVote       [ ^ 16r10 ]
    WireFrame class >> opRequestVoteReply  [ ^ 16r11 ]
    WireFrame class >> opAppendEntries     [ ^ 16r12 ]
    WireFrame class >> opAppendEntriesReply[ ^ 16r13 ]
    WireFrame class >> opGrainMessage      [ ^ 16r20 ]
    WireFrame class >> opGrainReply        [ ^ 16r21 ]
    WireFrame class >> opEventBatch        [ ^ 16r30 ]
    WireFrame class >> opStreamChunk       [ ^ 16r40 ]

    WireFrame class >> opcode: anOpcode sequenceId: aSeq payload: aByteArray [
        ^ self opcode: anOpcode flags: 0 sequenceId: aSeq payload: aByteArray
    ]

    WireFrame class >> opcode: anOpcode flags: aFlags sequenceId: aSeq payload: aByteArray [
        ^ (self new) initializeOpcode: anOpcode
                              flags: aFlags
                         sequenceId: aSeq
                            payload: aByteArray
    ]

    initializeOpcode: anOpcode flags: aFlags sequenceId: aSeq payload: aByteArray [
        opcode := anOpcode.
        flags := aFlags.
        sequenceId := aSeq.
        payload := aByteArray ifNil: [ ByteArray new: 0 ] ifNotNil: [ aByteArray copy ].
        checksum := nil.
        ^ self
    ]

    opcode [
        ^ opcode
    ]

    flags [
        ^ flags
    ]

    sequenceId [
        ^ sequenceId
    ]

    payload [
        ^ payload
    ]

    checksum [
        ^ checksum
    ]

    isError [
        ^ (flags bitAnd: 2) ~= 0
    ]

    isOneWay [
        ^ (flags bitAnd: 4) ~= 0
    ]

    encode [
        "Serialize into binary byte array with 24-byte header and CRC32C trailing checksum."
        | buf headerWithoutCrc crc |
        buf := ByteBuffer allocate: 24 + payload size.

        "Magic (4 bytes)"
        buf writeBytes: (self class magicBytes).
        "Version (1 byte)"
        buf writeUInt8: (self class protocolVersion).
        "Opcode (1 byte)"
        buf writeUInt8: opcode.
        "Flags (2 bytes)"
        buf writeUInt16: flags.
        "Sequence ID (8 bytes)"
        buf writeUInt64: sequenceId.
        "Payload length (4 bytes)"
        buf writeUInt32: payload size.

        "Calculate CRC32C over the first 20 bytes of header plus payload"
        headerWithoutCrc := buf asByteArray.
        crc := CRC32C checksum: (headerWithoutCrc , payload).
        checksum := crc.

        "Checksum (4 bytes)"
        buf writeUInt32: crc.

        "Payload bytes"
        payload size > 0 ifTrue: [
            buf writeBytes: payload.
        ].

        ^ buf asByteArray
    ]

    WireFrame class >> decodeFrom: aByteBuffer [
        "Parse frame from buffer. Validates magic, version, payload length, and CRC32C."
        | magic ver op fl seq len expectedCrc payloadSlice calculatedCrc frameBytes |
        (aByteBuffer readableBytes < 24) ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Insufficient bytes for LWP frame header'
        ].

        magic := aByteBuffer readBytes: 4.
        (magic = self magicBytes) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'Invalid LWP frame magic identifier'
        ].

        ver := aByteBuffer readUInt8.
        (ver = self protocolVersion) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'Unsupported LWP protocol version: ', ver printString
        ].

        op := aByteBuffer readUInt8.
        fl := aByteBuffer readUInt16.
        seq := aByteBuffer readUInt64.
        len := aByteBuffer readUInt32.
        expectedCrc := aByteBuffer readUInt32.

        (aByteBuffer readableBytes < len) ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Incomplete frame payload'
        ].

        payloadSlice := len > 0 ifTrue: [ aByteBuffer readBytes: len ] ifFalse: [ ByteArray new: 0 ].

        "Validate CRC32C integrity"
        frameBytes := (ByteBuffer allocate: 20)
            writeBytes: magic;
            writeUInt8: ver;
            writeUInt8: op;
            writeUInt16: fl;
            writeUInt64: seq;
            writeUInt32: len;
            asByteArray.

        calculatedCrc := CRC32C checksum: (frameBytes , payloadSlice).
        (calculatedCrc = expectedCrc) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'LWP frame CRC32C checksum mismatch'
        ].

        ^ (self opcode: op flags: fl sequenceId: seq payload: payloadSlice)
    ]
]
