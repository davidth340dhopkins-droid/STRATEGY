# Strategy Garden Pipeline

This document explains the architecture of the fully isolated 
pipeline configuration for the Strategy Garden, which builds on
the concept of Git Worktrees to map environments to isolated,
self-managing subdirectories.

## **Environments (Worktrees)**

A "sprout" project acts as a single Git repository container. 
Within it, environments use isolated worktree directories.

### **The Core Pipeline**

The basic continuous deployment system is the Core Pipeline.
It maintains four subdirectories and branches:

- **Stable (`core-stable`)**: Tested, production-ready code.
- **Human Testing (`core-b-test`)**: Staging for manual QA.
- **Agent Testing (`core-a-test`)**: Code awaiting automated QA.
- **Merge (`core-merge`)**: Active integration development area.

### **Feature Pipelines**

When building a new feature or fixing a bug, a new feature 
branch is created (usually diverging from Stable). It spawns 
its own three unique temporary worktrees:

- **Feature Dev (`feature-NAME-dev`)**: Active feature development.
- **Feature Agent Testing (`feature-NAME-a-test`)**: Automated QA.
- **Feature Human Testing (`feature-NAME-b-test`)**: Manual QA.

Once verified in B-Test, a feature branch is merged into the
`core-merge` branch (to test its integration with the rest of the
live codebase). It is then promoted step-by-step through the Core
environments until resolving in Stable. At that point, the feature 
worktrees are permanently closed.

## **Dynamic Port Allocation**

When simultaneously running parallel environments, port 
collisions must be avoided. The Sprout logic automatically maps
blocks of contiguous ports to environments using an `xxyz`
schema.

- **`xx` (Project Tier)**: Default is `30`. If entirely occupied,
  it bumps sequentially to `31`, `32`, etc.
- **`y` (Pipeline Tier)**: `1` = Core, `2` = Feature A, etc.
- **`z` (Level)**: `0`=Stable, `1`=B-Test/Dev, `2`=A-Test, `3`=Merge.

**Example Ports (`xx`=`30`)**:
- Core Pipeline (`y`=1): `3010`, `3011`, `3012`, `3013`.
- Feature A (`y`=2): `3021`, `3022`, `3023`.

This scheme correctly pairs the first two digits matching 
throughout the entire project lifecycle, distinguishing the app
from other concurrent Garden tools.

## **Automatic Collisions Lifecycle**

If you re-run the environment boot script, it uses polling 
mechanisms (`Get-NetTCPConnection` interacting with properties
of the application `Win32_Process`) to determine if a blocked port 
is occupied by your app or a foreign app.

If it matches your specific project directory path, the system
will quickly terminate the old process and cleanly reuse the 
port. This eliminates "EADDRINUSE" errors during development
without artificially shifting to a different port tier (which 
would break local proxy setups and testing workflows).
