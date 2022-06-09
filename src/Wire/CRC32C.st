"=============================================================================
 CRC32C: Castagnoli 32-bit Cyclic Redundancy Check (Polynomial 0x1EDC6F41)
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: CRC32C [
    CRC32C class [
        | table |

        initializeTable [
            "Initialize 256-entry table for Castagnoli polynomial 0x82F63B78 (reflected)."
            | poly |
            poly := 16r82F63B78.
            table := Array new: 256.
            0 to: 255 do: [ :i |
                | crc |
                crc := i.
                1 to: 8 do: [ :j |
                    (crc bitAnd: 1) = 1 ifTrue: [
                        crc := (crc bitShift: -1) bitXor: poly.
                    ] ifFalse: [
                        crc := crc bitShift: -1.
                    ].
                ].
                table at: i + 1 put: (crc bitAnd: 16rFFFFFFFF).
            ].
        ]

        table [
            table ifNil: [ self initializeTable ].
            ^ table
        ]

        checksum: aByteArray [
            "Calculate 32-bit CRC32C over aByteArray with initial 0xFFFFFFFF and final invert."
            | crc |
            crc := self update: 16rFFFFFFFF with: aByteArray from: 1 to: aByteArray size.
            ^ crc bitXor: 16rFFFFFFFF
        ]

        update: prevCrc with: aByteArray from: start to: stop [
            | crc tbl |
            tbl := self table.
            crc := prevCrc.
            start to: stop do: [ :i |
                | b tableIdx |
                b := aByteArray at: i.
                tableIdx := ((crc bitXor: b) bitAnd: 16rFF) + 1.
                crc := (crc bitShift: -8) bitXor: (tbl at: tableIdx).
                crc := crc bitAnd: 16rFFFFFFFF.
            ].
            ^ crc
        ]
    ]
]
