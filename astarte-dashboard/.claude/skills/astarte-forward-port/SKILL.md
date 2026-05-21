---
name: astarte-forward-port
description: Standardized workflow to cascade bug fixes and changes from older release branches to newer release branches and eventually into master.
---

# Astarte Dashboard Forward-Porting Workflow

## Role

This workflow must be followed to ensure that fixes and changes landed in older `release-X.Y` branches are correctly "forward-ported" (cascaded) to all newer active release branches, and finally into the `master` branch.
The workflow must also be followed when creating a new release on an older `release-X.Y` branch, so that the CHANGELOG.md file in newer release branches includes the section of the released version and presents a coherent release history.

## Understanding the Branch Hierarchy

- **Base Branches**: Fixes target the oldest affected active release branch (e.g., `release-1.1`).
- **Target Branches**: Newer release branches (e.g., `release-1.2`) and finally `master`.
- **Progression Flow**: A fix applied to `release-1.1` must be forward-ported to `release-1.2`. Once merged there, it must be forward-ported from `release-1.2` to `master` (when no `release-1.3` or newer version branches exist).

## Process: How to Forward-Port

When requested to forward port changes from `release-X.Y` to the next branch in the hierarchy (either `release-A.B` or `master`), follow these steps:

1. **Identify the Target Branch**:

   - Find the next minor release branch available on the `origin` repository (e.g., if you are porting from `release-1.1`, check if `release-1.2` exists).
   - If no newer release branch exists, the ultimate target branch is `master`.

2. **Create the Forward-Port Branch**:

   - Check out the _Target Branch_ from the main repository (e.g., `git checkout origin/release-1.2` or `git checkout origin/master`).
   - Create a new temporary branch on your personal fork for the forward-port: e.g. `forward-port-release-X.Y-into-<target-branch>`.

3. **Merge the Changes**:

   - Fetch the latest changes from the _Source Branch_ (the older branch).
   - Perform a merge using the `--no-ff` flag to explicitly record the merge commit:
     `git merge --no-ff origin/release-X.Y`
   - **Handling Conflicts**: If there are merge conflicts, resolve them carefully, keeping in mind the logic from the newer branch while incorporating the fix from the older branch. Commit the conflict resolution.

4. **Open the Pull Request**:

   - Push your newly created forward-port branch to your personal fork.
   - Use `gh pr create` to open a Pull Request against the _Target Branch_ on the main repository.
   - **Title Naming Convention**: Use the format `Forward port release X.Y into <target-branch>` (e.g., "Forward port release 1.1 into release 1.2" or "Forward port release 1.2 into master").

5. **Continue the Cascade (Iterative Loop)**:
   - Once your PR is reviewed and merged into the target branch, the process is not necessarily over.
   - If the target branch was a release branch (e.g., `release-1.2`), you MUST repeat steps 1-4 to forward port `release-1.2` into the next branch (e.g., `release-1.3`), and so on, until the changes finally land in `master`.
