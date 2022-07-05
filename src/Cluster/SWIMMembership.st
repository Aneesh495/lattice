"=============================================================================
 SWIMMembership: Scalable Weakly-Consistent Infection-Style Gossip Membership
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: SWIMMember [
    | nodeId address incarnation state lastStateChangeMs |

    SWIMMember class >> id: anId address: anAddress [
        ^ (self new) initializeId: anId address: anAddress
    ]

    initializeId: anId address: anAddress [
        nodeId := anId asString.
        address := anAddress asString.
        incarnation := 0.
        state := #alive.
        lastStateChangeMs := Time millisecondClockValue.
        ^ self
    ]

    nodeId [
        ^ nodeId
    ]

    address [
        ^ address
    ]

    incarnation [
        ^ incarnation
    ]

    incarnation: anInt [
        incarnation := anInt.
        ^ self
    ]

    state [
        ^ state
    ]

    isAlive [
        ^ state = #alive
    ]

    isSuspect [
        ^ state = #suspect
    ]

    isDead [
        ^ state = #dead
    ]

    markAliveWithIncarnation: anIncarnation [
        incarnation := anIncarnation.
        state := #alive.
        lastStateChangeMs := Time millisecondClockValue.
        ^ self
    ]

    markSuspect [
        state := #suspect.
        lastStateChangeMs := Time millisecondClockValue.
        ^ self
    ]

    markDead [
        state := #dead.
        lastStateChangeMs := Time millisecondClockValue.
        ^ self
    ]

    lastStateChangeMs [
        ^ lastStateChangeMs
    ]
]

Object subclass: SWIMMembership [
    | localNodeId localAddress localIncarnation members suspicionTimeoutMs updatesQueue |

    SWIMMembership class >> localId: anId address: anAddr [
        ^ (self new) initializeLocalId: anId address: anAddr
    ]

    initializeLocalId: anId address: anAddr [
        localNodeId := anId asString.
        localAddress := anAddr asString.
        localIncarnation := 0.
        members := Dictionary new.
        suspicionTimeoutMs := 2000.
        updatesQueue := OrderedCollection new.

        "Add self as first alive member"
        self addMember: (SWIMMember id: localNodeId address: localAddress).
        ^ self
    ]

    localNodeId [
        ^ localNodeId
    ]

    localIncarnation [
        ^ localIncarnation
    ]

    addMember: aMember [
        members at: aMember nodeId put: aMember.
        ^ self
    ]

    member: aNodeId [
        ^ members at: aNodeId asString ifAbsent: [ nil ]
    ]

    aliveMembers [
        | list |
        list := OrderedCollection new.
        members do: [ :m |
            m isAlive ifTrue: [ list add: m ].
        ].
        ^ list
    ]

    aliveNodesExcludingSelf [
        | list |
        list := OrderedCollection new.
        members do: [ :m |
            (m isAlive and: [ m nodeId ~= localNodeId ]) ifTrue: [ list add: m ].
        ].
        ^ list
    ]

    "-------------------------------------------------------------------------
     Gossip Message Processing and Refutation
    -------------------------------------------------------------------------"

    handleAliveMessageFor: aNodeId address: anAddr incarnation: remoteInc [
        | member |
        aNodeId asString = localNodeId ifTrue: [
            "If another node claims an alive state for self with higher incarnation,
             refute by bumping local incarnation"
            remoteInc >= localIncarnation ifTrue: [
                localIncarnation := remoteInc + 1.
            ].
            ^ self
        ].

        member := self member: aNodeId.
        member ifNil: [
            member := SWIMMember id: aNodeId address: anAddr.
            member markAliveWithIncarnation: remoteInc.
            self addMember: member.
            updatesQueue add: member.
            ^ self
        ].

        "Update state if remote incarnation is higher or overrides suspect state"
        (remoteInc > member incarnation or: [ (remoteInc = member incarnation) and: [ member isSuspect ] ]) ifTrue: [
            member markAliveWithIncarnation: remoteInc.
            updatesQueue add: member.
        ].
        ^ self
    ]

    handleSuspectMessageFor: aNodeId incarnation: remoteInc [
        | member |
        aNodeId asString = localNodeId ifTrue: [
            "Suspicion refutation: if local node is suspected, bump incarnation and broadcast alive"
            remoteInc >= localIncarnation ifTrue: [
                localIncarnation := remoteInc + 1.
                member := self member: localNodeId.
                member markAliveWithIncarnation: localIncarnation.
                updatesQueue add: member.
            ].
            ^ self
        ].

        member := self member: aNodeId.
        member ifNotNil: [
            (remoteInc >= member incarnation and: [ member isAlive ]) ifTrue: [
                member incarnation: remoteInc.
                member markSuspect.
                updatesQueue add: member.
            ].
        ].
        ^ self
    ]

    handleDeadMessageFor: aNodeId incarnation: remoteInc [
        | member |
        aNodeId asString = localNodeId ifTrue: [
            "Cannot mark self dead; refute immediately"
            localIncarnation := remoteInc + 1.
            ^ self
        ].

        member := self member: aNodeId.
        member ifNotNil: [
            remoteInc >= member incarnation ifTrue: [
                member incarnation: remoteInc.
                member markDead.
                updatesQueue add: member.
            ].
        ].
        ^ self
    ]

    checkSuspicionTimeouts: nowMs [
        "Expire suspect nodes to dead when suspicionTimeoutMs has elapsed."
        members do: [ :m |
            (m isSuspect and: [ (nowMs - m lastStateChangeMs) >= suspicionTimeoutMs ]) ifTrue: [
                m markDead.
                updatesQueue add: m.
            ].
        ].
        ^ self
    ]

    popPendingUpdates: maxCount [
        "Drain updates to piggyback onto outgoing SWIM pings/acks."
        | batch count |
        batch := OrderedCollection new.
        count := maxCount min: updatesQueue size.
        1 to: count do: [ :i |
            batch add: (updatesQueue removeFirst).
        ].
        ^ batch
    ]
]
