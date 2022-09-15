"=============================================================================
 Run Distributed Financial Ledger Example Application
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

"Load Kernel & Subsystems"
FileStream fileIn: 'src/Kernel/LatticeId.st'.
FileStream fileIn: 'src/Kernel/VectorClock.st'.
FileStream fileIn: 'src/Kernel/Capability.st'.
FileStream fileIn: 'src/Kernel/ByteBuffer.st'.
FileStream fileIn: 'src/Kernel/PriorityQueue.st'.
FileStream fileIn: 'src/Kernel/Mailbox.st'.
FileStream fileIn: 'src/Wire/CRC32C.st'.
FileStream fileIn: 'src/Wire/WireFrame.st'.
FileStream fileIn: 'src/Wire/WireSerializer.st'.
FileStream fileIn: 'src/Cluster/HashRing.st'.
FileStream fileIn: 'src/Cluster/SWIMMembership.st'.
FileStream fileIn: 'src/Cluster/ClusterNode.st'.
FileStream fileIn: 'src/Cluster/RaftLog.st'.
FileStream fileIn: 'src/Cluster/RaftServer.st'.
FileStream fileIn: 'src/Cluster/RaftReplication.st'.
FileStream fileIn: 'src/Actor/GrainId.st'.
FileStream fileIn: 'src/Actor/GrainContext.st'.
FileStream fileIn: 'src/Actor/GrainManager.st'.
FileStream fileIn: 'src/Actor/GrainDispatcher.st'.
FileStream fileIn: 'src/Actor/GrainTimer.st'.
FileStream fileIn: 'src/Actor/GrainRef.st'.
FileStream fileIn: 'src/Storage/WALSegment.st'.
FileStream fileIn: 'src/Storage/BitemporalEvent.st'.
FileStream fileIn: 'src/Storage/BitemporalIndex.st'.
FileStream fileIn: 'src/Storage/SnapshotManager.st'.
FileStream fileIn: 'src/Storage/LatticeStore.st'.

"Load Application"
FileStream fileIn: 'examples/ledger/AccountGrain.st'.

Transcript show: '============================================================='; cr.
Transcript show: ' Lattice Distributed Financial Ledger Demo                   '; cr.
Transcript show: '============================================================='; cr.

ledger := LedgerApp new.

alice := ledger account: 'alice-001'.
bob := ledger account: 'bob-002'.

alice openWithHolder: 'Alice Chen' currency: 'USD'.
bob openWithHolder: 'Bob Smith' currency: 'USD'.

Transcript show: 'Depositing $10,000 into Alice account...'; cr.
alice deposit: 10000 withRef: 'wire-init-alice'.

Transcript show: 'Depositing $2,500 into Bob account...'; cr.
bob deposit: 2500 withRef: 'wire-init-bob'.

Transcript show: 'Initial Balances:'; cr.
Transcript show: '  Alice: $'; show: alice balance printString; cr.
Transcript show: '  Bob:   $'; show: bob balance printString; cr.

Transcript show: 'Executing $1,500 inter-grain transfer from Alice to Bob...'; cr.
ledger transferFrom: 'alice-001' to: 'bob-002' amount: 1500 ref: 'tx-xfer-901'.

Transcript show: 'Post-Transfer Balances:'; cr.
Transcript show: '  Alice: $'; show: alice balance printString; cr.
Transcript show: '  Bob:   $'; show: bob balance printString; cr.

(alice balance = 8500 and: [ bob balance = 4000 ]) ifTrue: [
    Transcript show: '=> Ledger Transfer Invariants Verified Successfully'; cr.
] ifFalse: [
    Transcript show: '=> Ledger Invariant FAILED'; cr.
    ObjectMemory quit: 1.
].

ledger close.
Transcript show: 'Ledger session closed.'; cr.
