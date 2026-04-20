const express = require('express');
const serveIndex = require('serve-index');
const chokidar = require('chokidar');
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = 8080;
const STRATEGY_DIR = path.resolve(__dirname, '..', '..', '..');

// REBUILD Watcher (monitoring entities and gardener/entities for auto-indexing)
const monitor = chokidar.watch([
  path.join(STRATEGY_DIR, 'entities'),
  path.join(STRATEGY_DIR, 'tools', 'gardener', 'entities')
], {
  ignored: /(^|[\/\\])\..|(index\.md$)/,
  ignoreInitial: true
});

let rebuildTimeout = null;
let isBuilding = false;
let buildPending = false;

function triggerBuild() {
  if (isBuilding) {
    buildPending = true;
    return;
  }
  isBuilding = true;
  console.log(`[Auto-Rebuild] Executing build-index.ps1...`);
  // Note: Assuming the build-index script is updated to handle the root
  exec(`pwsh -File "${path.join(STRATEGY_DIR, 'tools', 'gardener', 'scripts', 'build-index.ps1')}"`, (error, stdout, stderr) => {
    isBuilding = false;
    if (error) console.error(`[Auto-Rebuild] Error: ${error.message}`);
    if (buildPending) {
      buildPending = false;
      rebuildTimeout = setTimeout(triggerBuild, 2000);
    }
  });
}

monitor.on('all', (event, filename) => {
  console.log(`[Auto-Rebuild Triggered] ${event}: ${filename}`);
  if (rebuildTimeout) clearTimeout(rebuildTimeout);
  rebuildTimeout = setTimeout(triggerBuild, 2000);
});

// File Browsing (Strategy Root)
app.use('/', express.static(STRATEGY_DIR, { dotfiles: 'allow' }), serveIndex(STRATEGY_DIR, { 
    icons: true, 
    view: 'details',
    hidden: true,
    template: path.join(__dirname, 'template.html'),
    filter: (filename, index, files, dir) => {
        return filename !== 'ag-stop-probe.json';
    }
}));

app.listen(PORT, '0.0.0.0', () => {
    console.log(`--- Strategy Garden Explorer ---`);
    console.log(`Port: ${PORT}`);
    console.log(`Path: ${STRATEGY_DIR}`);
});

