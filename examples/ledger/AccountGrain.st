"=============================================================================
 AccountGrain: Virtual Actor Account with Bitemporal Transaction Auditing
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: AccountGrain [
    | holder currency balance isFrozen auditLog store |

    onActivate [
        holder := 'unassigned'.
        currency := 'USD'.
        balance := 0.
        isFrozen := false.
        auditLog := OrderedCollection new.
    ]

    setStore: aStore [
        store := aStore.
    ]

    openWithHolder: aHolder currency: aCurrency [
        holder := aHolder.
        currency := aCurrency.
        self recordEvent: #AccountOpened payload: (Dictionary new at: 'holder' put: aHolder; at: 'currency' put: aCurrency; yourself).
        ^ self
    ]

    deposit: anAmount withRef: aRef [
        anAmount <= 0 ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Deposit amount must be strictly positive'
        ].
        isFrozen ifTrue: [
            SystemExceptions.InvalidState signal: 'Cannot deposit into frozen account'
        ].

        balance := balance + anAmount.
        self recordEvent: #FundsDeposited payload: (Dictionary new at: 'amount' put: anAmount; at: 'ref' put: aRef; at: 'newBalance' put: balance; yourself).
        ^ balance
    ]

    withdraw: anAmount withRef: aRef [
        anAmount <= 0 ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Withdrawal amount must be strictly positive'
        ].
        isFrozen ifTrue: [
            SystemExceptions.InvalidState signal: 'Cannot withdraw from frozen account'
        ].
        anAmount > balance ifTrue: [
            SystemExceptions.InvalidState signal: 'Insufficient funds for withdrawal'
        ].

        balance := balance - anAmount.
        self recordEvent: #FundsWithdrawn payload: (Dictionary new at: 'amount' put: anAmount; at: 'ref' put: aRef; at: 'newBalance' put: balance; yourself).
        ^ balance
    ]

    freeze [
        isFrozen := true.
        self recordEvent: #AccountFrozen payload: Dictionary new.
        ^ self
    ]

    unfreeze [
        isFrozen := false.
        self recordEvent: #AccountUnfrozen payload: Dictionary new.
        ^ self
    ]

    balance [
        ^ balance
    ]

    holder [
        ^ holder
    ]

    currency [
        ^ currency
    ]

    isFrozen [
        ^ isFrozen
    ]

    auditTrail [
        ^ auditLog copy
    ]

    recordEvent: anEventType payload: aPayload [
        | record |
        record := Dictionary new
            at: 'type' put: anEventType;
            at: 'timestamp' put: Time millisecondClockValue;
            at: 'payload' put: aPayload;
            yourself.
        auditLog add: record.

        store ifNotNil: [
            store appendEventFor: grainId asString
                       eventType: anEventType
                       validTime: (record at: 'timestamp')
                         payload: aPayload.
        ].
    ]
]

Object subclass: LedgerApp [
    | coordinator manager store |

    LedgerApp class >> new [
        ^ (super new) initialize
    ]

    initialize [
        | localNode |
        localNode := ClusterNode id: 'ledger-node-1' host: '127.0.0.1' port: 9100.
        coordinator := ClusterCoordinator onNode: localNode.
        manager := GrainManager new.
        manager registerGrainType: #Account class: AccountGrain.
        store := LatticeStore inDirectory: '/tmp/lattice_ledger_demo'.
        ^ self
    ]

    account: anAccountId [
        | gid ctx |
        gid := GrainId type: #Account key: anAccountId asString.
        ctx := manager getOrCreateGrain: gid.
        ctx grainInstance setStore: store.
        ^ GrainRef forGrainId: gid coordinator: coordinator manager: manager
    ]

    transferFrom: fromAccId to: toAccId amount: anAmount ref: aRef [
        "Coordinate inter-account atomic turn execution with compensation on failure."
        | fromRef toRef |
        fromRef := self account: fromAccId.
        toRef := self account: toAccId.

        "Step 1: Debit sender"
        fromRef withdraw: anAmount withRef: (aRef , ':debit').

        "Step 2: Credit receiver (with saga compensation if failed)"
        [
            toRef deposit: anAmount withRef: (aRef , ':credit').
        ] on: Error do: [ :ex |
            "Compensate: refund sender"
            fromRef deposit: anAmount withRef: (aRef , ':refund_compensate').
            ex pass.
        ].

        ^ true
    ]

    close [
        store close.
    ]
]
