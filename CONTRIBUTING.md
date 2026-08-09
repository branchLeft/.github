# Contributing to branchLeft

This applies to every repository in the branchLeft org unless that repo's own `CONTRIBUTING.md` says otherwise.

## Process

1. Fork the repo and create a branch off `main`.
2. Make your change, following the repo's own setup docs for install/lint/test commands.
3. Open a pull request against `main`. Fill in the PR template.
4. CI must pass and a maintainer must approve before it can merge.
5. PRs are merged with **squash merge only** — your branch's commit history doesn't need to be clean, but your PR title/description should be, since that becomes the commit message on `main`.

## You don't need to sign your commits

`main` requires signed commits, but that's satisfied by the squash-merge commit GitHub itself creates and signs when your PR is merged — your own commits, on your branch, do not need to be signed. Don't let this block you from contributing.

## Review

All PRs need one approving review from a maintainer (`@branchLeft/branchleft-admin`) before merge. Please be patient — this is a small team.

## Documentation

Changes to documentation, and to code comments, follow [docs/DOCUMENTATION-STANDARD.md](docs/DOCUMENTATION-STANDARD.md). The short version: write the current state, name people by role rather than by name, and put the reasoning behind a change in the PR description rather than in the repo. A `docs-lint` check enforces the mechanical parts.

## Code of Conduct

Participation is governed by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a security issue

Do not open a public issue. See [SECURITY.md](SECURITY.md).
