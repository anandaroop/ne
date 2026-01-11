---
name: bump-version
description: Increments the gem version. Follows semantic versioning. Use when asked to "bump version" or even just "bump"
---

# Bump Gem Version

Workflow:

```
- [ ] Determine the new version number
- [ ] Increment the declared version number
- [ ] Update artifacts
- [ ] Commit with changelog
```

## Determine the new version number

- Review changes since the last time @lib/natural_earth/version.rb was updated

- Follow semantic versioning rules to determine whether this is a major, minor or patch version change

## Increment the declared version number

- Increment the version in @lib/natural_earth/version.rb

## Update artifacts

- Run `bundle install`
  - This will update @Gemfile.lock

## Commit with changelog

- Prepare a conventional commit message with a concise summary of changes since the last version bump
- IMPORTANT: be sure to only list commits SINCE the previous "chore(version)" commit
- IMPORTANT: omit the previous "chore(version)" commits from the listing

```
chore(version): 1.2.3

1e646e0 docs: reorg and refresh
0354eaf feat: add dual-axis buffer control
ee6bbb0 fix: ne.csv access bug
```

Commit the change.
