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

"Load Tests"
FileStream fileIn: 'tests/Unit/KernelTest.st'.

"Execute Kernel Tests"
KernelTest runAll.
