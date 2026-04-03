# init.ps1
# This script runs once immediately after a sprout directory is created and the package is copied.
# Its primary purpose is to establish the isolated initial git repository structure.

Write-Host "Initializing isolated Git repository..." -ForegroundColor Cyan

# 1. Initialize empty git repository
git init

# 2. Add all recently copied files (seed file and packaged scripts)
git add .

# 3. Create root commit
git commit -m "chore: initial sprout generation" | Out-Null

Write-Host "Git repository initialized." -ForegroundColor Green

# 4. Create core/stable worktree upfront so the user can develop the app
# We use an orphan branch so it does not inherit `_nursery` or the initial repo history.
git checkout --orphan core/stable | Out-Null
git rm -rf . | Out-Null
git commit --allow-empty -m "chore: initialize isolated core/stable application branch" | Out-Null
git checkout master | Out-Null

git worktree add core/stable core/stable | Out-Null

Write-Host "Created clean 'core/stable' worktree." -ForegroundColor Cyan

# 5. Generate README-FIRST.md
$readmeContent = @"
# 🛑 README FIRST

Welcome to your new Sprout project!

To properly establish your multi-tiered continuous deployment pipeline, follow these steps:

## Step 1: Initialize Your App in \`core/stable\`
Navigate into the **\`core/stable/\`** directory and build your application there. 
For example, run your \`npx create-vite\` or \`npx create-next-app\` command INSIDE \`core/stable/\`. Everything that makes up your application should be built inside that folder so it propagates correctly.

*Note: You MUST commit your changes inside \`core/stable/\` before proceeding to Step 2.*

## Step 2: Build the DevOps Pipeline
Once your application serves correctly (e.g. you know the command to run it locally), return to the Root directory and launch the pipeline builder:

\`\`\`powershell
pwsh _nursery/scripts/build-pipeline.ps1 -RunCommand "your server command e.g. npm run dev -- --port {PORT}"
\`\`\`

*(Be sure to include `{PORT}` exactly where your framework expects a port number).*

This script will read your \`core/stable\` codebase and map out the remaining independent environments (\`core/merge\`, \`core/a-test\`, \`core/b-test\`)!
"@

Set-Content -Path "README-FIRST.md" -Value $readmeContent -Encoding UTF8
Write-Host "Dropped README-FIRST.md with instructions!" -ForegroundColor Yellow
