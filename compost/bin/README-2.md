# Strategy Garden

This repository is dedicated to building and managing a system
for generating and scaling sustainable income streams with the
assistance of AI.

The directory index and landing page for the gardener console is:
**[index.md](./index.md)**.

## **Step-by-Step Instructions (The Lifecycle)**

Follow these steps for regular maintenance of the garden:

1. **Gather (Compost)**:

   - Identify raw ideas, data, or source materials.

   - Drop them into `compost/bin/`. This is your dumping ground for
     unfiltered "heterogeneous material."

2. **Sort (Glossary)**:

   - Review your compost and distill key terms, concepts, or
     potential brand identities.

   - Document them in [`glossary.md`](./glossary.md). This is where
     ideas are stored before they are born as projects.

3. **Instantiate (Seeds)**:

   - When a concept is ready to become a project, create a new
     document in [`entities/seeds/`](./entities/seeds/).

   - Use the Gardener tools to formalize them into the index.

4. **Cultivate (Gardener)**:

   - Run `pwsh gardener/scripts/add-to-index.ps1` to reformat seeds
     into managed projects.

   - This applies the master template and enforces the
     `_filename.md` naming convention.

5. **Govern (Index)**:

   - Monitor the master project list at
     [`gardener/entities/_index.md`](./gardener/entities/_index.md).

   - Use the Explorer Dashboard (`localhost:8080`) to browse your
     progress.

## **Updating the Gardener Template**

To change the structural metadata or their presentation, you can
update the template document. These changes will impact all
managed projects once the build script is re-run (and this may be
triggered automatically).

1. **Locate the Templates**: Navigate to `gardener/_templates/`.
   You will see folders named by version (e.g., `v31`).

2. **Increment the Version**: Duplicate the latest version folder
   and increment its number (e.g., rename the copy to `v32`).

3. **Modify the Structure**: Edit the `entity.md` file inside your
   new folder. You can add or remove frontmatter fields, edit the
   name and descriptions of existing fields, and change the text
   layout for the markdown body. Be careful to observe the
   instructions within the template file to avoid breakage.

4. **Deploy**: No commands are required. The next time you run
   `pwsh gardener/scripts/add-to-index.ps1` on a file, the script
   will dynamically detect highest version folder and apply its
   contents. Existing entities retain the structure they were
   created with.
