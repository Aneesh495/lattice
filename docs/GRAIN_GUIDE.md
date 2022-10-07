# Lattice Virtual Actor (Grain) Developer Guide

Virtual Actors (called Grains in Lattice) provide an intuitive, high-concurrency programming model that abstracts away physical server locations, thread synchronization, and explicit lifecycle management.

---

## 1. Core Principles

1. **Location Transparency**: Callers reference grains solely by their logical `GrainId` (type and key). Whether a grain resides on the local node or on a remote cluster host, method invocations look identical.
2. **Turn-Based Isolation**: Each grain instance is strictly single-threaded. Messages from its mailbox are processed one turn at a time. Developers write domain logic without acquiring mutexes or locks.
3. **Automatic Lifecycle Management**: Grains are not manually created or destroyed. They are activated into memory upon receiving a message and automatically passivated to disk when idle.
4. **Perpetual Existence**: A grain logically exists forever. If not in memory, its state is rehydrated from the bitemporal event store.

---

## 2. Authoring a Grain

To define a new virtual actor, subclass `LatticeGrain` and implement domain methods:

```smalltalk
LatticeGrain subclass: BankAccountGrain [
    | holder balance currency auditLog |

    onActivate [
        "Called once when grain is loaded into memory."
        balance := 0.
        auditLog := OrderedCollection new.
    ]

    onPassivate [
        "Called before grain is evicted from memory."
        "Flush any pending dirty state checkpoints if needed."
    ]

    openWithHolder: aName currency: aCurrency [
        holder := aName.
        currency := aCurrency.
        ^ self
    ]

    deposit: amount [
        amount <= 0 ifTrue: [
            SystemExceptions.InvalidArgument signal: 'Deposit must be positive'
        ].
        balance := balance + amount.
        auditLog add: (Dictionary new at: 'action' put: 'deposit'; at: 'amount' put: amount; yourself).
        ^ balance
    ]

    withdraw: amount [
        amount > balance ifTrue: [
            SystemExceptions.InvalidState signal: 'Insufficient balance'
        ].
        balance := balance - amount.
        auditLog add: (Dictionary new at: 'action' put: 'withdraw'; at: 'amount' put: amount; yourself).
        ^ balance
    ]

    balance [
        ^ balance
    ]
]
```

---

## 3. Invoking a Grain

### 3.1 Transparent Dynamic Proxies
Because `GrainRef` implements Smalltalk message reflection via `doesNotUnderstand:`, you can invoke methods directly:

```smalltalk
"Retrieve or activate account grain"
accountRef := cluster account: 'user-404'.

"Direct message dispatch"
accountRef openWithHolder: 'Katherine Johnson' currency: 'USD'.
accountRef deposit: 5000.
currentBalance := accountRef balance.
```

### 3.2 Explicit Turn Invocation
You can also dispatch keyword selectors explicitly with argument arrays:

```smalltalk
result := accountRef send: #deposit: withArguments: #(2500).
```

---

## 4. Timers and Durable Reminders

### 4.1 Transient Grain Timers
Grain timers run in-memory while the grain is active. If the grain passivates, the timer stops:

```smalltalk
timer := GrainTimer forContext: self context
                       selector: #heartbeatTick
                       periodMs: 1000.
```

### 4.2 Durable Reminders
Reminders survive node restarts and cluster failovers. If the target grain is passivated when the reminder fires, Lattice activates the grain and delivers the tick:

```smalltalk
reminder := GrainReminder grainId: self id
                             name: 'monthly-maintenance'
                        dueTimeMs: (Time millisecondClockValue + 86400000)
                         periodMs: 86400000
                         selector: #applyMonthlyFee.
```
