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

"Load Cluster Subsystem"
FileStream fileIn: 'src/Cluster/HashRing.st'.
FileStream fileIn: 'src/Cluster/SWIMMembership.st'.
FileStream fileIn: 'src/Cluster/ClusterNode.st'.

"Load Tests"
FileStream fileIn: 'tests/Unit/KernelTest.st'.
FileStream fileIn: 'tests/Unit/WireTest.st'.
FileStream fileIn: 'tests/Unit/ClusterTest.st'.

"Execute Tests"
KernelTest runAll.
WireTest runAll.
ClusterTest runAll.
