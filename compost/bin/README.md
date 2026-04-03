# Entity Database Manager

This folder contains the automation and source files for the versioned Entity
Database.

## 🧱 What is this?

This system separates **data** from **display**. You manage entity information
in clean YAML frontmatter blocks, and a build script automatically renders that
data into a beautiful, human-readable markdown layout using versioned templates.

- **Source of Truth**: The YAML fields at the top of each `.md` file.

- **Auto-Rendering**: A script (`scripts/build-index.ps1`) converts your YAML
  data into a markdown body and updates the global index table.

- **Versioning**: Each entity is "stamped" with a template version, allowing the
  database to evolve over time without breaking older records.

## 📂 Quick Structure

- `entities/v{n}/` — Your actual entity records (Markdown with YAML
  frontmatter).

- `_templates/v{n}/` — Master layouts for each version of the database.

- `entities/_index.md` — The auto-generated master list of all entities.

- `scripts/start-dashboard.ps1` — Starts a live file explorer (Port 8080) for
  remote browsing.

## 🛠️ How to Manage Entities

### 1. Create a New Entity

Run the creator script to scaffold a blank file from the latest template:

```powershell
# Usage: pwsh -File "scripts/create-entity.ps1" "project-name" [-NoBuild]
pwsh -File "scripts/create-entity.ps1" "my-new-project"
```

_Note: Use `-NoBuild` to skip the index update if you are creating multiple
entities in a row._

### 2. Configure & Build

1. Open the newly created `.md` file in your editor.

2. Fill in the YAML fields (between the `---` lines).

3. **Rename Automation**: If you change the `key` field in the YAML, the build
   script will automatically rename the `.md` file to match it on its next run.

4. **Compile After Edits**: After editing existing YAML fields, manually run the
   build script to update the markdown body and the database index:

   ```powershell
   # Usage: pwsh -File "scripts/build-index.ps1" [-Cleanup] [-KeepBin]
   pwsh -File "scripts/build-index.ps1"
   ```
   _Note: Add `-Cleanup` to automatically run the cleanup script (which prunes
   old folders AND empties the `_bin`). Add `-KeepBin` if you want to keep
   recycled files._

### 3. Edit an Entity

- Open the `.md` file and edit the YAML block directly.

- Always run `scripts/build-index.ps1` after editing.

- **Important**: NEVER edit the markdown body below the `---` lines directly. It
  will be overwritten.

### 4. Delete/Recycle an Entity

Use the deletion script to move the entity to the trash and update the index:

```powershell
# Usage: pwsh -File "scripts/delete-entity.ps1" "project-name" [-NoBuild]
pwsh -File "scripts/delete-entity.ps1" "my-old-project"
```

_Note: Entities are moved to a local `_bin` directory with a version and
timestamp suffix—not immediately deleted._

### 5. Live Explorer (Web View)

If you are on the move and want a direct file browser via local host:

```powershell
pwsh -File "scripts/start-dashboard.ps1"
```

_Note: The explorer runs on `http://localhost:8080`. It shows raw directories
and files, allowing you to open and read them directly in your browser. It still
rebuilds the index automatically whenever you save changes._

---

## ⚙️ Advanced Management

### Modifying the Template or Schema

**CRITICAL RULE**: The full versioning process (creating a new `v{n}` directory)
**MUST** be followed every time you change the layout, schema, or even field
comments—unless the user explicitly states otherwise.

- **Preserving History**: This ensures that older entities stay compatible with
  their original templates until you are ready to migrate them.

- **Applying Changes**: Create the next version folder (e.g., `v28`), copy the
  previous template, apply your edits, and increment the `template_version`
  strictly inside the new file.

When you are ready to migrate existing entities, update their `template_version`
in their YAML frontmatter and run `scripts/build-index.ps1`. The script will
automatically re-render the bodies and move the files to the new versioned
folder.

Detailed steps are in the [entities.md](../../../.agents/workflows/entities.md)
workflow.

## 🚀 Further Documentation

For detailed instructions on schema updates, template versioning, and mass
migrations, refer to the official workflow document: 👉
[entities.md](../../../.agents/workflows/entities.md)

---

_Note: Always keep the build script updated if the folder structure moves._
