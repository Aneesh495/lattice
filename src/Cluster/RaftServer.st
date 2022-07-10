"=============================================================================
 RaftServer: Leader Election and Consensus RPC State Machine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: RaftServer [
    | nodeId peers role currentTerm votedFor log commitIndex lastApplied votesGranted nextIndex matchIndex lock |

    RaftServer class >> id: aNodeId peers: peerCollection [
        ^ (self new) initializeId: aNodeId peers: peerCollection
    ]

    initializeId: aNodeId peers: peerCollection [
        nodeId := aNodeId asString.
        peers := OrderedCollection new.
        peerCollection do: [ :p | peers add: p asString ].
        role := #follower.
        currentTerm := 0.
        votedFor := nil.
        log := RaftLog new.
        commitIndex := 0.
        lastApplied := 0.
        votesGranted := Set new.
        nextIndex := Dictionary new.
        matchIndex := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    nodeId [
        ^ nodeId
    ]

    role [
        ^ role
    ]

    isLeader [
        ^ role = #leader
    ]

    isCandidate [
        ^ role = #candidate
    ]

    isFollower [
        ^ role = #follower
    ]

    currentTerm [
        ^ currentTerm
    ]

    votedFor [
        ^ votedFor
    ]

    log [
        ^ log
    ]

    commitIndex [
        ^ commitIndex
    ]

    commitIndex: anIndex [
        commitIndex := anIndex.
        ^ self
    ]

    lastApplied [
        ^ lastApplied
    ]

    lastApplied: anIndex [
        lastApplied := anIndex.
        ^ self
    ]

    clusterSize [
        ^ peers size + 1
    ]

    quorumCount [
        ^ (self clusterSize // 2) + 1
    ]

    stepDownToTerm: aNewTerm [
        currentTerm := aNewTerm.
        role := #follower.
        votedFor := nil.
        votesGranted := Set new.
        ^ self
    ]

    startElection [
        "Transition to candidate, increment term, vote for self, and reset votes set."
        lock critical: [
            role := #candidate.
            currentTerm := currentTerm + 1.
            votedFor := nodeId.
            votesGranted := Set new.
            votesGranted add: nodeId.
        ].
        ^ self
    ]

    recordVoteFrom: aPeerId granted: isGranted [
        lock critical: [
            (role = #candidate and: [ isGranted ]) ifTrue: [
                votesGranted add: aPeerId asString.
                (votesGranted size >= self quorumCount) ifTrue: [
                    self becomeLeader.
                ].
            ].
        ].
        ^ self
    ]

    becomeLeader [
        role := #leader.
        peers do: [ :p |
            nextIndex at: p put: (log lastLogIndex + 1).
            matchIndex at: p put: 0.
        ].
        ^ self
    ]

    handleRequestVoteTerm: term candidateId: candId lastLogIndex: candLastIdx lastLogTerm: candLastTerm [
        "Process RequestVote RPC adhering to Raft election safety invariant."
        | voteGranted myLastIdx myLastTerm logUpToDate |
        lock critical: [
            term > currentTerm ifTrue: [
                self stepDownToTerm: term.
            ].

            voteGranted := false.
            (term = currentTerm and: [ votedFor isNil or: [ votedFor = candId asString ] ]) ifTrue: [
                myLastIdx := log lastLogIndex.
                myLastTerm := log lastLogTerm.

                "Log comparison: candidate term higher, or equal term and at least as long"
                logUpToDate := (candLastTerm > myLastTerm) or: [
                    (candLastTerm = myLastTerm) and: [ candLastIdx >= myLastIdx ]
                ].

                logUpToDate ifTrue: [
                    voteGranted := true.
                    votedFor := candId asString.
                ].
            ].
        ].
        ^ Dictionary new
            at: 'term' put: currentTerm;
            at: 'voteGranted' put: voteGranted;
            yourself
    ]

    nextIndexFor: aPeerId [
        ^ nextIndex at: aPeerId asString ifAbsent: [ 1 ]
    ]

    matchIndexFor: aPeerId [
        ^ matchIndex at: aPeerId asString ifAbsent: [ 0 ]
    ]

    setMatchIndexFor: aPeerId to: anIndex [
        matchIndex at: aPeerId asString put: anIndex.
        nextIndex at: aPeerId asString put: (anIndex + 1).
        ^ self
    ]
]
