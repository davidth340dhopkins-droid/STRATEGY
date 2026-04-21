# Strategy Garden

This repository is a system for managing and scaling projects with the assistance of AI. It contains a structured lifecycle for transforming raw data and ideas into valuable products, and projects are gathered together into a single repository accessible by AI.

**Caution:** This repository is a work-in-progress and any included documentation may not accurately reflect its current state.

---

## **Table of Contents**
- [Rationale & Philosophy](#rationale--philosophy)
- [The Strategy Matrix (Index)](#the-strategy-matrix-index)
- [Step-by-Step Instructions (The Lifecycle)](#step-by-step-instructions-the-lifecycle)
- [The Pipeline Architecture](#the-pipeline-architecture)
- [Governance & Templates](#governance--templates)

---

## **Rationale & Philosophy**

### **The Role of AI**
Artificial intelligence is a powerful technology for achieving one's goals. It has strengths and weaknesses — which are complemented by human intelligence — and the best results may always be achieved by applying both forms of intelligence together.

Artificial intelligence:
- Is a specialist and not a generalist.
- Learns slowly and periodically (rather than continuously).
- Produces work that is "high-volume" (but "low-signal").

Optimal AI-assisted work tends to progress "radially" rather than "linearly," focusing on "process-oriented" scaling rather than one-off outcomes. This **Strategy Garden** is fashioned to build and discover the optimal project development process to incorporate the latest agentic tools whilst advancing the projects themselves.

### **Parallelism & Scaling**
A productive AI-assisted workflow involves multiple parallel attempts and frequent testing gates. Once an objective is abstracted into a series of steps, the human selects the best attempt, or modifies the process, or both. Because AI operates in the digital realm, process design is more valuable, as any result of a process can be multiplied and scaled rapidly.

---

## **The Strategy Matrix (Index)**

This section provides an index of the major components and directories of the Strategy Garden repository.

### **1. Input (Compost)**
- **[`compost/`](./compost/)** — A dumping site for raw, unfiltered data.
- **[`compost/bin/`](./compost/bin/)** — Legacy or outside-source content signifying non-applicability to the current environment.

### **2. Development (Entities)**
- **[`entities/`](./entities/)** — The active development site.
- **[`entities/seeds/`](./entities/seeds/)** — Document-based projects awaiting formalization.
- **[`entities/sprouts/`](./entities/sprouts/)** — Mature projects with dedicated DevOps pipelines.
- **[`glossary.md`](./entities/glossary.md)** — Centralized definitions and potential brand identities.

### **3. Automation (Tools)**
- **[`tools/`](./tools/)** — Management systems.
- **[`tools/gardener/`](./tools/gardener/)** — Template systems and indexing scripts.
- **[`tools/gardener/entities/index.md`](./tools/gardener/entities/index.md)** — **MASTER PROJECT DATABASE.** Automatically updated to track all managed entities.

---

## **Step-by-Step Instructions (The Lifecycle)**

1. **Gather (Compost)**: Drop raw data into `compost/bin/`.
2. **Sort (Glossary)**: Distill key terms and concepts into [`glossary.md`](./entities/glossary.md).
3. **Instantiate (Seeds)**: Create a new document in [`entities/seeds/`](./entities/seeds/).
4. **Cultivate (Gardener)**: Run `pwsh tools/gardener/scripts/add-to-index.ps1` to reformat seeds into managed projects using the latest template.
5. **Incubate (Nursery)**: Initialize a Sprout project to create a full CD pipeline.
6. **Govern (Index)**: Monitor progress via [`tools/gardener/entities/index.md`](./tools/gardener/entities/index.md) and the Explorer Dashboard (`localhost:8080`).

---

## **The Pipeline Architecture**

The Nursery provides a standardized, fully isolated pipeline for every Sprout project, utilizing **Centralized Proxy Orchestration** to manage environments via isolated Git worktrees.

### **Centralized Orchestration**
Instead of holding individual logic, Sprout projects are managed by the root `.nurse` package. All lifecycle commands (build, start, stop, promote) are routed through the root using the `-Target` parameter to ensure consistent environment states.

### **Environments (Worktrees)**
- **Stable (`core-stable`)**: Proven, production-ready code.
- **B-Test (`core-b-test`)**: Staging for manual human verification.
- **A-Test (`core-a-test`)**: Sandbox for automated agent testing.
- **Merge/Dev (`core-merge`)**: Active integration and development.

### **Tier-per-Pipeline Port Allocation**
To avoid collisions during parallel execution, every pipeline (Core or Feature) is assigned a unique **Port Tier** in `port_registry.json`.
- **Core Tier (e.g., 301)**: Ports mapping to 3010 (Stable), 3011 (B-Test), 3012 (A-Test), etc.
- **Feature Tier (e.g., 302)**: Assigned dynamically to prevent overlap.

---

## **Governance & Templates**

To update project presentation or metadata structure:
1. **Navigate** to `tools/gardener/template/vx/`.
2. **Modify** `entity.md`.
3. **Re-run** `add-to-index.ps1` to apply changes across the garden.