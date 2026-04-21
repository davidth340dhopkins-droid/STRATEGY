const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const net = require('net');

const app = express();
const PORT = 8081;

app.use(cors());
app.use(express.static(path.join(__dirname, 'public'), {
    setHeaders: (res) => res.setHeader('Cache-Control', 'no-store')
}));

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

const { exec } = require('child_process');
const inProgress = new Map();

app.post('/api/environments/kill', express.json(), async (req, res) => {
    const { path: projectPath } = req.body;
    if (!projectPath) return res.status(400).json({ error: "Missing project path" });
    if (inProgress.has(projectPath)) return res.status(429).json({ error: "Action already in progress for this project." });
    
    inProgress.set(projectPath, true);
    const stopScript = path.join(projectPath, '.nurse', 'dist', 'scripts', 'stop-servers.ps1');
    console.log(`[Lifecycle] Killing: ${projectPath}`);
    
    exec(`pwsh -File "${stopScript}"`, (error, stdout, stderr) => {
        inProgress.delete(projectPath);
        if (error) {
            console.error(`[Kill Error]: ${error.message}`);
            return res.status(500).json({ error: error.message });
        }
        res.json({ success: true, output: stdout });
    });
});

app.post('/api/environments/restart', express.json(), async (req, res) => {
    const { path: projectPath } = req.body;
    if (!projectPath) return res.status(400).json({ error: "Missing project path" });
    if (inProgress.has(projectPath)) return res.status(429).json({ error: "Action already in progress for this project." });
    
    inProgress.set(projectPath, true);
    const stopScript = path.join(projectPath, '.nurse', 'dist', 'scripts', 'stop-servers.ps1');
    const startScript = path.join(projectPath, '.nurse', 'dist', 'scripts', 'start-servers.ps1');
    console.log(`[Lifecycle] Restarting: ${projectPath}`);
    
    exec(`pwsh -Command "& '${stopScript}'; Start-Sleep -Seconds 2; & '${startScript}'"`, { timeout: 30000 }, (error, stdout, stderr) => {
        inProgress.delete(projectPath);
        if (error) {
            console.error(`[Restart Error]: ${error.message}`);
            return res.status(500).json({ error: error.message });
        }
        res.json({ success: true, output: stdout });
    });
});

app.post('/api/environments/test-promote', express.json(), async (req, res) => {
    const { path: projectPath } = req.body;
    if (!projectPath) return res.status(400).json({ error: "Missing project path" });

    const testPromoteScript = path.join(projectPath, '.nurse', 'dist', 'scripts', 'test-promote.ps1');
    console.log(`[Test-Promote] Bumping dev version: ${projectPath}`);

    exec(`pwsh -File "${testPromoteScript}"`, { timeout: 15000 }, (error, stdout, stderr) => {
        if (stdout) console.log(`[Test-Promote stdout]: ${stdout}`);
        if (error) {
            console.error(`[Test-Promote Error]: ${error.message}`);
            return res.status(500).json({ error: error.message, detail: stderr || stdout });
        }
        res.json({ success: true, output: stdout });
    });
});

app.post('/api/environments/promote', express.json(), async (req, res) => {
    let { path: projectPath, from, to } = req.body;
    if (!projectPath || !from || !to) return res.status(400).json({ error: "Missing promotion parameters" });

    const promoteKey = `${projectPath}::promote`;
    if (inProgress.has(promoteKey)) return res.status(429).json({ error: "Promotion already in progress." });
    inProgress.set(promoteKey, true);

    // Normalize aliases: 'dev' is the display name, 'merge' is the script name
    if (from === 'dev') from = 'merge';
    if (to   === 'dev') to   = 'merge';

    const promoteScript = path.join(projectPath, '.nurse', 'dist', 'scripts', 'promote.ps1');
    console.log(`[Promote] ${path.basename(projectPath)}: ${from} → ${to}`);
    console.log(`[Promote] Script: ${promoteScript}`);

    exec(`pwsh -File "${promoteScript}" -From "${from}" -To "${to}"`, { timeout: 60000 }, (error, stdout, stderr) => {
        inProgress.delete(promoteKey);
        if (stdout) console.log(`[Promote stdout]: ${stdout}`);
        if (stderr) console.warn(`[Promote stderr]: ${stderr}`);
        if (error) {
            console.error(`[Promote Error]: ${error.message}`);
            return res.status(500).json({ error: error.message, detail: stderr || stdout });
        }
        res.json({ success: true, output: stdout });
    });
});

