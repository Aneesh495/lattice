"=============================================================================
 ActorTest: Comprehensive Unit Test Suite for Virtual Actor Grains
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: BankAccountGrain [
    | balance accountHolder |

    onActivate [
        balance := 0.
        accountHolder := 'unassigned'.
    ]

    setHolder: aName [
        accountHolder := aName.
        ^ accountHolder
    ]

    deposit: amount [
        balance := balance + amount.
        ^ balance
    ]

    withdraw: amount [
        amount > balance ifTrue: [
            SystemExceptions.InvalidState signal: 'Insufficient funds for withdrawal'
        ].
        balance := balance - amount.
        ^ balance
    ]

    balance [
        ^ balance
    ]
]

LatticeTestCase subclass: ActorTest [

    testGrainIdParsingAndFormatting [
        | gid str gid2 |
        gid := GrainId type: #BankAccount key: 'acc-404'.
        self assert: gid grainType equals: #BankAccount.
        self assert: gid key equals: 'acc-404'.

        str := gid asString.
        self assert: str equals: 'BankAccount/acc-404'.

        gid2 := GrainId fromString: str.
        self assert: gid equals: gid2.
        self assert: gid hash equals: gid2 hash.
    ]

    testGrainActivationAndTurnExecution [
        | mgr gid ctx disp b1 b2 |
        mgr := GrainManager new.
        mgr registerGrainType: #BankAccount class: BankAccountGrain.

        gid := GrainId type: #BankAccount key: 'acc-1'.
        self deny: (mgr isActive: gid).

        ctx := mgr getOrCreateGrain: gid.
        self assert: (mgr isActive: gid).
        self assert: ctx isActive.

        disp := GrainDispatcher forContext: ctx.
        disp start.

        b1 := disp dispatchSync: #deposit: arguments: #(100).
        self assert: b1 equals: 100.

        b2 := disp dispatchSync: #deposit: arguments: #(250).
        self assert: b2 equals: 350.

        self assert: (disp dispatchSync: #balance arguments: #()) equals: 350.
        disp stop.
    ]

    testGrainTurnExceptionPropagation [
        | mgr gid ctx disp |
        mgr := GrainManager new.
        mgr registerGrainType: #BankAccount class: BankAccountGrain.

        gid := GrainId type: #BankAccount key: 'acc-2'.
        ctx := mgr getOrCreateGrain: gid.
        disp := GrainDispatcher forContext: ctx.
        disp start.

        disp dispatchSync: #deposit: arguments: #(50).
        self should: [
            disp dispatchSync: #withdraw: arguments: #(200).
        ] raise: SystemExceptions.InvalidState.

        disp stop.
    ]

    testGrainIdlePassivation [
        | mgr gid1 gid2 evicted |
        mgr := GrainManager ttlMilliseconds: 100.
        mgr registerGrainType: #BankAccount class: BankAccountGrain.

        gid1 := GrainId type: #BankAccount key: 'acc-10'.
        gid2 := GrainId type: #BankAccount key: 'acc-20'.

        mgr getOrCreateGrain: gid1.
        mgr getOrCreateGrain: gid2.
        self assert: mgr activeCount equals: 2.

        "Simulate aging by checking with advanced timestamp"
        evicted := mgr passivateIdleGrainsOlderThan: 0.
        self assert: evicted equals: 2.
        self assert: mgr activeCount equals: 0.
    ]

    testGrainReminderAdvancement [
        | gid rem now |
        gid := GrainId type: #BankAccount key: 'acc-periodic'.
        now := 10000.
        rem := GrainReminder grainId: gid
                                name: 'monthly-audit'
                           dueTimeMs: 12000
                            periodMs: 5000
                            selector: #performAudit.

        self deny: (rem shouldFireAt: 11000).
        self assert: (rem shouldFireAt: 12000).
        self assert: (rem shouldFireAt: 13000).

        rem advanceNextDueTime: 12500.
        self assert: rem dueTimeMs equals: 17500.
        self deny: (rem shouldFireAt: 15000).
        self assert: (rem shouldFireAt: 17500).
    ]
]
