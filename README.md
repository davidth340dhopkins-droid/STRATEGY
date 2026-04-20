# Strategy Garden

This repository is a system for managing and scaling projects with the assistance of AI. It contains a structured lifecycle for transforming raw data and ideas into valuable products, and projects are gathered together into a single repository accessible by AI.

**Caution:** This repository is a work-in-progress and any included documentation may not accurately reflect its current state.

---

## **Repository Index**

This section provides an index of the major components and directories of the Strategy Garden repository.

### **Compost**

- **[`compost/`](./compost/)** — A dumping site for raw, unfiltered data. It provides the heterogeneous material from which ideas may be derived.

- **[`compost/bin/`](./compost/bin/)** — Specifically for outside-source content or legacy materials to optionally signify that they are not to be considered applicable to the current environment.

### **Entities**

- **[`entities/`](./entities/)** — The active development site where ideas are grown.

- **[`entities/seeds/`](./entities/seeds/)** — Document-based projects, which are either managed or unformatted.

- **[`entities/sprouts/`](./entities/sprouts/)** — Mature projects that have moved to their own folders.

### **Tools (Gardener & Nurse)**

- **[`tools/`](./tools/)** — Automation systems.

- **[`tools/gardener/`](./tools/gardener/)** — Automation scripts and template systems.

- **[`tools/gardener/entities/index.md`](./tools/gardener/entities/index.md)** — **MASTER PROJECT DATABASE.** Automatically updated by the gardener's scripts. Use this to track all managed entities.

### **Terminology**

- **[`glossary.md`](./entities/glossary.md)** — Definitions for terms with special meanings within the Strategy Garden.

---

## **Step-by-Step Instructions (The Lifecycle)**

Follow these steps for regular maintenance of the garden:

1. **Gather (Compost)**:
   - Identify raw ideas, data, or source materials.
   - Drop them into `compost/bin/`. This is your dumping ground for unfiltered "heterogeneous material."

2. **Sort (Glossary)**:
   - Review your compost and distill key terms, concepts, or potential brand identities.
   - Document them in [`glossary.md`](./entities/glossary.md). This is where ideas are stored before they are born as projects.

3. **Instantiate (Seeds)**:
   - When a concept is ready to become a project, create a new document in [`entities/seeds/`](./entities/seeds/).
   - Use the Gardener tools to formalize them into the index.

4. **Cultivate (Gardener)**:
   - Run `pwsh tools/gardener/scripts/add-to-index.ps1` to reformat seeds into managed projects.
   - This applies the master template and enforces the `_filename.md` naming convention.

5. **Govern (Index)**:
   - Monitor the master project list at [`tools/gardener/entities/index.md`](./tools/gardener/entities/index.md).
   - Use the Explorer Dashboard (`localhost:8080`) to browse your progress.

---

## **Rationale & Philosophy**

### **The Role of AI**
Artificial intelligence is a powerful technology for achieving one's goals. It has strengths and weaknesses — which are complemented by human intelligence — and the best results may always be achieved by applying both forms of intelligence together.

Artificial intelligence:
- Is a specialist and not a generalist.
- Learns slowly and periodically (rather than continuously).
- Produces work that is "high-volume" (but "low-signal").

Because of these characteristics, optimal AI-assisted work tends to:
- Progress "radially" rather than "linearly".
- Progress allometrically rather than isometrically.
- Be "process-oriented" rather than "outcome-oriented."

### **Human vs. AI Workflows**
Human work tends to involve focusing on a single objective and using experimentation and iteration to incrementally build towards it until it is achieved. Humans learn continuously and are generalists, so the results from any failed attempt will be rapidly synthesized. As humans operate in the real world (which is slow and expensive), there tends to be more value in gaining the desired result quickly than in understanding why it was achieved.

Conversely, AI-assisted work relies on abstraction rather than experimentation. AI agents have a U-shaped efficiency curve: they are most effective working on outcomes that are very general or very specific and struggle at those in between. As complex tasks involve starting with a broad problem space and making it progressively narrower, the way that we deal with the inevitable problem of the "messy middle" is to pre-empt it. We begin by abstracting the task into a series of precise steps for the AI to follow. We can use the AI itself to help us with the abstraction process and, if necessary, continue adding layers of abstraction until executing the task successfully is sufficiently deterministic.

### **Parallelism & Scaling**
A productive AI-assisted workflow involves multiple parallel attempts and frequent testing gates. Once an objective is abstracted into a series of steps, it is useful for the AI to make many parallel attempts at executing each step for human review. The human then selects the best attempt with which to proceed, or elects to modify the process (which can be done with the help of the AI), or both.

