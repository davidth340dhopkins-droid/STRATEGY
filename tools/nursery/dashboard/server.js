const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const net = require('net');

const app = express();
const PORT = 8081;

app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

const STRATEGY_DIR = path.resolve(__dirname, '..', '..', '..');
const REGISTRY_FILE = path.join(STRATEGY_DIR, 'tools', 'nursery', 'port_registry.json');

// Helper to check if a local port is actively listening
function checkPort(port) {
    return new Promise((resolve) => {
        const socket = new net.Socket();
        socket.setTimeout(200);
        socket.on('connect', () => {
            socket.destroy();
            resolve(true);
        });
        socket.on('timeout', () => {
            socket.destroy();
            resolve(false);
        });
        socket.on('error', () => {
            socket.destroy();
            resolve(false);
        });
        socket.connect(port, '127.0.0.1');
    });
}

app.get('/api/environments', async (req, res) => {
    try {
        if (!fs.existsSync(REGISTRY_FILE)) {
            return res.json([]);
        }

        const registryRaw = fs.readFileSync(REGISTRY_FILE, 'utf8');
        const registry = JSON.parse(registryRaw);
        const environments = [];

        for (const [tierStr, projectPath] of Object.entries(registry)) {
            const tier = parseInt(tierStr, 10);
            
            // Reconstruct the pipeline ports: stable=0, b-test=1, a-test=2, merge=3
            // $tier + '10' etc. In PS it was "${xx}${y}0" where y=1.
            const stablePort = parseInt(`${tier}10`, 10);
            const bTestPort = parseInt(`${tier}11`, 10);
            const aTestPort = parseInt(`${tier}12`, 10);
            const mergePort = parseInt(`${tier}13`, 10);

            const projectName = path.basename(projectPath);

            const [stableUp, bTestUp, aTestUp, mergeUp] = await Promise.all([
                checkPort(stablePort),
                checkPort(bTestPort),
                checkPort(aTestPort),
                checkPort(mergePort)
            ]);

            environments.push({
                tier,
                project: projectName,
                path: projectPath,
                stages: {
                    stable: { port: stablePort, online: stableUp },
                    bTest: { port: bTestPort, online: bTestUp },
                    aTest: { port: aTestPort, online: aTestUp },
                    merge: { port: mergePort, online: mergeUp },
                }
            });
        }

        res.json(environments.sort((a,b) => a.tier - b.tier));
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: e.message });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`--- Nursery Pipeline Dashboard ---`);
    console.log(`Listening on http://localhost:${PORT}`);
});
