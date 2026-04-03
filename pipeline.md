# Strategy Garden: Sprout Pipeline Architecture

The Strategy Garden implements a standardized, robust DevOps pipeline for every "sprout" (a managed project). Instead of relying on a single codebase where different tests and features conflict, the Garden uses **Git Worktrees** and **Dynamic Port Allocation** to run physically isolated environments simultaneously.

## Core Concepts

When a sprout is initialized, its root directory acts strictly as an orchestration container. The actual code resides in sub-directories representing isolated Git branches (worktrees). 

There are two types of pipelines: **Core** and **Feature**.

### 1. The Core Pipeline
The Core pipeline represents the trunk of your project. It is perpetually maintained across 4 permanent environments:

- **Stable (`core-stable`):** The baseline, production-ready code.
- **Human Testing (`core-b-test`):** The staging area where humans perform manual QA.
- **Agent Testing (`core-a-test`):** The automated sandbox where AI agents verify code functionality via smoke tests.
- **Merge (`core-merge`):** The integration development branch. When features are finished, they merge here first to resolve conflicts against the main codebase.

### 2. Feature Pipelines
To build a new feature or resolve a bug, a new Feature pipeline is spawned. A Feature pipeline draws from a source environment (usually `core-stable`) and creates 3 temporary working environments:

- **Feature Dev (`feature-NAME-dev`):** Where raw code changes are written.
- **Feature Agent Testing (`feature-NAME-a-test`):** Where AI agents test the specific feature.
- **Feature Human Testing (`feature-NAME-b-test`):** Where manual reviewers test the feature.

*Lifecycle:* Once a feature passes Human Testing, it is promoted into `core-merge` to integrate with the main app. From there, it flows up through `core-a-test`, `core-b-test`, and finally into `core-stable`. Once merged into stable, the feature worktrees are pruned.

## Server & Dynamic Port Allocation

Because a single project might run up to 4 (Core) + 3 (Feature) = 7 simultaneous servers, the Garden uses dynamic port allocation to ensure no collisions occur. 

Ports are assigned following an **`x0yz`** schema:

- **`x` (Project Tier):** e.g., `3`, `4`, `5`. If standard ports are taken (e.g. `3000`), the script automatically bumps to `4000` or `5000` to find a free tier.
- **`y` (Pipeline ID):**
  - `1` = Core Pipeline
  - `2` = Feature pipeline A
  - `3` = Feature pipeline B
- **`z` (Environment):**
  - `0` = Stable
  - `1` = B-Test (Core) OR Dev (Feature)
  - `2` = A-Test (Core & Feature)
  - `3` = Merge/Dev (Core) OR B-test (Feature)

### Example Port Mappings (Tier 3000)

**Core Pipeline (`y=1` -> `x01z`):**
- Stable: `3010`
- B-Test: `3011`
- A-Test: `3012`
- Merge: `3013`

**Feature "Darkmode" (`y=2` -> `x02z`):**
- Dev: `3021`
- A-Test: `3022`
- B-Test: `3023`

When you run the setup script, you assign it a run command (e.g., `npm run dev --port {PORT}`). The pipeline automation dynamically scans for the lowest available `x` and `y` tiers, replaces the placeholder, and launches the entire suite of servers perfectly isolated from each other.
