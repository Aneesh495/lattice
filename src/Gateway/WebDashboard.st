"=============================================================================
 WebDashboard: Embedded Interactive Web Inspector and Cluster Visualization
 Part of the Lattice Distributed Virtual Actor Mesh.
 All code conforms strictly to ANSI Smalltalk semantics.
============================================================================="

Object subclass: WebDashboard [

    WebDashboard class >> renderWithCoordinator: aCoord manager: aMgr [
        | localId activeGrains totalMembers html |
        localId := aCoord localNode nodeId.
        activeGrains := aMgr activeCount.
        totalMembers := aCoord membership aliveMembers size.

        html := '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Lattice :: Virtual Actor Mesh Dashboard</title>
    <style>
        :root {
            --bg-primary: #0f141c;
            --bg-secondary: #1a2230;
            --bg-card: #222d3f;
            --text-primary: #e6edf3;
            --text-secondary: #8b949e;
            --accent: #58a6ff;
            --success: #3fb950;
            --border: #30363d;
        }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 18px 32px;
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--border);
        }
        .title {
            font-size: 20px;
            font-weight: 700;
            letter-spacing: 0.5px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .badge {
            background: rgba(63, 185, 80, 0.15);
            color: var(--success);
            border: 1px solid rgba(63, 185, 80, 0.4);
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        .container {
            max-width: 1200px;
            margin: 32px auto;
            padding: 0 24px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 20px;
            margin-bottom: 28px;
        }
        .card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 24px;
        }
        .card-title {
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--text-secondary);
            margin-bottom: 12px;
        }
        .card-value {
            font-size: 36px;
            font-weight: 700;
            color: var(--accent);
        }
        .table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 16px;
        }
        .table th, .table td {
            text-align: left;
            padding: 12px;
            border-bottom: 1px solid var(--border);
            font-size: 14px;
        }
        .table th {
            color: var(--text-secondary);
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="title">
            <span>LATTICE</span>
            <span class="badge">ONLINE</span>
        </div>
        <div>
            <span>Local Node: <strong>' , localId , '</strong></span>
        </div>
    </div>
    <div class="container">
        <div class="grid">
            <div class="card">
                <div class="card-title">Active Virtual Grains</div>
                <div class="card-value">' , activeGrains printString , '</div>
            </div>
            <div class="card">
                <div class="card-title">Cluster Membership</div>
                <div class="card-value">' , totalMembers printString , ' Nodes</div>
            </div>
            <div class="card">
                <div class="card-title">Consistent Hash Vnodes</div>
                <div class="card-value">' , aCoord hashRing totalVnodes printString , '</div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">SWIM Gossip Member Topology</div>
            <table class="table">
                <thead>
                    <tr>
                        <th>Node Identifier</th>
                        <th>Network Address</th>
                        <th>Gossip Status</th>
                        <th>Incarnation</th>
                    </tr>
                </thead>
                <tbody>'.

        aCoord membership aliveMembers do: [ :m |
            html := html , '<tr>
                <td><strong>' , m nodeId , '</strong></td>
                <td>' , m address , '</td>
                <td><span class="badge">' , m state asString asUppercase , '</span></td>
                <td>' , m incarnation printString , '</td>
            </tr>'.
        ].

        html := html , '</tbody>
            </table>
        </div>
    </div>
</body>
</html>'.
        ^ html
    ]
]
