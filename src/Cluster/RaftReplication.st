"=============================================================================
 RaftReplication: AppendEntries RPC and Commit Index Convergence Subsystem
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

RaftServer extend [

    handleAppendEntriesTerm: term leaderId: leaderId prevLogIndex: prevIdx prevLogTerm: prevTerm entries: newEntries leaderCommit: leaderCommit [
        "Follower handler for AppendEntries RPC according to Raft section 5.3."
        | success matchIdx |
        lock critical: [
            term > currentTerm ifTrue: [
                self stepDownToTerm: term.
            ].

            "1. Reply false if term < currentTerm"
            term < currentTerm ifTrue: [
                ^ Dictionary new
                    at: 'term' put: currentTerm;
                    at: 'success' put: false;
                    at: 'matchIndex' put: 0;
                    yourself
            ].

            "Recognize leader and stay follower"
            role := #follower.

            "2. Reply false if log does not contain an entry at prevLogIndex matching prevLogTerm"
            prevIdx > 0 ifTrue: [
                (log lastLogIndex < prevIdx) ifTrue: [
                    ^ Dictionary new
                        at: 'term' put: currentTerm;
                        at: 'success' put: false;
                        at: 'matchIndex' put: log lastLogIndex;
                        yourself
                ].
                (log termAt: prevIdx) ~= prevTerm ifTrue: [
                    ^ Dictionary new
                        at: 'term' put: currentTerm;
                        at: 'success' put: false;
                        at: 'matchIndex' put: (prevIdx - 1);
                        yourself
                ].
            ].

            "3. If an existing entry conflicts with a new one, delete existing entry and all that follow"
            newEntries do: [ :entry |
                | existing |
                existing := log entryAt: entry index.
                existing ifNotNil: [
                    existing term ~= entry term ifTrue: [
                        log truncateFromIndex: entry index.
                        log appendEntry: entry.
                    ].
                ] ifNil: [
                    log appendEntry: entry.
                ].
            ].

            "4. Update commit index"
            leaderCommit > commitIndex ifTrue: [
                commitIndex := leaderCommit min: log lastLogIndex.
            ].

            success := true.
            matchIdx := log lastLogIndex.
        ].

        ^ Dictionary new
            at: 'term' put: currentTerm;
            at: 'success' put: success;
            at: 'matchIndex' put: matchIdx;
            yourself
    ]

    advanceLeaderCommitIndex [
        "Leader calculates whether commitIndex can advance based on matchIndex quorum."
        | minIndex maxIndex quorum |
        role = #leader ifFalse: [ ^ self ].
        quorum := self quorumCount.
        minIndex := commitIndex + 1.
        maxIndex := log lastLogIndex.

        minIndex to: maxIndex do: [ :n |
            (log termAt: n) = currentTerm ifTrue: [
                | replicatedCount |
                replicatedCount := 1. "Leader has entry"
                peers do: [ :p |
                    (self matchIndexFor: p) >= n ifTrue: [
                        replicatedCount := replicatedCount + 1.
                    ].
                ].
                replicatedCount >= quorum ifTrue: [
                    commitIndex := n.
                ].
            ].
        ].
        ^ commitIndex
    ]
]
