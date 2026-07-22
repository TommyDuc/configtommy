---
name: nix-version-check
description: >
  Check whether a newer version of a nixpkgs package is available in the nixpkgs
  channels (nixpkgs-unstable, master, staging-next) compared to the version
  currently installed or pinned locally. Reports where a bump sits in the
  staging -> master -> unstable pipeline and whether `nix flake update` would
  pick it up. Use when the user asks "is a new version available", "is it fixed
  in nixpkgs yet", "recheck upstream", "would a nix update fix this", or wants to
  track a package bump landing in a channel.
---

# Nix Version Check

Determine if a newer version of a nixpkgs package has reached a channel that a
`nix flake update` would resolve, and where the bump currently sits in the
nixpkgs release pipeline.

## When to Use

- "Is a new version of X available?"
- "Is it fixed in nixpkgs yet?" / "Would `nix flake update` fix this?"
- "Recheck upstream." (tracking a CVE fix or bump moving toward a channel)
- Tracking a specific package bump landing in `nixpkgs-unstable`.

## Procedure

### 1. Identify the current/local version

In priority order:

- Resolved flake version: `nix eval --raw nixpkgs#<pkg>.version`
- The tool's own report: `<tool> --version` (e.g. `go version`)
- The pinned rev in `flake.lock` for the `nixpkgs` input.

### 2. Locate the version file path in nixpkgs

Package definitions live at different paths, and versioned packages split by
version (e.g. Go: `pkgs/development/compilers/go/1.26.nix`).

- Find it: `nix eval nixpkgs#<pkg>.meta.position` (returns `path:line`).
- Or search the nixpkgs tree for the attribute file.

Record the path relative to the repo root; call it `<path>`.

### 3. Query the channels

Compare the three relevant branches. `nixpkgs-unstable` is the branch a
`github:nixos/nixpkgs/nixpkgs-unstable` flake input tracks, so it is the one
that decides whether `nix flake update` fixes the issue.

```bash
for br in nixpkgs-unstable master staging-next; do
  echo "=== $br ==="
  curl -s "https://raw.githubusercontent.com/NixOS/nixpkgs/$br/<path>" \
    | grep -m1 'version ='
done
```

### 4. Interpret the pipeline

The bump flows `staging` -> `staging-next` -> `master` -> Hydra build ->
`nixpkgs-unstable`.

| Where the new version appears        | Meaning                                              | ETA to channel   |
| ------------------------------------ | ---------------------------------------------------- | ---------------- |
| `nixpkgs-unstable` has it            | `nix flake update` **will** fix it. Act now.         | available        |
| `master` has it, unstable does not   | Hydra building the unstable jobset green.            | ~1-3 days        |
| only `staging-next` has it           | Earlier in pipeline, not on master yet.              | ~4-10 days       |
| none of them                         | Not merged yet. Check the tracking/bump PR.          | unknown          |

ETAs are rough and never guaranteed; the channel advances only when Hydra
builds pass.

### 5. Verdict and action plan

State a clear yes/no on: "Would `nix flake update` fix it right now?"

When `nixpkgs-unstable` shows the new version:

1. `nix flake update` (updates the `nixpkgs` rev in `flake.lock`).
2. Verify: `nix eval --raw nixpkgs#<pkg>.version` or `<tool> --version`.
3. Re-run the relevant check (e.g. `just audit`, tests).
4. Commit `flake.lock` only, unless a version floor in another file also needs
   raising.

## Notes

- Channel name depends on the flake input. A flake tracking `nixos-unstable` or
  a release channel (`nixos-25.11`, `nixpkgs-25.11-darwin`) needs that branch
  substituted into the loop.
- The `grep 'version ='` pattern fits packages with an explicit `version` attr.
  For packages pinned via `fetchFromGitHub` tags or `buildGoModule` `rev`, read
  the definition and match the tag/rev field instead.
- To find the PR carrying a bump, search:
  `https://api.github.com/search/issues?q=repo:NixOS/nixpkgs+<pkg>+<version>+in:title+type:pr`
