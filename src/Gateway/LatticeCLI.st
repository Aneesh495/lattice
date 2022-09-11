"=============================================================================
 LatticeCLI: Command-Line Dispatcher and Interactive Cluster Controller
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: LatticeCLI [

    LatticeCLI class >> banner [
        Transcript show: '============================================================================='; cr.
        Transcript show: ' Lattice :: Distributed Virtual Actor Mesh & Reactive Object-Graph Database  '; cr.
        Transcript show: ' Smalltalk Core Engine with Native C Acceleration and Raft Consensus         '; cr.
        Transcript show: '============================================================================='; cr.
    ]

    LatticeCLI class >> runWithArgs: anArray [
        | cmd |
        anArray isEmpty ifTrue: [
            self printHelp.
            ^ self
        ].

        cmd := anArray first.
        cmd = 'version' ifTrue: [
            self banner.
            Transcript show: 'Lattice v1.0.0 (ANSI Smalltalk / GNU Smalltalk)'; cr.
            ^ self
        ].

        cmd = 'help' ifTrue: [
            self printHelp.
            ^ self
        ].

        cmd = 'status' ifTrue: [
            self showStatus.
            ^ self
        ].

        cmd = 'test' ifTrue: [
            FileStream fileIn: 'tests/run_unit_tests.st'.
            ^ self
        ].

        cmd = 'bench' ifTrue: [
            FileStream fileIn: 'benchmarks/run_benchmarks.st'.
            ^ self
        ].

        Transcript show: 'Unknown command: '; show: cmd; cr.
        self printHelp.
    ]

    LatticeCLI class >> showStatus [
        | node ring |
        self banner.
        node := ClusterNode id: 'standalone-node-1' host: '127.0.0.1' port: 9000.
        ring := HashRing virtualNodes: 128.
        ring addNode: node nodeId.

        Transcript show: 'Node ID:         '; show: node nodeId; cr.
        Transcript show: 'Listen Address:  '; show: node address; cr.
        Transcript show: 'Consistent Ring: '; show: ring totalVnodes printString; show: ' virtual nodes'; cr.
        Transcript show: 'Gossip Status:   ALIVE (Incarnation 0)'; cr.
        Transcript show: 'Consensus Role:  STANDALONE LEADER (Term 1)'; cr.
    ]

    LatticeCLI class >> printHelp [
        self banner.
        Transcript show: 'Usage: lattice <command> [options]'; cr; cr.
        Transcript show: 'Commands:'; cr.
        Transcript show: '  status       Inspect local node topology and cluster health'; cr.
        Transcript show: '  test         Execute comprehensive automated unit test suite'; cr.
        Transcript show: '  bench        Execute throughput and turn latency microbenchmarks'; cr.
        Transcript show: '  version      Display engine version and runtime metadata'; cr.
        Transcript show: '  help         Display this help documentation'; cr.
    ]
]
