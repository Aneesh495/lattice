"=============================================================================
 BitemporalEvent: Dual-Axis Temporal Event Representation (TxTime vs ValidTime)
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: BitemporalEvent [
    | eventId aggregateId eventType sequenceNumber txTime validTime payload |

    BitemporalEvent class >> aggregateId: anAggId
                                eventType: aType
                           sequenceNumber: aSeq
                                   txTime: aTx
                                validTime: aValid
                                  payload: aPayload [
        ^ (self new) initializeEventId: LatticeId generate
                           aggregateId: anAggId
                             eventType: aType
                        sequenceNumber: aSeq
                                txTime: aTx
                             validTime: aValid
                               payload: aPayload
    ]

    initializeEventId: anId
          aggregateId: anAggId
            eventType: aType
       sequenceNumber: aSeq
               txTime: aTx
            validTime: aValid
              payload: aPayload [
        eventId := anId.
        aggregateId := anAggId asString.
        eventType := aType asSymbol.
        sequenceNumber := aSeq.
        txTime := aTx.
        validTime := aValid.
        payload := aPayload.
        ^ self
    ]

    id [
        ^ eventId
    ]

    aggregateId [
        ^ aggregateId
    ]

    eventType [
        ^ eventType
    ]

    sequenceNumber [
        ^ sequenceNumber
    ]

    txTime [
        ^ txTime
    ]

    validTime [
        ^ validTime
    ]

    payload [
        ^ payload
    ]

    encode [
        | buf payloadBytes |
        buf := ByteBuffer allocate: 128.
        buf writeBytes: eventId bytes.
        buf writeString: aggregateId.
        buf writeString: eventType asString.
        buf writeUInt64: sequenceNumber.
        buf writeUInt64: txTime.
        buf writeUInt64: validTime.

        payloadBytes := WireSerializer serialize: payload.
        buf writeUInt32: payloadBytes size.
        buf writeBytes: payloadBytes.
        ^ buf asByteArray
    ]

    BitemporalEvent class >> decodeFrom: aBuffer [
        | idBytes aggId typeStr seq tx valid payloadLen payloadBytes p |
        idBytes := aBuffer readBytes: 16.
        aggId := aBuffer readString.
        typeStr := aBuffer readString.
        seq := aBuffer readUInt64.
        tx := aBuffer readUInt64.
        valid := aBuffer readUInt64.

        payloadLen := aBuffer readUInt32.
        payloadBytes := aBuffer readBytes: payloadLen.
        p := WireSerializer deserialize: payloadBytes.

        ^ (self new) initializeEventId: (LatticeId fromBytes: idBytes)
                           aggregateId: aggId
                             eventType: typeStr asSymbol
                        sequenceNumber: seq
                                txTime: tx
                             validTime: valid
                               payload: p
    ]

    printOn: aStream [
        aStream nextPutAll: 'BitemporalEvent(';
                nextPutAll: eventType asString;
                nextPutAll: ', agg='; nextPutAll: aggregateId;
                nextPutAll: ', seq='; nextPutAll: sequenceNumber printString;
                nextPutAll: ', tx='; nextPutAll: txTime printString;
                nextPutAll: ', valid='; nextPutAll: validTime printString;
                nextPut: $)
    ]
]
