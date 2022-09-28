"=============================================================================
 FaultInjectionTest: Jepsen-Style Split-Brain, Network Partition & Churn Suite
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: FaultInjectionTest [

    testSplitBrainPartitionMajorityMaintainsConsensus [
        | majorityServers minorityServers majLeader entry reply allNodes |
        "Cluster of 5 nodes: N1, N2, N3 vs N4, N5"
        majorityServers := OrderedCollection new.
        minorityServers := OrderedCollection new.
        allNodes := #('node-1' 'node-2' 'node-3' 'node-4' 'node-5').

        1 to: 3 do: [ :i |
            | myId otherPeers |
            myId := 'node-' , i printString.
            otherPeers := allNodes copyWithout: myId.
            majorityServers add: (RaftServer id: myId peers: otherPeers).
        ].
        4 to: 5 do: [ :i |
            | myId otherPeers |
            myId := 'node-' , i printString.
            otherPeers := allNodes copyWithout: myId.
            minorityServers add: (RaftServer id: myId peers: otherPeers).
        ].

        "Majority side elects N1"
        majLeader := majorityServers first.
        majLeader startElection.
        majLeader recordVoteFrom: 'node-2' granted: true.
        majLeader recordVoteFrom: 'node-3' granted: true.
        self assert: majLeader isLeader.

        "Leader writes entry and replicates across majority"
        entry := majLeader log appendEntryWithTerm: 1 command: 'set system:online'.
        reply := (majorityServers at: 2) handleAppendEntriesTerm: 1
                                                        leaderId: majLeader nodeId
                                                    prevLogIndex: 0
                                                     prevLogTerm: 0
                                                         entries: (OrderedCollection with: entry)
                                                    leaderCommit: 1.
        self assert: (reply at: 'success').

        majLeader setMatchIndexFor: 'node-2' to: 1.
        majLeader setMatchIndexFor: 'node-3' to: 1.
        majLeader advanceLeaderCommitIndex.
        self assert: majLeader commitIndex equals: 1.

        "Minority side attempts election: only has 2 votes out of 5; must fail to reach quorum of 3"
        (minorityServers first) startElection.
        (minorityServers first) recordVoteFrom: 'node-5' granted: true.
        self deny: (minorityServers first) isLeader.
        self assert: (minorityServers first) isCandidate.
    ]

    testHashRingDynamicChurnStability [
        | ring initialAssignments churnedAssignments movedKeys |
        ring := HashRing virtualNodes: 64.
        1 to: 5 do: [ :i | ring addNode: ('worker-' , i printString) ].

        initialAssignments := Dictionary new.
        1 to: 500 do: [ :k |
            | key target |
            key := 'partition-key-' , k printString.
            target := ring nodeForKey: key.
            initialAssignments at: key put: target.
        ].

        "Add 6th node (consistent hash churn)"
        ring addNode: 'worker-6'.

        churnedAssignments := Dictionary new.
        movedKeys := 0.
        1 to: 500 do: [ :k |
            | key target |
            key := 'partition-key-' , k printString.
            target := ring nodeForKey: key.
            churnedAssignments at: key put: target.
            (target ~= (initialAssignments at: key)) ifTrue: [
                movedKeys := movedKeys + 1.
            ].
        ].

        "Theoretical key movement when moving from N=5 to N=6 is ~1/6 = 16.7% (approx 83 keys).
         Assert bounded movement (must not rebalance all keys like modulo hashing does)"
        self assert: (movedKeys < 200) message: ('Excessive churn: moved ' , movedKeys printString , ' keys').
        self assert: (movedKeys > 30) message: ('Insufficient redistribution: moved ' , movedKeys printString , ' keys').
    ]

    testMailboxHighThroughputTurnQueueBurst [
        | mb total |
        mb := Mailbox capacity: 10000.
        total := 2000.

        "Enqueue 2,000 interleaved messages"
        1 to: total do: [ :i |
            (i \\ 10 = 0) ifTrue: [
                mb enqueue: ('urgent-' , i printString) priority: 100.
            ] ifFalse: [
                mb enqueue: ('normal-' , i printString) priority: 10.
            ].
        ].

        self assert: mb size equals: total.

        "High priority messages must dequeue first"
        1 to: (total // 10) do: [ :i |
            | msg |
            msg := mb dequeue.
            self assert: ((msg copyFrom: 1 to: 6) = 'urgent').
        ].

        "Remaining normal messages follow"
        1 to: (total - (total // 10)) do: [ :i |
            | msg |
            msg := mb dequeue.
            self assert: ((msg copyFrom: 1 to: 6) = 'normal').
        ].

        self assert: mb isEmpty.
    ]
]
