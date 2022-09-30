"=============================================================================
 LatticeBenchmark: Comprehensive Latency and Throughput Microbenchmark Suite
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: BenchmarkGrain [
    | counter |
    onActivate [ counter := 0. ]
    inc [ counter := counter + 1. ^ counter. ]
]

Object subclass: LatticeBenchmark [

    LatticeBenchmark class >> runAll [
        Transcript show: '============================================================='; cr.
        Transcript show: ' Lattice High-Performance Microbenchmark Suite              '; cr.
        Transcript show: '============================================================='; cr.

        self benchHashRingLookup.
        self benchWireFramingAndCrc.
        self benchVirtualActorTurnExecution.
        self benchWalSegmentAppend.

        Transcript show: '============================================================='; cr.
        Transcript show: ' Benchmarks Complete                                        '; cr.
        Transcript show: '============================================================='; cr.
    ]

    LatticeBenchmark class >> benchHashRingLookup [
        | ring iterations startMs durationMs opsPerSec |
        ring := HashRing virtualNodes: 128.
        1 to: 16 do: [ :i | ring addNode: ('node-' , i printString) ].

        iterations := 50000.
        Transcript show: 'Benchmarking HashRing lookup ('; show: iterations printString; show: ' iterations)...'; cr.

        startMs := Time millisecondClockValue.
        1 to: iterations do: [ :i |
            ring nodeForKey: ('grain/bench/key-' , (i \\ 1000) printString).
        ].
        durationMs := (Time millisecondClockValue - startMs) max: 1.
        opsPerSec := (iterations * 1000) // durationMs.

        Transcript show: '  Time: '; show: durationMs printString; show: ' ms | ';
                   show: opsPerSec printString; show: ' lookups/sec'; cr.
    ]

    LatticeBenchmark class >> benchWireFramingAndCrc [
        | payload iterations startMs durationMs opsPerSec mbPerSec totalBytes |
        payload := 'Lattice Wire Protocol payload turn data with 64 bytes of content' asByteArray.
        iterations := 30000.
        Transcript show: 'Benchmarking LWP Wire Framing and CRC32C ('; show: iterations printString; show: ' frames)...'; cr.

        startMs := Time millisecondClockValue.
        1 to: iterations do: [ :i |
            | frame encoded buf decoded |
            frame := WireFrame opcode: WireFrame opGrainMessage flags: 0 sequenceId: i payload: payload.
            encoded := frame encode.
            buf := ByteBuffer wrap: encoded.
            decoded := WireFrame decodeFrom: buf.
        ].
        durationMs := (Time millisecondClockValue - startMs) max: 1.
        opsPerSec := (iterations * 1000) // durationMs.
        totalBytes := iterations * (24 + payload size).
        mbPerSec := (totalBytes * 1000) // (durationMs * 1048576).

        Transcript show: '  Time: '; show: durationMs printString; show: ' ms | ';
                   show: opsPerSec printString; show: ' frames/sec | ~';
                   show: mbPerSec printString; show: ' MB/sec'; cr.
    ]

    LatticeBenchmark class >> benchVirtualActorTurnExecution [
        | mgr gid ctx disp iterations startMs durationMs turnsPerSec |
        mgr := GrainManager new.
        mgr registerGrainType: #Benchmark class: BenchmarkGrain.
        gid := GrainId type: #Benchmark key: 'bench-1'.
        ctx := mgr getOrCreateGrain: gid.
        disp := GrainDispatcher forContext: ctx.
        disp start.

        iterations := 20000.
        Transcript show: 'Benchmarking Virtual Actor Single-Threaded Turn Execution ('; show: iterations printString; show: ' turns)...'; cr.

        startMs := Time millisecondClockValue.
        1 to: iterations do: [ :i |
            disp dispatchSync: #inc arguments: #().
        ].
        durationMs := (Time millisecondClockValue - startMs) max: 1.
        turnsPerSec := (iterations * 1000) // durationMs.

        Transcript show: '  Time: '; show: durationMs printString; show: ' ms | ';
                   show: turnsPerSec printString; show: ' turns/sec'; cr.

        disp stop.
    ]

    LatticeBenchmark class >> benchWalSegmentAppend [
        | store payload iterations startMs durationMs recsPerSec |
        store := LatticeStore inDirectory: '/tmp/lattice_bench_wal'.
        payload := Dictionary new at: 'metric' put: 42; at: 'status' put: 'ok'; yourself.

        iterations := 10000.
        Transcript show: 'Benchmarking Bitemporal WAL Record Append ('; show: iterations printString; show: ' records)...'; cr.

        startMs := Time millisecondClockValue.
        1 to: iterations do: [ :i |
            store appendEventFor: 'device/sensor-1'
                       eventType: #TelemetryRecorded
                       validTime: i
                         payload: payload.
        ].
        durationMs := (Time millisecondClockValue - startMs) max: 1.
        recsPerSec := (iterations * 1000) // durationMs.

        Transcript show: '  Time: '; show: durationMs printString; show: ' ms | ';
                   show: recsPerSec printString; show: ' records/sec'; cr.

        store close.
    ]
]