// Helper to read version file
function readVersion(projectPath, stage, type) {
    // If it's a feature, the stage directories are now flat in projectPath (dev, a-test, b-test)
    // If it's core, they are in projectPath/core/stage
    let stageDir = stage;
    if (stage === 'merge' && type === 'feature') stageDir = 'dev';
    
    const relativePath = type === 'feature' ? path.join('pipeline', 'feature', stageDir) : path.join('pipeline', 'core', stageDir);
    const versionFile = path.join(projectPath, relativePath, 'VERSION');
    
    try {
        if (fs.existsSync(versionFile)) {
            return fs.readFileSync(versionFile, 'utf8').trim();
        }
    } catch (e) {}
    
    // Fallback to project root VERSION if stage-specific not found
    const rootVersion = path.join(projectPath, 'VERSION');
    try {
        if (fs.existsSync(rootVersion)) {
            return fs.readFileSync(rootVersion, 'utf8').trim();
        }
    } catch (e) {}

    return '0.1.0';
}

// Helper to read feature manifest
function readManifest(projectPath) {
    const manifestFile = path.join(projectPath, 'pipeline', 'core', 'merge', 'FEATURES_MERGED.json');
    try {
        if (fs.existsSync(manifestFile)) {
            const raw = fs.readFileSync(manifestFile, 'utf8');
            if (raw.trim()) {
                const data = JSON.parse(raw);
                if (Array.isArray(data)) return data;
                if (data && typeof data === 'object') return [data];
            }
        }
    } catch (e) {
        console.error("Error reading manifest:", e.message);
    }
    return [];
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
            
            const stablePort = parseInt(`${tier}10`, 10);
            const bTestPort = parseInt(`${tier}11`, 10);
            const aTestPort = parseInt(`${tier}12`, 10);
            const mergePort = parseInt(`${tier}13`, 10);

            const projectName = path.basename(projectPath);
            const isFeature = projectPath.toLowerCase().includes(path.sep + 'feature' + path.sep) || projectPath.toLowerCase().endsWith(path.sep + 'feature');
            let parentProject = null;
            
            if (isFeature) {
                const normalized = projectPath.replace(/\\/g, '/');
                const parts = normalized.split('/');
                const featIdx = parts.lastIndexOf('feature');
                if (featIdx > 1) { // pipeline/feature/name -> idx 1 is 'feature'
                    parentProject = parts[featIdx - 2]; // Project Root is 2 above 'feature'
                }
            }

            const [stableUp, bTestUp, aTestUp, mergeUp] = await Promise.all([
                checkPort(stablePort),
                checkPort(bTestPort),
                checkPort(aTestPort),
                checkPort(mergePort)
            ]);

            environments.push({
                tier,
                project: projectName,
                parent: parentProject,
                type: isFeature ? 'feature' : 'core',
                path: projectPath,
                stages: {
                    stable: { port: stablePort, online: stableUp, version: readVersion(projectPath, 'stable', isFeature ? 'feature' : 'core') },
                    bTest: { port: bTestPort, online: bTestUp, version: readVersion(projectPath, 'b-test', isFeature ? 'feature' : 'core') },
                    aTest: { port: aTestPort, online: aTestUp, version: readVersion(projectPath, 'a-test', isFeature ? 'feature' : 'core') },
                    merge: { 
                        port: mergePort, 
                        online: mergeUp, 
                        version: readVersion(projectPath, 'merge', isFeature ? 'feature' : 'core'),
                        manifest: (!isFeature) ? readManifest(projectPath) : []
                    },
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
