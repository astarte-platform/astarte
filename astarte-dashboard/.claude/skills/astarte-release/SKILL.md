---
name: astarte-release
description: Standardized workflow to prepare, tag, and publish a new release for Astarte Dashboard
---

# Astarte Dashboard Release Workflow

This workflow describes Astarte project's release strategy and it must be followed when a release is to be prepared or published.

## Astarte Branching & Release Strategy

- **Base branches**: `master` is the main development branch. Release branches are named `release-X.Y` (e.g., `release-1.2`, `release-1.3`).
- **Versioning**: Strict Semantic Versioning with a `v` prefix for tags (e.g., `v1.2.0`, `v1.3.0-rc.1`, `v1.2.1-alpha.0`).
- **Files to update**: `package.json`, `package-lock.json`, and `CHANGELOG.md`.
- **Changelog format**: Follows "Keep a Changelog". Updates are staged in an `[Unreleased]` section.

## Process: Part 1 - Prepare the Release

When a new release is to be prepared (e.g., v1.3.0):

1. **Determine the target release branch**:

   - The target branch should be `release-X.Y` based on the version being released, e.g. `release-1.3` for a `v1.3.2` release.
   - Verify if the `release-X.Y` branch exists on the main repository.
   - If it does not exist, create the branch on the main repo, branching it off the `master` branch.

2. **Create a preparation branch**:

   - Create a new branch on your personal fork (e.g., `prepare-release-v1.3.0`) branching off the target release branch.

3. **Update Versions**:

   - Update the `version` field in `package.json` to the new version (without the `v` prefix), and the `version` fields in `package-lock.json` (e.g. manually or by running `npm install`).

4. **Update CHANGELOG.md**:

   - Locate the `## [Unreleased]` section.
   - Rename the `## [Unreleased]` header with the upcoming release tag and current date, e.g. `## [X.Y.Z(-prerelease)] - YYYY-MM-DD`.
   - If there are no unreleased changes, create a new section for the new version with empty appropriate headers (Added, Changed, Fixed, etc.) or whatever is appropriate based on Keep a Changelog.
   - Add a new, empty `## [Unreleased]` section at the top of the changelog for future changes.

5. **Commit & Pull Request**:
   - Commit the changes with the message: `chore(release): prepare vX.Y.Z`.
   - Push the preparation branch to your personal fork.
   - Use `gh pr create` to open a Pull Request against the target `release-X.Y` branch on the main repository.
   - Ensure you use a descriptive PR title like `chore(release): prepare vX.Y.Z`.

## Process: Part 2 - Tag and Publish the Release

The release must be tagged and published AFTER the preparation PR is merged:

1. **Verify merge**:

   - Ensure the preparation PR is merged into the `release-X.Y` branch.
   - Fetch the latest changes from the main repository and checkout the `release-X.Y` branch.

2. **Tag the release**:

   - Tag the merge commit with the release tag, using a signed and annotated tag (e.g., `git tag -as v1.3.0 -m "Astarte Dashboard v1.3.0 release"`).
   - Push the tag to the main repository.

3. **Create GitHub Release**:
   - Extract the release notes for this specific version from `CHANGELOG.md`.
   - Use the `gh release create` command to create a GitHub release targeting the tag.
   - **Important**: The title should be the tag name (e.g., `v1.3.0`). The body should contain the changes reported in the `CHANGELOG.md` for this release, following the existing pattern from previous releases.
   - **Prerelease flag**: If the release tag contains `-alpha`, `-beta`, or `-rc` (e.g. `v1.3.0-rc.1`), you MUST append the `--prerelease` flag to the `gh release create` command. Set the release as the latest one with the `--latest` flag only when releasing the highest stable (not prelease) version according to semantic versioning scheme.
