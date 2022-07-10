"=============================================================================
 RaftTest: Comprehensive Unit Test Suite for Raft Consensus State Machine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeTestCase subclass: RaftTest [

    testLeaderElectionAndQuorum [
        | s1 s2 s3 r2 r3 |
        s1 := RaftServer id: 'node1' peers: #('node2' 'node3').
        s2 := RaftServer id: 'node2' peers: #('node1' 'node3').
        s3 := RaftServer id: 'node3' peers: #('node1' 'node2').

        s1 startElection.
        self assert: s1 isCandidate.
        self assert: s1 currentTerm equals: 1.
        self assert: s1 votedFor equals: 'node1'.

        "Request votes from s2 and s3"
        r2 := s2 handleRequestVoteTerm: 1 candidateId: 'node1' lastLogIndex: 0 lastLogTerm: 0.
        r3 := s3 handleRequestVoteTerm: 1 candidateId: 'node1' lastLogIndex: 0 lastLogTerm: 0.

        self assert: (r2 at: 'voteGranted').
        self assert: (r3 at: 'voteGranted').

        s1 recordVoteFrom: 'node2' granted: (r2 at: 'voteGranted').
        self assert: s1 isLeader.
        self assert: (s1 nextIndexFor: 'node2') equals: 1.
    ]

    testVoteRestrictionDoubleVoteRejected [
        | s resp1 resp2 |
        s := RaftServer id: 'node2' peers: #('node1' 'node3').

        resp1 := s handleRequestVoteTerm: 1 candidateId: 'node1' lastLogIndex: 0 lastLogTerm: 0.
        self assert: (resp1 at: 'voteGranted').
        self assert: s votedFor equals: 'node1'.

        "Node3 requests vote for the same term"
        resp2 := s handleRequestVoteTerm: 1 candidateId: 'node3' lastLogIndex: 0 lastLogTerm: 0.
        self deny: (resp2 at: 'voteGranted').
        self assert: s votedFor equals: 'node1'.
    ]

    testLogUpToDateSafetyCheck [
        | s resp |
        s := RaftServer id: 'node2' peers: #('node1').
        s log appendEntryWithTerm: 2 command: 'entry1'.
        s log appendEntryWithTerm: 2 command: 'entry2'.

        "Candidate has term 2 but only 1 entry; must be rejected"
        resp := s handleRequestVoteTerm: 3 candidateId: 'node1' lastLogIndex: 1 lastLogTerm: 2.
        self deny: (resp at: 'voteGranted').

        "Candidate has term 2 and 2 entries; must be accepted"
        resp := s handleRequestVoteTerm: 4 candidateId: 'node1' lastLogIndex: 2 lastLogTerm: 2.
        self assert: (resp at: 'voteGranted').
    ]

    testAppendEntriesLogReplicationAndConflictTruncation [
        | s entries1 entries2 reply1 reply2 |
        s := RaftServer id: 'follower1' peers: #('leader').

        "Append entries at term 1"
        entries1 := OrderedCollection new.
        entries1 add: (RaftLogEntry index: 1 term: 1 command: 'set A').
        entries1 add: (RaftLogEntry index: 2 term: 1 command: 'set B').

        reply1 := s handleAppendEntriesTerm: 1
                                   leaderId: 'leader'
                               prevLogIndex: 0
                                prevLogTerm: 0
                                    entries: entries1
                               leaderCommit: 2.

        self assert: (reply1 at: 'success').
        self assert: s log size equals: 2.
        self assert: s commitIndex equals: 2.

        "Conflict: new leader at term 2 overrides index 2"
        entries2 := OrderedCollection new.
        entries2 add: (RaftLogEntry index: 2 term: 2 command: 'set B_new').

        reply2 := s handleAppendEntriesTerm: 2
                                   leaderId: 'newLeader'
                               prevLogIndex: 1
                                prevLogTerm: 1
                                    entries: entries2
                               leaderCommit: 2.

        self assert: (reply2 at: 'success').
        self assert: s log size equals: 2.
        self assert: (s log entryAt: 2) term equals: 2.
        self assert: (s log entryAt: 2) command equals: 'set B_new'.
    ]
]
