"=============================================================================
 RaftLog: Replicated Log Entries and State Machine Invariant Engine
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: RaftLogEntry [
    | index term command txTimestamp |

    RaftLogEntry class >> index: anIndex term: aTerm command: aCommand [
        ^ (self new) initializeIndex: anIndex term: aTerm command: aCommand
    ]

    initializeIndex: anIndex term: aTerm command: aCommand [
        index := anIndex.
        term := aTerm.
        command := aCommand.
        txTimestamp := Time millisecondClockValue.
        ^ self
    ]

    index [
        ^ index
    ]

    term [
        ^ term
    ]

    command [
        ^ command
    ]

    txTimestamp [
        ^ txTimestamp
    ]

    printOn: aStream [
        aStream nextPutAll: 'RaftLogEntry(idx=';
                nextPutAll: index printString;
                nextPutAll: ', term=';
                nextPutAll: term printString;
                nextPutAll: ', cmd=';
                nextPutAll: command printString;
                nextPut: $)
    ]
]

Object subclass: RaftLog [
    | entries |

    RaftLog class >> new [
        ^ (super new) initialize
    ]

    initialize [
        entries := OrderedCollection new.
        ^ self
    ]

    size [
        ^ entries size
    ]

    isEmpty [
        ^ entries isEmpty
    ]

    lastLogIndex [
        entries isEmpty ifTrue: [ ^ 0 ].
        ^ (entries last) index
    ]

    lastLogTerm [
        entries isEmpty ifTrue: [ ^ 0 ].
        ^ (entries last) term
    ]

    entryAt: anIndex [
        (anIndex < 1 or: [ anIndex > entries size ]) ifTrue: [ ^ nil ].
        ^ entries at: anIndex
    ]

    termAt: anIndex [
        anIndex = 0 ifTrue: [ ^ 0 ].
        (anIndex < 1 or: [ anIndex > entries size ]) ifTrue: [ ^ 0 ].
        ^ (entries at: anIndex) term
    ]

    appendEntryWithTerm: aTerm command: aCommand [
        | newIndex entry |
        newIndex := self lastLogIndex + 1.
        entry := RaftLogEntry index: newIndex term: aTerm command: aCommand.
        entries add: entry.
        ^ entry
    ]

    appendEntry: aRaftLogEntry [
        entries add: aRaftLogEntry.
        ^ aRaftLogEntry
    ]

    truncateFromIndex: anIndex [
        "Delete all entries starting from anIndex onwards. Used when a follower
         detects a conflicting entry during AppendEntries RPC."
        (anIndex > entries size or: [ anIndex < 1 ]) ifTrue: [ ^ self ].
        [ entries size >= anIndex ] whileTrue: [
            entries removeLast.
        ].
        ^ self
    ]

    sliceFrom: startIndex [
        ^ self sliceFrom: startIndex to: entries size
    ]

    sliceFrom: startIndex to: endIndex [
        | slice end |
        slice := OrderedCollection new.
        (startIndex < 1 or: [ startIndex > entries size ]) ifTrue: [ ^ slice ].
        end := endIndex min: entries size.
        startIndex to: end do: [ :i |
            slice add: (entries at: i).
        ].
        ^ slice
    ]
]
