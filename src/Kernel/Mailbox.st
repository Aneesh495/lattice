"=============================================================================
 Mailbox: Concurrent Turn Mailbox with Priority Scheduling and Stashing
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: Mailbox [
    | queue stash lock notifySem isClosed capacity |

    Mailbox class >> new [
        ^ self capacity: 1000
    ]

    Mailbox class >> capacity: maxMessages [
        ^ (super new) initializeCapacity: maxMessages
    ]

    initializeCapacity: maxMessages [
        capacity := maxMessages.
        queue := PriorityQueue new.
        stash := OrderedCollection new.
        lock := Semaphore forMutualExclusion.
        notifySem := Semaphore new.
        isClosed := false.
        ^ self
    ]

    size [
        | s |
        lock critical: [ s := queue size ].
        ^ s
    ]

    isEmpty [
        | empty |
        lock critical: [ empty := queue isEmpty ].
        ^ empty
    ]

    isClosed [
        | closed |
        lock critical: [ closed := isClosed ].
        ^ closed
    ]

    close [
        lock critical: [
            isClosed := true.
            notifySem signal.
        ].
        ^ self
    ]

    enqueue: aMessage [
        ^ self enqueue: aMessage priority: 10
    ]

    enqueue: aMessage priority: aPriority [
        "Enqueue a message with specified priority (e.g., System=100, Normal=10).
         Signals the notification semaphore for waiting worker processes."
        lock critical: [
            isClosed ifTrue: [
                SystemExceptions.InvalidState signal: 'Cannot enqueue message to closed Mailbox'
            ].
            (queue size >= capacity) ifTrue: [
                SystemExceptions.InvalidState signal: 'Mailbox capacity limit exceeded'
            ].
            queue push: aMessage priority: aPriority.
            notifySem signal.
        ].
        ^ self
    ]

    dequeue [
        "Non-blocking dequeue. Returns nil if empty."
        | msg |
        lock critical: [
            msg := queue pop.
        ].
        ^ msg
    ]

    dequeueWait [
        "Blocking dequeue. Waits until a message is available or mailbox is closed."
        | msg |
        [
            lock critical: [
                msg := queue pop.
                (msg isNil and: [ isClosed not ]) ifTrue: [
                    "Wait required outside lock"
                ].
            ].
            (msg notNil or: [ isClosed ]) ifTrue: [ ^ msg ].
            notifySem wait.
        ] repeat.
    ]

    stash: aMessage [
        "Stash a message for deferred replay when actor transitions state."
        lock critical: [
            stash add: aMessage.
        ].
        ^ self
    ]

    unstashAll [
        "Prepend all stashed messages back into the active queue with high priority."
        lock critical: [
            stash do: [ :msg |
                queue push: msg priority: 20.
                notifySem signal.
            ].
            stash := OrderedCollection new.
        ].
        ^ self
    ]

    stashSize [
        | s |
        lock critical: [ s := stash size ].
        ^ s
    ]
]
