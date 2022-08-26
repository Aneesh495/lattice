"=============================================================================
 LatticeTcpTransport: Asynchronous Socket Networking and Memory Transport
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeLoopbackTransport [
    | registeredNodes lock |

    LatticeLoopbackTransport class >> default [
        ^ defaultInstance ifNil: [ defaultInstance := self new ]
    ]

    LatticeLoopbackTransport class >> reset [
        defaultInstance := nil.
    ]

    initialize [
        registeredNodes := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    registerNode: aNodeId handler: aHandlerBlock [
        lock critical: [
            registeredNodes at: aNodeId asString put: aHandlerBlock.
        ].
        ^ self
    ]

    unregisterNode: aNodeId [
        lock critical: [
            registeredNodes removeKey: aNodeId asString ifAbsent: [ nil ].
        ].
        ^ self
    ]

    sendFrame: aWireFrame toNode: aTargetNodeId [
        | handler response |
        lock critical: [
            handler := registeredNodes at: aTargetNodeId asString ifAbsent: [ nil ].
        ].
        handler ifNil: [
            SystemExceptions.NotFound signal: ('Target node unreachable: ' , aTargetNodeId asString)
        ].
        response := handler value: aWireFrame.
        ^ response
    ]
]

Object subclass: LatticeTcpServer [
    | port serverSocket isRunning serverProcess frameHandler lock |

    LatticeTcpServer class >> port: aPort handler: aHandlerBlock [
        ^ (self new) initializePort: aPort handler: aHandlerBlock
    ]

    initializePort: aPort handler: aHandlerBlock [
        port := aPort.
        frameHandler := aHandlerBlock.
        isRunning := false.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    start [
        lock critical: [
            isRunning ifTrue: [ ^ self ].
            isRunning := true.
            [
                PackageLoader fileInPackage: 'Sockets'.
                serverSocket := Sockets.ServerSocket port: port.
                [ isRunning ] whileTrue: [
                    serverSocket waitForConnection.
                    isRunning ifTrue: [
                        | client |
                        client := serverSocket accept: Sockets.StreamSocket.
                        client ifNotNil: [
                            [ self handleClient: client ] fork.
                        ].
                    ].
                ].
            ] on: Error do: [ :ex |
                "Socket lifecycle termination"
            ].
        ] fork.
        ^ self
    ]

    stop [
        lock critical: [
            isRunning := false.
            serverSocket ifNotNil: [
                [ serverSocket close ] on: Error do: [ :ex | nil ].
            ].
        ].
        ^ self
    ]

    handleClient: aSocket [
        [
            | rawBytes buf frame reply replyBytes |
            rawBytes := String new: 4096.
            [ aSocket atEnd not and: [ isRunning ] ] whileTrue: [
                | count |
                count := aSocket nextAvailable: 4096 into: rawBytes startingAt: 1.
                count > 0 ifTrue: [
                    buf := ByteBuffer wrap: (rawBytes copyFrom: 1 to: count) asByteArray.
                    [ buf readableBytes >= 24 ] whileTrue: [
                        frame := [ WireFrame decodeFrom: buf ] on: Error do: [ :ex | nil ].
                        frame ifNotNil: [
                            reply := frameHandler value: frame.
                            reply ifNotNil: [
                                replyBytes := reply encode.
                                aSocket nextPutAll: replyBytes asString.
                                aSocket flush.
                            ].
                        ] ifNil: [
                            buf reset.
                        ].
                    ].
                ].
            ].
            aSocket close.
        ] on: Error do: [ :ex |
            [ aSocket close ] on: Error do: [ :e | nil ].
        ].
    ]
]

Object subclass: LatticeTcpClient [
    | host port socket lock |

    LatticeTcpClient class >> host: aHost port: aPort [
        ^ (self new) initializeHost: aHost port: aPort
    ]

    initializeHost: aHost port: aPort [
        host := aHost asString.
        port := aPort.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    connect [
        PackageLoader fileInPackage: 'Sockets'.
        socket := Sockets.StreamSocket remote: host port: port.
        ^ self
    ]

    sendFrame: aWireFrame [
        | encodedBytes rawBytes count buf reply |
        lock critical: [
            socket ifNil: [ self connect ].
            encodedBytes := aWireFrame encode.
            socket nextPutAll: encodedBytes asString.
            socket flush.

            rawBytes := String new: 4096.
            count := socket nextAvailable: 4096 into: rawBytes startingAt: 1.
            (count < 24) ifTrue: [
                SystemExceptions.InvalidState signal: 'Insufficient response bytes from remote node'
            ].
            buf := ByteBuffer wrap: (rawBytes copyFrom: 1 to: count) asByteArray.
            reply := WireFrame decodeFrom: buf.
        ].
        ^ reply
    ]

    close [
        lock critical: [
            socket ifNotNil: [
                [ socket close ] on: Error do: [ :ex | nil ].
                socket := nil.
            ].
        ].
        ^ self
    ]
]
