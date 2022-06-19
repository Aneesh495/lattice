"=============================================================================
 WireTest: Unit Test Suite for CRC32C, Wire Framing, and Binary Serialization
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: WireTest [

    testCrc32cRfcVector [
        | data crc |
        data := '123456789' asByteArray.
        crc := CRC32C checksum: data.
        self assert: crc equals: 16rE3069283.
    ]

    testCrc32cBitCorruptionDetection [
        | data crc corrupted corruptedCrc |
        data := 'Distributed Virtual Actor Mesh Turn' asByteArray.
        crc := CRC32C checksum: data.

        corrupted := data copy.
        corrupted at: 1 put: ((corrupted at: 1) bitXor: 1).
        corruptedCrc := CRC32C checksum: corrupted.

        self deny: crc equals: corruptedCrc.
    ]

    testWireFrameRoundtrip [
        | payload frame encoded buf decoded |
        payload := 'Actor invocation payload: transfer(amount: 500)' asByteArray.
        frame := WireFrame opcode: WireFrame opGrainMessage
                           flags: 1
                      sequenceId: 987654321
                         payload: payload.

        encoded := frame encode.
        self assert: (encoded size = (24 + payload size)).

        buf := ByteBuffer wrap: encoded.
        decoded := WireFrame decodeFrom: buf.

        self assert: decoded opcode equals: WireFrame opGrainMessage.
        self assert: decoded flags equals: 1.
        self assert: decoded sequenceId equals: 987654321.
        self assert: decoded payload asString equals: payload asString.
    ]

    testWireFrameCrcCorruptionFails [
        | frame encoded corrupted buf |
        frame := WireFrame opcode: WireFrame opAppendEntries
                           flags: 0
                      sequenceId: 1
                         payload: 'test entry' asByteArray.
        encoded := frame encode.

        "Corrupt a byte in payload"
        corrupted := encoded copy.
        corrupted at: (corrupted size) put: ((corrupted at: corrupted size) bitXor: 16rFF).

        buf := ByteBuffer wrap: corrupted.
        self should: [ WireFrame decodeFrom: buf ] raise: SystemExceptions.InvalidArgument.
    ]

    testWireSerializerPrimitivesAndCollections [
        | orig bytes restored |
        orig := Dictionary new.
        orig at: 'int' put: -9999999999.
        orig at: 'bool' put: true.
        orig at: 'sym' put: #processTurn.
        orig at: 'arr' put: #('alpha' 'beta' 123).
        orig at: 'clock' put: (VectorClock new tick: 'nodeA'; tick: 'nodeB').
        orig at: 'id' put: LatticeId generate.

        bytes := WireSerializer serialize: orig.
        restored := WireSerializer deserialize: bytes.

        self assert: (restored at: 'int') equals: -9999999999.
        self assert: (restored at: 'bool') equals: true.
        self assert: (restored at: 'sym') equals: #processTurn.
        self assert: ((restored at: 'arr') at: 1) equals: 'alpha'.
        self assert: ((restored at: 'clock') at: 'nodeA') equals: 1.
        self assert: (restored at: 'id') equals: (orig at: 'id').
    ]
]
