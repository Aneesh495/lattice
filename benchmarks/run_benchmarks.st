"=============================================================================
 Lattice Microbenchmark Suite Runner
============================================================================="

"Load Kernel Subsystem"
FileStream fileIn: 'src/Kernel/LatticeId.st'.
FileStream fileIn: 'src/Kernel/VectorClock.st'.
FileStream fileIn: 'src/Kernel/Capability.st'.
FileStream fileIn: 'src/Kernel/ByteBuffer.st'.
FileStream fileIn: 'src/Kernel/PriorityQueue.st'.
FileStream fileIn: 'src/Kernel/Mailbox.st'.

"Load Wire Subsystem"
FileStream fileIn: 'src/Wire/CRC32C.st'.
FileStream fileIn: 'src/Wire/WireFrame.st'.
FileStream fileIn: 'src/Wire/WireSerializer.st'.

"Load Cluster Subsystem"
FileStream fileIn: 'src/Cluster/HashRing.st'.
FileStream fileIn: 'src/Cluster/SWIMMembership.st'.
FileStream fileIn: 'src/Cluster/ClusterNode.st'.

"Load Actor Subsystem"
FileStream fileIn: 'src/Actor/GrainId.st'.
FileStream fileIn: 'src/Actor/GrainContext.st'.
FileStream fileIn: 'src/Actor/GrainManager.st'.
FileStream fileIn: 'src/Actor/GrainDispatcher.st'.
FileStream fileIn: 'src/Actor/GrainTimer.st'.
FileStream fileIn: 'src/Actor/GrainRef.st'.

"Load Storage Subsystem"
FileStream fileIn: 'src/Storage/WALSegment.st'.
FileStream fileIn: 'src/Storage/BitemporalEvent.st'.
FileStream fileIn: 'src/Storage/BitemporalIndex.st'.
FileStream fileIn: 'src/Storage/SnapshotManager.st'.
FileStream fileIn: 'src/Storage/LatticeStore.st'.

"Load Benchmark Suite"
FileStream fileIn: 'benchmarks/LatticeBenchmark.st'.

"Execute Benchmarks"
LatticeBenchmark runAll.
