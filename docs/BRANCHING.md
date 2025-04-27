# Branching Strategy

This document outlines the branching strategy used in this project.

## Main Branches

### main
- The primary branch containing production-ready code
- Always stable and deployable
- Protected branch - requires code review and CI passing
- No direct commits allowed

### development
- Integration branch for feature development
- Code here is in a pre-release state
- Merges into main when stable
- Regular integration testing performed

## Feature Branches

### Format
Feature branches follow the naming convention:
```
<type>/<description>
```

Where `type` is one of:
- `feature/` - New features
- `bugfix/` - Bug fixes
- `hotfix/` - Critical fixes for production
- `release/` - Release preparation
- `infrastructure/` - Infrastructure changes
- `docs/` - Documentation updates

### Examples
- `feature/add-new-test-framework`
- `bugfix/fix-vm-networking`
- `infrastructure/restructure-codebase`
- `docs/add-documentation`

## Workflow

1. Create feature branch from development
2. Develop and test changes
3. Create pull request to development
4. Code review and CI checks
5. Merge to development
6. Periodic releases from development to main

## Release Process

1. Create release branch from development
2. Version bump and changelog updates
3. Final testing and fixes
4. Merge to main with tag
5. Backport critical fixes to main if needed

## Hotfix Process

1. Create hotfix branch from main
2. Fix critical issue
3. Merge to main and development
4. Create new release tag

## Branch Protection

### main
- Requires pull request
- Requires code review approval
- Must pass CI checks
- No direct commits

### development
- Requires pull request
- Must pass CI checks
- Code review recommended

## Best Practices

1. Keep branches focused and short-lived
2. Regular rebasing with parent branch
3. Descriptive commit messages
4. Clean commit history
5. Delete branches after merging

## Commit Messages

Format:
```
<type>: <subject>

[optional body]

[optional footer]
```

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting
- refactor: Code restructuring
- test: Adding tests
- chore: Maintenance

Example:
```
feat: Add new VM network configuration

- Added support for custom network bridges
- Updated documentation
- Added unit tests

Fixes #123
``` 