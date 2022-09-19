"=============================================================================
 DeviceTwinGrain: Virtual Actor Digital Twin with Telemetry Windowing
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

LatticeGrain subclass: DeviceTwinGrain [
    | deviceId latitude longitude speed battery alertCount history |

    onActivate [
        deviceId := 'dev-unassigned'.
        latitude := 0.0.
        longitude := 0.0.
        speed := 0.0.
        battery := 100.0.
        alertCount := 0.
        history := OrderedCollection new.
    ]

    recordTelemetryLat: aLat lon: aLon speed: aSpeed battery: aBattery [
        | record isAnomaly |
        latitude := aLat.
        longitude := aLon.
        speed := aSpeed.
        battery := aBattery.

        isAnomaly := false.
        (speed > 35.0 or: [ battery < 15.0 ]) ifTrue: [
            alertCount := alertCount + 1.
            isAnomaly := true.
        ].

        record := Dictionary new
            at: 'lat' put: aLat;
            at: 'lon' put: aLon;
            at: 'speed' put: aSpeed;
            at: 'battery' put: aBattery;
            at: 'anomaly' put: isAnomaly;
            at: 'time' put: Time millisecondClockValue;
            yourself.

        history add: record.
        ^ isAnomaly
    ]

    telemetryHistory [
        ^ history copy
    ]

    alertCount [
        ^ alertCount
    ]

    currentSpeed [
        ^ speed
    ]

    currentBattery [
        ^ battery
    ]
]
