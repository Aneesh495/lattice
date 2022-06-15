"=============================================================================
 WireSerializer: High-Speed Compact Binary Serializer for Smalltalk Object Graphs
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: WireSerializer [
    "Type Tag Constants"
    WireSerializer class >> tagNil         [ ^ 16r00 ]
    WireSerializer class >> tagTrue        [ ^ 16r01 ]
    WireSerializer class >> tagFalse       [ ^ 16r02 ]
    WireSerializer class >> tagInteger     [ ^ 16r03 ]
    WireSerializer class >> tagFloat       [ ^ 16r04 ]
    WireSerializer class >> tagString      [ ^ 16r05 ]
    WireSerializer class >> tagSymbol      [ ^ 16r06 ]
    WireSerializer class >> tagByteArray   [ ^ 16r07 ]
    WireSerializer class >> tagCollection  [ ^ 16r08 ]
    WireSerializer class >> tagDictionary  [ ^ 16r09 ]
    WireSerializer class >> tagLatticeId   [ ^ 16r0A ]
    WireSerializer class >> tagVectorClock [ ^ 16r0B ]

    WireSerializer class >> serialize: anObject [
        | buf |
        buf := ByteBuffer allocate: 128.
        self serialize: anObject into: buf.
        ^ buf asByteArray
    ]

    WireSerializer class >> serialize: anObject into: aBuffer [
        anObject isNil ifTrue: [
            aBuffer writeUInt8: self tagNil.
            ^ self
        ].
        (anObject == true) ifTrue: [
            aBuffer writeUInt8: self tagTrue.
            ^ self
        ].
        (anObject == false) ifTrue: [
            aBuffer writeUInt8: self tagFalse.
            ^ self
        ].
        (anObject isKindOf: Integer) ifTrue: [
            aBuffer writeUInt8: self tagInteger.
            aBuffer writeInt64: anObject.
            ^ self
        ].
        (anObject isKindOf: Float) ifTrue: [
            "Store float as integer fraction / parts or scaled int"
            aBuffer writeUInt8: self tagFloat.
            aBuffer writeInt64: (anObject * 1000000) rounded.
            ^ self
        ].
        (anObject isKindOf: Symbol) ifTrue: [
            aBuffer writeUInt8: self tagSymbol.
            aBuffer writeString: anObject asString.
            ^ self
        ].
        (anObject isKindOf: String) ifTrue: [
            aBuffer writeUInt8: self tagString.
            aBuffer writeString: anObject.
            ^ self
        ].
        (anObject isKindOf: ByteArray) ifTrue: [
            aBuffer writeUInt8: self tagByteArray.
            aBuffer writeUInt32: anObject size.
            aBuffer writeBytes: anObject.
            ^ self
        ].
        (anObject isKindOf: LatticeId) ifTrue: [
            aBuffer writeUInt8: self tagLatticeId.
            aBuffer writeBytes: anObject bytes.
            ^ self
        ].
        (anObject isKindOf: VectorClock) ifTrue: [
            | dict |
            aBuffer writeUInt8: self tagVectorClock.
            dict := anObject asDictionary.
            aBuffer writeUInt32: dict size.
            dict keysAndValuesDo: [ :k :v |
                aBuffer writeString: k.
                aBuffer writeInt64: v.
            ].
            ^ self
        ].
        (anObject isKindOf: Dictionary) ifTrue: [
            aBuffer writeUInt8: self tagDictionary.
            aBuffer writeUInt32: anObject size.
            anObject keysAndValuesDo: [ :k :v |
                self serialize: k into: aBuffer.
                self serialize: v into: aBuffer.
            ].
            ^ self
        ].
        (anObject isKindOf: SequenceableCollection) ifTrue: [
            aBuffer writeUInt8: self tagCollection.
            aBuffer writeUInt32: anObject size.
            anObject do: [ :each |
                self serialize: each into: aBuffer.
            ].
            ^ self
        ].

        SystemExceptions.InvalidArgument signal: 'Cannot serialize object of type: ', anObject class printString
    ]

    WireSerializer class >> deserialize: aByteArray [
        | buf |
        buf := ByteBuffer wrap: aByteArray.
        ^ self deserializeFrom: buf
    ]

    WireSerializer class >> deserializeFrom: aBuffer [
        | tag |
        tag := aBuffer readUInt8.

        tag = self tagNil ifTrue: [ ^ nil ].
        tag = self tagTrue ifTrue: [ ^ true ].
        tag = self tagFalse ifTrue: [ ^ false ].
        tag = self tagInteger ifTrue: [ ^ aBuffer readInt64 ].
        tag = self tagFloat ifTrue: [
            | scaled |
            scaled := aBuffer readInt64.
            ^ scaled asFloat / 1000000.0
        ].
        tag = self tagSymbol ifTrue: [ ^ aBuffer readString asSymbol ].
        tag = self tagString ifTrue: [ ^ aBuffer readString ].
        tag = self tagByteArray ifTrue: [
            | len |
            len := aBuffer readUInt32.
            ^ aBuffer readBytes: len
        ].
        tag = self tagLatticeId ifTrue: [
            | b |
            b := aBuffer readBytes: 16.
            ^ LatticeId fromBytes: b
        ].
        tag = self tagVectorClock ifTrue: [
            | count clock |
            count := aBuffer readUInt32.
            clock := VectorClock new.
            1 to: count do: [ :i |
                | k v |
                k := aBuffer readString.
                v := aBuffer readInt64.
                clock set: k value: v.
            ].
            ^ clock
        ].
        tag = self tagDictionary ifTrue: [
            | count dict |
            count := aBuffer readUInt32.
            dict := Dictionary new.
            1 to: count do: [ :i |
                | k v |
                k := self deserializeFrom: aBuffer.
                v := self deserializeFrom: aBuffer.
                dict at: k put: v.
            ].
            ^ dict
        ].
        tag = self tagCollection ifTrue: [
            | count arr |
            count := aBuffer readUInt32.
            arr := Array new: count.
            1 to: count do: [ :i |
                arr at: i put: (self deserializeFrom: aBuffer).
            ].
            ^ arr
        ].

        SystemExceptions.InvalidArgument signal: 'Unknown serialization tag: ', tag printString
    ]
]
