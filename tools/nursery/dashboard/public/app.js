document.addEventListener('DOMContentLoaded', () => {
    const grid = document.getElementById('grid');
    const loading = document.getElementById('loading');
    const errorEl = document.getElementById('error');

    async function fetchEnvironments() {
        try {
            const res = await fetch('/api/environments');
            if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
            const data = await res.json();
            renderGrid(data);
        } catch (e) {
            showError(e.message);
        }
    }

    function showError(msg) {
        loading.classList.add('hidden');
        errorEl.textContent = `Failed to load registry: ${msg}`;
        errorEl.classList.remove('hidden');
    }

    function createStageBtn(stageName, stageData) {
        const isOnline = stageData.online;
        const href = isOnline ? `http://localhost:${stageData.port}` : '#';
        const target = isOnline ? `target="_blank"` : '';
        
        return `
            <a href="${href}" ${target} class="stage-btn ${isOnline ? 'online' : 'offline'}">
                <div class="stage-header">
                    <span class="stage-name">${stageName.replace('Test', '-Test').toUpperCase()}</span>
                    <span class="stage-port">:${stageData.port}</span>
                </div>
                <div class="status-indicator ${isOnline ? 'online' : 'offline'}">
                    <div class="dot"></div>
                    <span class="text">${isOnline ? 'Online' : 'Offline'}</span>
                </div>
            </a>
        `;
    }

    function renderGrid(environments) {
        loading.classList.add('hidden');
        grid.innerHTML = '';

        if (environments.length === 0) {
            grid.innerHTML = `<div class="card" style="text-align: center; color: var(--text-muted); grid-column: 1 / -1;">No active pipeline environments discovered in registry.</div>`;
            return;
        }

        environments.forEach(env => {
            const card = document.createElement('div');
            card.className = 'card';
            
            card.innerHTML = `
                <div class="card-header">
                    <div>
                        <div class="card-title">${env.project}</div>
                        <div class="card-path">${env.path}</div>
                    </div>
                    <div class="card-tier">Tier #${env.tier}</div>
                </div>
                <div class="stages-grid">
                    ${createStageBtn('stable', env.stages.stable)}
                    ${createStageBtn('bTest', env.stages.bTest)}
                    ${createStageBtn('aTest', env.stages.aTest)}
                    ${createStageBtn('merge', env.stages.merge)}
                </div>
            `;
            grid.appendChild(card);
        });
    }

    // Initial fetch
    fetchEnvironments();
    // Poll every 5 seconds for status updates
    setInterval(fetchEnvironments, 5000);
});
