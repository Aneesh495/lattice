"=============================================================================
 WALSegment: Append-Only Write-Ahead Log Segment with CRC32C Validation
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: WALRecord [
    | recordType sequenceId payload checksum |

    WALRecord class >> type: aType sequenceId: aSeq payload: aPayload [
        ^ (self new) initializeType: aType sequenceId: aSeq payload: aPayload
    ]

    initializeType: aType sequenceId: aSeq payload: aPayload [
        recordType := aType.
        sequenceId := aSeq.
        payload := aPayload ifNil: [ ByteArray new: 0 ] ifNotNil: [ aPayload copy ].
        checksum := CRC32C checksum: payload.
        ^ self
    ]

    recordType [
        ^ recordType
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

    encode [
        | buf |
        buf := ByteBuffer allocate: 17 + payload size.
        buf writeUInt32: payload size.
        buf writeUInt8: recordType.
        buf writeUInt64: sequenceId.
        payload size > 0 ifTrue: [ buf writeBytes: payload ].
        buf writeUInt32: checksum.
        ^ buf asByteArray
    ]

    WALRecord class >> decodeFrom: aBuffer [
        | len type seq payloadSlice expectedCrc calculatedCrc |
        (aBuffer readableBytes < 17) ifTrue: [ ^ nil ].
        len := aBuffer readUInt32.
        type := aBuffer readUInt8.
        seq := aBuffer readUInt64.

        (aBuffer readableBytes < (len + 4)) ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Truncated WAL record payload'
        ].
        payloadSlice := len > 0 ifTrue: [ aBuffer readBytes: len ] ifFalse: [ ByteArray new: 0 ].
        expectedCrc := aBuffer readUInt32.

        calculatedCrc := CRC32C checksum: payloadSlice.
        (calculatedCrc = expectedCrc) ifFalse: [
            SystemExceptions.InvalidArgument signal: 'WAL record CRC32C integrity violation'
        ].

        ^ (self type: type sequenceId: seq payload: payloadSlice)
    ]
]

Object subclass: WALSegment [
    | filePath segmentId records fileStream lock isClosed |

    WALSegment class >> magic [
        "ASCII 'LWAL' = 16r4C 16r57 16r41 16r4C"
        ^ #[16r4C 16r57 16r41 16r4C]
    ]

    WALSegment class >> openPath: aFilePath segmentId: aSegId [
        ^ (self new) initializePath: aFilePath segmentId: aSegId
    ]

    initializePath: aFilePath segmentId: aSegId [
        filePath := aFilePath asString.
        segmentId := aSegId.
        records := OrderedCollection new.
        lock := Semaphore forMutualExclusion.
        isClosed := false.
        self openAndRecover.
        ^ self
    ]

    filePath [
        ^ filePath
    ]

    segmentId [
        ^ segmentId
    ]

    records [
        ^ records copy
    ]

    recordCount [
        ^ records size
    ]

    openAndRecover [
        | file exists |
        file := File name: filePath.
        exists := file exists.
        exists ifTrue: [
            | stream allBytes buf |
            stream := FileStream open: filePath mode: FileStream read.
            allBytes := stream contents asByteArray.
            stream close.

            allBytes size >= 4 ifTrue: [
                buf := ByteBuffer wrap: allBytes.
                "Validate magic"
                (buf readBytes: 4) = self class magic ifTrue: [
                    [ buf readableBytes >= 17 ] whileTrue: [
                        | rec |
                        rec := [ WALRecord decodeFrom: buf ] on: Error do: [ :ex | nil ].
                        rec ifNotNil: [ records add: rec ] ifNil: [ buf reset ].
                    ].
                ].
            ].
        ].

        "Open append write stream"
        exists ifFalse: [
            fileStream := FileStream open: filePath mode: FileStream write.
            fileStream nextPutAll: (self class magic asString).
            fileStream flush.
        ] ifTrue: [
            fileStream := FileStream open: filePath mode: FileStream append.
        ].
    ]

    appendPayload: aByteArray type: aType sequenceId: aSeq [
        | record encoded |
        lock critical: [
            isClosed ifTrue: [
                SystemExceptions.InvalidState signal: 'WAL segment is closed'
            ].
            record := WALRecord type: aType sequenceId: aSeq payload: aByteArray.
            encoded := record encode.
            fileStream nextPutAll: encoded asString.
            fileStream flush.
            records add: record.
        ].
        ^ record
    ]

    close [
        lock critical: [
            isClosed ifFalse: [
                isClosed := true.
                fileStream ifNotNil: [ fileStream close ].
            ].
        ].
        ^ self
    ]
]
