// Tracks in-progress promotions by projectPath:stage — survives re-renders
const promotingSet = new Set();
const queuedSet = new Set();

document.addEventListener('DOMContentLoaded', () => {
    const grid = document.getElementById('grid');
    const loading = document.getElementById('loading');

    // Map camelCase keys from API to the kebab-case stage names the server expects
    const STAGE_KEY_MAP = {
        stable: 'stable',
        bTest:  'b-test',
        aTest:  'a-test',
        merge:  'merge',   // note: server maps 'dev' -> 'merge' for features
    };

    // Next stage in promotion chain
    const PROMOTE_CHAIN = {
        merge:  'a-test',
        'a-test': 'b-test',
        'b-test': 'stable',
    };

    // --- Error Modal ---
    let errorModal = document.getElementById('error-modal');
    if (!errorModal) {
        errorModal = document.createElement('div');
        errorModal.id = 'error-modal';
        errorModal.innerHTML = `
            <div class="modal-backdrop" onclick="this.parentElement.classList.add('hidden')">
                <div class="modal-box" onclick="event.stopPropagation()">
                    <div class="modal-header">
                        <span class="modal-title">⚠ Error</span>
                        <button class="modal-close" onclick="document.getElementById('error-modal').classList.add('hidden')">✕</button>
                    </div>
                    <pre class="modal-body" id="error-modal-body"></pre>
                    <div class="modal-footer">
                        <button class="modal-copy" onclick="navigator.clipboard.writeText(document.getElementById('error-modal-body').textContent)">Copy</button>
                    </div>
                </div>
            </div>
        `;
        errorModal.className = 'hidden';
        document.body.appendChild(errorModal);
    }

    function showError(msg) {
        document.getElementById('error-modal-body').textContent = msg;
        document.getElementById('error-modal').classList.remove('hidden');
    }

    async function fetchEnvironments() {
        try {
            const res = await fetch('/api/environments');
            if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
            const data = await res.json();
            renderGrid(data);
        } catch (e) {
            grid.innerHTML = `<div class="error">Failed to fetch environments: ${e.message}</div>`;
        } finally {
            loading.classList.add('hidden');
        }
    }

    async function controlEnvironment(action, projectPath, btn) {
        btn.disabled = true;
        const orig = btn.innerHTML;
        btn.innerHTML = action === 'kill' ? '⏹ Killing…' : '↺ Restarting…';
        try {
            const res = await fetch(`/api/environments/${action}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ path: projectPath })
            });
            const data = await res.json();
            if (data.error) throw new Error(data.error);
        } catch (e) {
            showError(`Error during ${action}:\n${e.message}`);
        } finally {
            btn.innerHTML = orig;
            btn.disabled = false;
            setTimeout(fetchEnvironments, 1500);
        }
    }

    async function testPromote(projectPath, btn) {
        btn.disabled = true;
        const orig = btn.innerHTML;
        btn.innerHTML = '⟳ Bumping…';

        const promoKey = `${projectPath}:merge`;
        promotingSet.add(promoKey);
        fetchEnvironments();

        try {
            const res = await fetch('/api/environments/test-promote', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ path: projectPath })
            });
            const data = await res.json();
            if (data.error) throw new Error(data.error + (data.detail ? `\n---\n${data.detail}` : ''));
        } catch (e) {
            showError(`Test-promote failed:\n${e.message}`);
        } finally {
            promotingSet.delete(promoKey);
            btn.innerHTML = orig;
            btn.disabled = false;
            setTimeout(fetchEnvironments, 500);
        }
    }

    function getPromoteChain(from, to, isFeature) {
        if (from === to) return [];
        const chain = [];
        let curr = from;
        let limit = 10;
        
        while (curr && curr !== to && limit-- > 0) {
            let next = PROMOTE_CHAIN[curr];
            // Provide a custom bridge for features (b-test -> merge or core-merge)
            if (isFeature && curr === 'b-test' && (to === 'merge' || to === 'core-merge')) {
                next = to;
            }
            if (!next) break;
            chain.push({ from: curr, to: next });
            curr = next;
        }
        
        // If we found a valid chain, return it
        if (curr === to) return chain;
        
        // Fallback for non-standard paths
        return [{ from: from, to: to }];
    }

    async function promoteEnvironment(projectPath, fromStage, toStage, sourceCard, fromBtn) {
        if (!fromStage || !toStage || fromStage === toStage) return;

        const isFeature = projectPath.toLowerCase().includes('feature');
        const steps = getPromoteChain(fromStage, toStage, isFeature);
        
        // Add all future steps to queued
        for (let i = 1; i < steps.length; i++) {
            queuedSet.add(`${projectPath}:${steps[i].to}`);
        }
        
        for (const step of steps) {
            const promoKey = `${projectPath}:${step.to}`;
            queuedSet.delete(promoKey);
            promotingSet.add(promoKey);
            await fetchEnvironments(); // Update UI to show 'Promoting...'

            console.log(`[Promote] ${projectPath}: ${step.from} → ${step.to}`);

            try {
                let apiTo = step.to;
                if (apiTo === 'core-merge') apiTo = 'merge';

                const res = await fetch('/api/environments/promote', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ path: projectPath, from: step.from, to: apiTo })
                });
                const data = await res.json();
                if (data.error) throw new Error(data.error + (data.detail ? `\n---\n${data.detail}` : ''));
            } catch (e) {
                showError(`Promotion failed (${step.from} → ${step.to}):\n${e.message}`);
                promotingSet.delete(promoKey);
                // Clear any remaining queued items for this chain so they don't hang
                for (let i = steps.indexOf(step) + 1; i < steps.length; i++) {
                    queuedSet.delete(`${projectPath}:${steps[i].to}`);
                }
                setTimeout(fetchEnvironments, 500);
                return; // Stop the chain on failure
            }

            promotingSet.delete(promoKey);
        }
        
        // Final refresh after all sequence steps complete
        setTimeout(fetchEnvironments, 500);
    }

    function createStageBtn(stageKey, stageData, isFeature, projectPath) {
        const scriptStage = STAGE_KEY_MAP[stageKey]; // e.g. 'bTest' -> 'b-test'

        // Feature stable slot → Promote-to-Merge button
        if (isFeature && stageKey === 'stable') {
            const pmKey = `${projectPath}:core-merge`;
            const isP = promotingSet.has(pmKey);
            const isQ = queuedSet.has(pmKey);
            
            return `
                <div class="stage-btn promote-btn ${isP ? 'is-promoting promoting' : ''} ${isQ ? 'is-queued queued' : ''}" data-stage="core-merge" data-promote-path="${projectPath.replace(/\\/g, '\\\\')}" data-from="b-test" data-to="core-merge">
                    <div class="stage-header">
                        <span class="stage-name" style="color: var(--accent-bright);">⇪ PROMOTE</span>
                        <span class="stage-port" style="color: var(--accent);">→ MERGE</span>
                    </div>
                    ${(isP || isQ) ? `
                        <div class="status-indicator online ${isP ? 'promoting' : 'queued'}" style="margin-top: 0.5rem">
                            <div class="dot"></div>
                            <span class="text">${isP ? 'Promoting...' : 'Queued...'}</span>
                        </div>
                    ` : ''}
                </div>
            `;
        }

        const isOnline = stageData?.online;
        const port = stageData?.port;
        const v = stageData?.version || '0.0.0';
        const manifest = stageData?.manifest || [];
        const href = `http://localhost:${port}`;

        let displayName = stageKey === 'bTest' ? 'B-TEST'
                        : stageKey === 'aTest' ? 'A-TEST'
                        : stageKey === 'merge' ? (isFeature ? 'DEV' : 'MERGE')
                        : 'STABLE';

        const displayStage = isFeature && stageKey === 'merge' ? 'dev' : scriptStage;
        
        let nextStage = PROMOTE_CHAIN[scriptStage] || '';
        if (isFeature && scriptStage === 'b-test') {
            nextStage = 'core-merge'; // Override to point back to the Core's root level logic
        }

        const promoKey = `${projectPath}:${scriptStage}`;
        const isPromoting = promotingSet.has(promoKey);
        const isQueued = queuedSet.has(promoKey);

        const stateClass = isPromoting ? 'promoting' : (isQueued ? 'queued' : '');
        const stateText  = isPromoting ? 'Promoting...' : (isQueued ? 'Queued...' : (isOnline ? 'Online' : 'Offline'));

        let manifestHtml = '';
        if (manifest.length > 0) {
            const listItems = manifest.map(f => `<li><span class="manifest-name">${f.name}</span><span class="manifest-version">${f.version}</span></li>`).join('');
            manifestHtml = `<ul class="feature-manifest-list">${listItems}</ul>`;
        }

        return `
            <div class="stage-btn ${isOnline ? 'online' : 'offline'} ${isPromoting ? 'is-promoting' : ''} ${isQueued ? 'is-queued' : ''}"
                 draggable="${isOnline && !isPromoting && !isQueued ? 'true' : 'false'}"
                 data-stage="${scriptStage}"
                 data-display="${displayStage}"
                 data-project="${projectPath}">
                <div class="stage-header">
                    <span class="stage-name">
                        ${displayName}
                        ${isOnline ? `<span class="external-link" title="Open in new tab" onclick="event.stopPropagation(); window.open('${href}', '_blank')">↗</span>` : ''}
                    </span>
                    <span class="stage-port">${isOnline ? `:${port}` : ''}</span>
                </div>
                <div class="stage-version">${v}</div>
                ${manifestHtml}
                <div class="status-indicator ${isOnline ? 'online' : 'offline'} ${stateClass}">
                    <div class="dot"></div>
                    <span class="text">${stateText}</span>
                    ${isOnline && nextStage && !isPromoting && !isQueued ? `<span class="promote-mini" title="Promote to ${nextStage}" data-promote-from="${scriptStage}" data-promote-to="${nextStage}" data-promote-path="${projectPath}" onclick="event.stopPropagation();">⇪</span>` : ''}
                </div>
            </div>
        `;
    }

    let draggedStage = null;
    let draggedPath = null;
    let draggedCardEl = null;

    function renderGrid(environments) {
        grid.innerHTML = '';

        if (environments.length === 0) {
            grid.innerHTML = `<div class="card" style="text-align:center;color:var(--text-muted);grid-column:1/-1;padding:3rem;">No active pipeline environments discovered.</div>`;
            return;
        }

        environments.forEach(env => {
            const card = document.createElement('div');
            card.className = 'card';
            card.dataset.project = env.path;

            const isFeature = env.type === 'feature';
            const displayTitle = isFeature && env.parent
                ? `<span class="parent-title">${env.parent}</span> <span class="separator">/</span> ${env.project}`
                : env.project;

            card.innerHTML = `
                <div class="card-header">
                    <div>
                        <div class="card-title">${displayTitle}</div>
                        <div class="card-path">${env.path}</div>
                    </div>
                    <div class="card-tier">${isFeature ? 'Feature' : 'Core'} #${env.tier}</div>
                </div>
                <div class="stages-grid">
                    ${createStageBtn('stable', env.stages.stable, isFeature, env.path)}
                    ${createStageBtn('bTest',  env.stages.bTest,  isFeature, env.path)}
                    ${createStageBtn('aTest',  env.stages.aTest,  isFeature, env.path)}
                    ${createStageBtn('merge',  env.stages.merge,  isFeature, env.path)}
                </div>
                <div class="card-controls">
                    ${isFeature ? '<button class="btn-control test-promote">▲ Bump Dev</button>' : ''}
                    <button class="btn-control kill">⏹ Kill</button>
                    <button class="btn-control restart">↺ Restart</button>
                </div>
            `;

            // --- Drag & Drop ---
            const stageBtns = card.querySelectorAll('.stage-btn[draggable="true"]');
            stageBtns.forEach(btn => {
                btn.addEventListener('dragstart', (e) => {
                    draggedStage = btn.dataset.stage;
                    draggedPath  = btn.dataset.project;
                    draggedCardEl = card;
                    card.classList.add('dragging');
                    e.dataTransfer.effectAllowed = 'move';
                    e.dataTransfer.setData('text/plain', draggedStage);
                });

                btn.addEventListener('dragend', () => {
                    card.classList.remove('dragging');
                    document.querySelectorAll('.stage-btn').forEach(b => b.classList.remove('drop-target'));
                    draggedStage = null;
                    draggedPath  = null;
                    draggedCardEl = null;
                });
            });

            const allStageBtns = card.querySelectorAll('.stage-btn[data-stage]');
            allStageBtns.forEach(btn => {
                btn.addEventListener('dragover', (e) => {
                    // draggedStage=merge (dev) vs btn.dataset.stage=core-merge (Promote)
                    if (draggedPath === env.path && draggedStage !== btn.dataset.stage) {
                        e.preventDefault();
                        e.dataTransfer.dropEffect = 'move';
                        allStageBtns.forEach(b => b.classList.remove('drop-target'));
                        btn.classList.add('drop-target');
                    }
                });
                btn.addEventListener('dragleave', (e) => {
                    if (!btn.contains(e.relatedTarget)) {
                        btn.classList.remove('drop-target');
                    }
                });
                btn.addEventListener('drop', (e) => {
                    e.preventDefault();
                    btn.classList.remove('drop-target');
                    if (draggedPath === env.path && draggedStage && draggedStage !== btn.dataset.stage) {
                        const fromBtn = card.querySelector(`[data-stage="${draggedStage}"]`);
                        promoteEnvironment(env.path, draggedStage, btn.dataset.stage, card, fromBtn);
                    }
                });
            });

            // Promote-to-Merge button (feature)
            const promoteBtn = card.querySelector('.promote-btn');
            if (promoteBtn) {
                promoteBtn.addEventListener('click', () => {
                    promoteEnvironment(env.path, promoteBtn.dataset.from, promoteBtn.dataset.to, card, promoteBtn);
                });
            }

            // Mini promote buttons
            card.querySelectorAll('.promote-mini').forEach(miniBtn => {
                miniBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const fromBtn = card.querySelector(`[data-stage="${miniBtn.dataset.promoteFrom}"]`);
                    promoteEnvironment(env.path, miniBtn.dataset.promoteFrom, miniBtn.dataset.promoteTo, card, fromBtn);
                });
            });

            // Test-promote button
            const testPromoteBtn = card.querySelector('.test-promote');
            if (testPromoteBtn) {
                testPromoteBtn.addEventListener('click', function() {
                    testPromote(env.path, this);
                });
            }

            card.querySelector('.kill').addEventListener('click', function() {
                controlEnvironment('kill', env.path, this);
            });
            card.querySelector('.restart').addEventListener('click', function() {
                controlEnvironment('restart', env.path, this);
            });

            grid.appendChild(card);
        });
    }

    // Make promoteEnvironment globally accessible for debugging
    window.promoteEnvironment = promoteEnvironment;

    fetchEnvironments();
    setInterval(fetchEnvironments, 5000);
});
