"=============================================================================
 SchemaMigration: Live Object Graph Evolution and Versioned Schema Transforms
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: SchemaMigration [
    | targetClass fromVersion toVersion migrationBlock |

    SchemaMigration class >> class: aClass from: fromV to: toV using: aBlock [
        ^ (self new) initializeClass: aClass from: fromV to: toV using: aBlock
    ]

    initializeClass: aClass from: fromV to: toV using: aBlock [
        targetClass := aClass asSymbol.
        fromVersion := fromV.
        toVersion := toV.
        migrationBlock := aBlock.
        ^ self
    ]

    targetClass [
        ^ targetClass
    ]

    fromVersion [
        ^ fromVersion
    ]

    toVersion [
        ^ toVersion
    ]

    applyTo: aStateDictionary [
        ^ migrationBlock value: aStateDictionary copy
    ]
]

Object subclass: SchemaRegistry [
    | migrations lock |

    SchemaRegistry class >> new [
        ^ (super new) initialize
    ]

    initialize [
        migrations := Dictionary new.
        lock := Semaphore forMutualExclusion.
        ^ self
    ]

    registerMigration: aMigration [
        | key |
        key := aMigration targetClass asString , ':' , aMigration fromVersion printString.
        lock critical: [
            migrations at: key put: aMigration.
        ].
        ^ self
    ]

    migrateState: aState fromVersion: fromV toVersion: toV forClass: aClass [
        "Sequentially apply migrations from fromVersion step-by-step up to toVersion."
        | currentV currentState |
        currentV := fromV.
        currentState := aState copy.

        [ currentV < toV ] whileTrue: [
            | key mig |
            key := aClass asString , ':' , currentV printString.
            lock critical: [
                mig := migrations at: key ifAbsent: [ nil ].
            ].
            mig ifNil: [
                SystemExceptions.NotFound signal: ('No schema migration path from v' , currentV printString , ' for ' , aClass asString)
            ].
            currentState := mig applyTo: currentState.
            currentV := mig toVersion.
        ].

        ^ currentState
    ]
]
