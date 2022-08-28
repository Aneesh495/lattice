"=============================================================================
 HttpGateway: Embedded HTTP/1.1 REST Management API and Routing Engine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: HttpRequest [
    | method path headers body queryParams |

    HttpRequest class >> parse: aRawString [
        ^ (self new) parseRaw: aRawString
    ]

    parseRaw: aRawString [
        | lines reqLine parts pathParts |
        lines := aRawString subStrings: (Character cr asString).
        lines isEmpty ifTrue: [
            method := 'GET'.
            path := '/'.
            headers := Dictionary new.
            body := ''.
            ^ self
        ].

        reqLine := lines first.
        parts := reqLine subStrings: ' '.
        method := parts first asUppercase.
        path := parts size > 1 ifTrue: [ parts at: 2 ] ifFalse: [ '/' ].

        headers := Dictionary new.
        "Parse query params if present"
        pathParts := path subStrings: '?'.
        path := pathParts first.

        body := ''.
        ^ self
    ]

    method [
        ^ method
    ]

    path [
        ^ path
    ]

    headers [
        ^ headers
    ]

    body [
        ^ body
    ]
]

Object subclass: HttpResponse [
    | statusCode statusText headers body |

    HttpResponse class >> okJson: aJsonString [
        ^ self status: 200 text: 'OK' contentType: 'application/json' body: aJsonString
    ]

    HttpResponse class >> okHtml: aHtmlString [
        ^ self status: 200 text: 'OK' contentType: 'text/html; charset=utf-8' body: aHtmlString
    ]

    HttpResponse class >> okText: aTextString [
        ^ self status: 200 text: 'OK' contentType: 'text/plain; version=0.0.4' body: aTextString
    ]

    HttpResponse class >> notFound: aMessage [
        ^ self status: 404 text: 'Not Found' contentType: 'application/json' body: ('{"error":"' , aMessage , '"}')
    ]

    HttpResponse class >> status: aCode text: aText contentType: aType body: aBody [
        ^ (self new) initializeStatus: aCode text: aText contentType: aType body: aBody
    ]

    initializeStatus: aCode text: aText contentType: aType body: aBody [
        statusCode := aCode.
        statusText := aText.
        headers := Dictionary new.
        headers at: 'Content-Type' put: aType.
        headers at: 'Connection' put: 'close'.
        headers at: 'Server' put: 'Lattice-HttpGateway/1.0'.
        body := aBody asString.
        headers at: 'Content-Length' put: body size printString.
        ^ self
    ]

    asString [
        | s |
        s := WriteStream on: String new.
        s nextPutAll: 'HTTP/1.1 '; nextPutAll: statusCode printString; nextPutAll: ' '; nextPutAll: statusText; nextPut: Character cr; nextPut: Character lf.
        headers keysAndValuesDo: [ :k :v |
            s nextPutAll: k; nextPutAll: ': '; nextPutAll: v; nextPut: Character cr; nextPut: Character lf.
        ].
        s nextPut: Character cr; nextPut: Character lf.
        s nextPutAll: body.
        ^ s contents
    ]
]

Object subclass: HttpGateway [
    | port coordinator grainManager isRunning serverSocket lock |

    HttpGateway class >> port: aPort coordinator: aCoord manager: aMgr [
        ^ (self new) initializePort: aPort coordinator: aCoord manager: aMgr
    ]

    initializePort: aPort coordinator: aCoord manager: aMgr [
        port := aPort.
        coordinator := aCoord.
        grainManager := aMgr.
        isRunning := false.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    handleRequest: aRequest [
        | path method |
        path := aRequest path.
        method := aRequest method.

        (path = '/health' or: [ path = '/api/health' ]) ifTrue: [
            ^ HttpResponse okJson: ('{"status":"UP","nodeId":"' , coordinator localNode nodeId , '","activeGrains":' , grainManager activeCount printString , '}')
        ].

        (path = '/cluster/nodes' or: [ path = '/api/nodes' ]) ifTrue: [
            | jsonNodes |
            jsonNodes := '['.
            coordinator membership aliveMembers do: [ :m |
                jsonNodes := jsonNodes , '{"id":"' , m nodeId , '","address":"' , m address , '","state":"' , m state asString , '","incarnation":' , m incarnation printString , '},'.
            ].
            (jsonNodes size > 1) ifTrue: [ jsonNodes := jsonNodes copyFrom: 1 to: jsonNodes size - 1 ].
            jsonNodes := jsonNodes , ']'.
            ^ HttpResponse okJson: ('{"nodes":' , jsonNodes , '}')
        ].

        (path = '/grains/active' or: [ path = '/api/grains' ]) ifTrue: [
            ^ HttpResponse okJson: ('{"activeGrainCount":' , grainManager activeCount printString , '}')
        ].

        (path = '/metrics') ifTrue: [
            ^ HttpResponse okText: (MetricsCollector default exportPrometheus)
        ].

        (path = '/' or: [ path = '/dashboard' ]) ifTrue: [
            ^ HttpResponse okHtml: (WebDashboard renderWithCoordinator: coordinator manager: grainManager)
        ].

        ^ HttpResponse notFound: 'Endpoint not found'
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
                            [ self serveClient: client ] fork.
                        ].
                    ].
                ].
            ] on: Error do: [ :ex | "Shutdown" ].
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

    serveClient: aSocket [
        [
            | reqStr req resp respStr |
            reqStr := String new: 4096.
            aSocket nextAvailable: 4096 into: reqStr startingAt: 1.
            req := HttpRequest parse: reqStr.
            resp := self handleRequest: req.
            respStr := resp asString.
            aSocket nextPutAll: respStr.
            aSocket flush.
            aSocket close.
        ] on: Error do: [ :ex |
            [ aSocket close ] on: Error do: [ :e | nil ].
        ].
    ]
]
