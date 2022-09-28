"=============================================================================
 Lattice Fault-Injection & Stress Test Suite Runner
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

"Load Stress Tests"
FileStream fileIn: 'tests/Stress/FaultInjectionTest.st'.

"Execute Stress Tests"
FaultInjectionTest runAll.
