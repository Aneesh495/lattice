"=============================================================================
 Run Real-Time IoT Fleet Digital Twin Example Application
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

"Load Kernel & Subsystems"
FileStream fileIn: 'src/Kernel/LatticeId.st'.
FileStream fileIn: 'src/Kernel/VectorClock.st'.
FileStream fileIn: 'src/Kernel/Capability.st'.
FileStream fileIn: 'src/Kernel/ByteBuffer.st'.
FileStream fileIn: 'src/Kernel/PriorityQueue.st'.
FileStream fileIn: 'src/Kernel/Mailbox.st'.
FileStream fileIn: 'src/Wire/CRC32C.st'.
FileStream fileIn: 'src/Wire/WireFrame.st'.
FileStream fileIn: 'src/Wire/WireSerializer.st'.
FileStream fileIn: 'src/Cluster/HashRing.st'.
FileStream fileIn: 'src/Cluster/SWIMMembership.st'.
FileStream fileIn: 'src/Cluster/ClusterNode.st'.
FileStream fileIn: 'src/Actor/GrainId.st'.
FileStream fileIn: 'src/Actor/GrainContext.st'.
FileStream fileIn: 'src/Actor/GrainManager.st'.
FileStream fileIn: 'src/Actor/GrainDispatcher.st'.
FileStream fileIn: 'src/Actor/GrainTimer.st'.
FileStream fileIn: 'src/Actor/GrainRef.st'.
FileStream fileIn: 'src/Stream/ReactiveStream.st'.
FileStream fileIn: 'src/Stream/DemandController.st'.
FileStream fileIn: 'src/Stream/WindowOperator.st'.
FileStream fileIn: 'src/Stream/WatermarkManager.st'.

"Load IoT Application"
FileStream fileIn: 'examples/iot_fleet/DeviceTwinGrain.st'.

Transcript show: '============================================================='; cr.
Transcript show: ' Lattice IoT Fleet Digital Twin & Stream Windowing Demo      '; cr.
Transcript show: '============================================================='; cr.

node := ClusterNode id: 'fleet-telemetry-1' host: '127.0.0.1' port: 9200.
coord := ClusterCoordinator onNode: node.
mgr := GrainManager new.
mgr registerGrainType: #DeviceTwin class: DeviceTwinGrain.

twin1 := GrainRef forGrainId: (GrainId type: #DeviceTwin key: 'vehicle-alpha') coordinator: coord manager: mgr.
twin2 := GrainRef forGrainId: (GrainId type: #DeviceTwin key: 'vehicle-bravo') coordinator: coord manager: mgr.

"Stream window operator: 2000ms tumbling window aggregating telemetry speeds"
winOp := TumblingWindowOperator ofSize: 2000.

Transcript show: 'Streaming telemetry ingest across fleet virtual grains...'; cr.

"Alpha normal ingest"
a1 := twin1 recordTelemetryLat: 37.7749 lon: -122.4194 speed: 22.5 battery: 95.0.
winOp add: 22.5 atTime: 500.

"Bravo normal ingest"
b1 := twin2 recordTelemetryLat: 40.7128 lon: -74.0060 speed: 18.0 battery: 80.0.
winOp add: 18.0 atTime: 1200.

"Alpha anomaly: overspeed 45.0 m/s"
a2 := twin1 recordTelemetryLat: 37.7750 lon: -122.4190 speed: 45.0 battery: 92.0.
winOp add: 45.0 atTime: 1800.

"Bravo anomaly: critical low battery 10.0%"
b2 := twin2 recordTelemetryLat: 40.7130 lon: -74.0055 speed: 12.0 battery: 10.0.
winOp add: 12.0 atTime: 2500.

Transcript show: 'Inspecting Grain State:'; cr.
Transcript show: '  Alpha Alert Count: '; show: twin1 alertCount printString; cr.
Transcript show: '  Bravo Alert Count: '; show: twin2 alertCount printString; cr.

"Evaluate window aggregation at watermark 2000ms"
results := winOp triggerUpTo: 2000 using: [ :win |
    | sum |
    sum := 0.0.
    win elements do: [ :s | sum := sum + s ].
    sum / win size
].

Transcript show: 'Window [0, 2000ms) Average Speed: '; show: (results first) printString; show: ' m/s'; cr.

(twin1 alertCount = 1 and: [ twin2 alertCount = 1 ]) ifTrue: [
    Transcript show: '=> Telemetry Alerts Verified Successfully'; cr.
] ifFalse: [
    Transcript show: '=> Telemetry Invariant FAILED'; cr.
    ObjectMemory quit: 1.
].
