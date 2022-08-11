"=============================================================================
 Lattice Unit Test Suite Runner
============================================================================="

"Load Test Framework"
FileStream fileIn: 'tests/LatticeTestFramework.st'.

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

"Load Cluster & Consensus Subsystem"
FileStream fileIn: 'src/Cluster/HashRing.st'.
FileStream fileIn: 'src/Cluster/SWIMMembership.st'.
FileStream fileIn: 'src/Cluster/ClusterNode.st'.
FileStream fileIn: 'src/Cluster/RaftLog.st'.
FileStream fileIn: 'src/Cluster/RaftServer.st'.
FileStream fileIn: 'src/Cluster/RaftReplication.st'.

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

"Load Stream Subsystem"
FileStream fileIn: 'src/Stream/ReactiveStream.st'.
FileStream fileIn: 'src/Stream/DemandController.st'.
FileStream fileIn: 'src/Stream/WindowOperator.st'.
FileStream fileIn: 'src/Stream/WatermarkManager.st'.

"Load Tests"
FileStream fileIn: 'tests/Unit/KernelTest.st'.
FileStream fileIn: 'tests/Unit/WireTest.st'.
FileStream fileIn: 'tests/Unit/ClusterTest.st'.
FileStream fileIn: 'tests/Unit/RaftTest.st'.
FileStream fileIn: 'tests/Unit/ActorTest.st'.
FileStream fileIn: 'tests/Unit/StorageTest.st'.
FileStream fileIn: 'tests/Unit/StreamTest.st'.

"Execute Tests"
KernelTest runAll.
WireTest runAll.
ClusterTest runAll.
RaftTest runAll.
ActorTest runAll.
StorageTest runAll.
StreamTest runAll.
