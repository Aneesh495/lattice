"=============================================================================
 Capability: Object-Capability Authorization Token (CapTP Model)
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: Capability [
    | capId resource operations issuedAt expiresAt parentId isRevoked |

    Capability class >> forResource: aResource operations: anArray [
        "Create an unattenuated root capability for the given resource."
        ^ self forResource: aResource
               operations: anArray
               expiresAt: nil
               parent: nil
    ]

    Capability class >> forResource: aResource operations: anArray ttlMilliseconds: ttl [
        "Create a capability with a specified time-to-live in milliseconds."
        | expiry |
        expiry := ttl ifNil: [ nil ] ifNotNil: [
            (Time millisecondClockValue) + ttl
        ].
        ^ self forResource: aResource
               operations: anArray
               expiresAt: expiry
               parent: nil
    ]

    Capability class >> forResource: aResource operations: anArray expiresAt: expiry parent: aParentId [
        ^ (self new) initializeResource: aResource
                     operations: anArray
                     expiresAt: expiry
                     parent: aParentId
    ]

    initializeResource: aResource operations: anArray expiresAt: anExpiry parent: aParentId [
        capId := LatticeId generate.
        resource := aResource asString.
        operations := Set new.
        anArray do: [ :op | operations add: op asString ].
        issuedAt := Time millisecondClockValue.
        expiresAt := anExpiry.
        parentId := aParentId.
        isRevoked := false.
        ^ self
    ]

    id [
        ^ capId
    ]

    resource [
        ^ resource
    ]

    operations [
        ^ operations copy
    ]

    issuedAt [
        ^ issuedAt
    ]

    expiresAt [
        ^ expiresAt
    ]

    parentId [
        ^ parentId
    ]

    isRevoked [
        ^ isRevoked
    ]

    revoke [
        isRevoked := true.
        ^ self
    ]

    isExpiredAt: nowMs [
        expiresAt ifNil: [ ^ false ].
        ^ nowMs >= expiresAt
    ]

    isExpired [
        ^ self isExpiredAt: Time millisecondClockValue
    ]

    isValidFor: anOperation on: aResource at: nowMs [
        "Verify capability validity: not revoked, target resource matches,
         not expired, and requested operation is explicitly permitted."
        isRevoked ifTrue: [ ^ false ].
        (self isExpiredAt: nowMs) ifTrue: [ ^ false ].
        (resource = aResource asString) ifFalse: [ ^ false ].
        ^ operations includes: anOperation asString
    ]

    isValidFor: anOperation on: aResource [
        ^ self isValidFor: anOperation on: aResource at: Time millisecondClockValue
    ]

    attenuate: subOperations [
        "Produce a restricted child capability. The child's operations must be
         a strict or non-strict subset of this capability's allowed operations."
        subOperations do: [ :op |
            (operations includes: op asString) ifFalse: [
                SystemExceptions.InvalidArgument signal: 'Cannot grant unheld permission: ', op asString
            ].
        ].
        ^ Capability forResource: resource
                     operations: subOperations
                     expiresAt: expiresAt
                     parent: capId
    ]

    printOn: aStream [
        aStream nextPutAll: 'Capability(';
                nextPutAll: resource;
                nextPutAll: ', ops=';
                nextPutAll: operations printString;
                nextPut: $)
    ]
]