Because AI operates in the digital realm, process design is more valuable as any result of a process can be multiplied and scaled rapidly. Just as multiple parallel attempts may be made at the micro level to execute a step correctly, multiple attempts may be made at the macro level to design the correct process.

This **Strategy Garden** is fashioned to build and discover the optimal project development process to incorporate the latest agentic tools whilst advancing the projects themselves. It permits quickly switching between projects and developing projects at different rates in parallel ("radial, allometric" development), rapidly copying process-related learnings across projects, and compiling all project-related activity into a single location to facilitate cross-project pollination.

---

## **Process Overview**

### **Gather & Sort**
Firstly, ideas are gathered in the "glossary" ([`glossary.md`](./entities/glossary.md)). These ideas may optionally be sourced from raw data that is dumped in the `compost/` folder, which is distilled into key terms, concepts, or potential brand identities.

### **Plant**
Secondly, select glossary entries are converted into "seed" entities. To do so, each idea is assigned a key and a document is composed for it in the [`entities/seeds/`](./entities/seeds/) subdirectory. These may be freeform documents or they may be created (and/or processed) using the "gardener" tool. Processed seed documents are added to the gardener's "index" ([`tools/gardener/entities/index.md`](./tools/gardener/entities/index.md)) which makes it easier to edit multiple seed documents at once.

The gardener processes seed documents with the use of a common template and the index is to be rebuilt whenever a managed seed document is edited or the template is updated.

### **Cultivate**
Thirdly, select seed entities are converted into "sprout projects" using the "nursery" tool. Sprouts are assigned their own folder (in [`entities/sprouts/`](./entities/sprouts/)) and their seed document is moved to this location. The nursery tool sets up a standardized DevOps pipeline for the project with feature worktrees and version control by copying a `.nurse` package into the target sprout directory on initialization.

---

## **The Pipeline Architecture**

This section explains the architecture of the fully isolated pipeline configuration, which builds on the concept of Git Worktrees to map environments to isolated, self-managing subdirectories.

### **Environments (Worktrees)**
A "sprout" project acts as a single Git repository container. Within it, environments use isolated worktree directories.

#### **The Core Pipeline**
The basic continuous deployment system is the Core Pipeline. It maintains four subdirectories and branches:
- **Stable (`core-stable`)**: Tested, production-ready code.
- **Human Testing (`core-b-test`)**: Staging for manual QA.
- **Agent Testing (`core-a-test`)**: Code awaiting automated QA.
- **Merge (`core-merge`)**: Active integration development area.

#### **Feature Pipelines**
When building a new feature or fixing a bug, a new feature branch is created (usually diverging from Stable). It spawns its own three unique temporary worktrees:
- **Feature Dev (`feature-NAME-dev`)**: Active feature development.
- **Feature Agent Testing (`feature-NAME-a-test`)**: Automated QA.
- **Feature Human Testing (`feature-NAME-b-test`)**: Manual QA.

Once verified in B-Test, a feature branch is merged into the `core-merge` branch (to test its integration with the rest of the live codebase). It is then promoted step-by-step through the Core environments until resolving in Stable.

### **Dynamic Port Allocation**
When simultaneously running parallel environments, port collisions must be avoided. The Sprout logic automatically maps blocks of contiguous ports to environments using an `xxyz` schema.
- **`xx` (Project Tier)**: Default is `30`. If entirely occupied, it bumps sequentially to `31`, `32`, etc.
- **`y` (Pipeline Tier)**: `1` = Core, `2` = Feature A, etc.
- **`z` (Level)**: `0`=Stable, `1`=B-Test/Dev, `2`=A-Test, `3`=Merge.

**Example Ports (`xx`=`30`)**:
- Core Pipeline (`y`=1): `3010`, `3011`, `3012`, `3013`.
- Feature A (`y`=2): `3021`, `3022`, `3023`.

If you re-run the environment boot script, it uses polling mechanisms (via PowerShell) to determine if a blocked port is occupied by your app. If it matches your specific project directory path, the system will terminate the old process and cleanly reuse the port.

---

## **Updating the Gardener Template**

To change the structural metadata or their presentation, you can update the template document. These changes will impact all managed projects once the build script is re-run.

1. **Locate the Template**: Navigate to `tools/gardener/template/`. You will see folders named by version (e.g., `v37`).
2. **Increment the Version**: Duplicate the latest version folder and increment its number (e.g., rename the copy to `v38`).
3. **Modify the Structure**: Edit the `entity.md` file inside your new folder. You can add or remove frontmatter fields, edit descriptions, and change the markdown layout.
4. **Deploy**: No commands are required. The next time you run `pwsh tools/gardener/scripts/add-to-index.ps1` on a file, the script will dynamically detect the highest version folder and apply its contents.