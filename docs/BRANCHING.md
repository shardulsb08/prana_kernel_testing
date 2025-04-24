# Branching Strategy

This document outlines the branching strategy for the kernel testing framework.

## Branch Structure

```
main
  └── syzkaller_descriptions
        └── gerrit/*
```

- `main`: Base branch containing all shared code and documentation
- `syzkaller_descriptions`: Feature branch for syzkaller-specific changes
- `gerrit/*`: Individual branches for Gerrit code reviews

## Workflow

### 1. Regular Development

```bash
# Start from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/name
# Make changes
git commit
git push origin feature/name
```

### 2. Syzkaller Development

```bash
# Update main
git checkout main
git pull origin main

# Update syzkaller_descriptions
git checkout syzkaller_descriptions
git rebase main
git push origin syzkaller_descriptions

# Create Gerrit change
git checkout -b gerrit/feature-name syzkaller_descriptions
# Make changes
git commit
git push origin HEAD:refs/for/syzkaller_descriptions
```

### 3. Maintaining Synchronization

```bash
# After main is updated
git checkout main
git pull origin main
git checkout syzkaller_descriptions
git rebase main
git push -f origin syzkaller_descriptions

# After Gerrit changes are merged
git checkout syzkaller_descriptions
git pull origin syzkaller_descriptions
git rebase main
git push -f origin syzkaller_descriptions
```

## Best Practices

1. **Always Branch from Latest**:
   - Keep `main` up-to-date
   - Rebase feature branches regularly

2. **Clean Commits**:
   - One logical change per commit
   - Clear commit messages
   - No merge commits in Gerrit changes

3. **Branch Naming**:
   - `feature/*`: Regular features
   - `bugfix/*`: Bug fixes
   - `gerrit/*`: Gerrit changes
   - `docs/*`: Documentation updates

4. **Conflict Resolution**:
   - Resolve conflicts in feature branches
   - Keep rebasing instead of merging
   - Document complex conflict resolutions

## Common Commands

### Setup New Feature
```bash
git checkout main
git pull
git checkout -b feature/name
# Make changes
git commit -m "feat: description"
git push origin feature/name
```

### Update Syzkaller Branch
```bash
git checkout main
git pull
git checkout syzkaller_descriptions
git rebase main
git push -f origin syzkaller_descriptions
```

### Create Gerrit Change
```bash
git checkout syzkaller_descriptions
git pull
git checkout -b gerrit/feature-name
# Make changes
git commit -m "feat: description"
git push origin HEAD:refs/for/syzkaller_descriptions
```

### Cleanup After Merge
```bash
git checkout main
git pull
git branch -d feature/name  # Delete local branch
git push origin --delete feature/name  # Delete remote branch
``` 