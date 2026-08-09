# GitHub org & repo configuration

What's configured across `branchLeft`, and why.

## Goal

Anyone can fork and open a PR. Nobody — including maintainers, by default — can push directly to `main`, force-push it, or delete it. Merges require a green CI run, an approving review, and land as a single signed commit.

## Org level (`branchLeft`)

- `members_can_create_repositories: false`, `default_repository_permission: none` — new members get no access until explicitly granted.
- New-repo security defaults on: Dependabot alerts/updates, dependency graph, secret scanning, secret scanning push protection.
- **Known Free-plan limitation:** `members_can_delete_repositories`, `members_can_change_repo_visibility`, and `members_can_invite_outside_collaborators` cannot be turned off via the API on this plan — they silently stay `true`. Low risk today since both org members are owners, but revisit if a non-owner member is ever added.
- Org 2FA requirement: enable manually at **Settings → Authentication security** — no API for this field.

## Per repo (`website`, `components`, and any future repo via `scripts/bootstrap-repo.sh`)

- **Merge:** squash-only, auto-delete branch on merge. Squash-only is load-bearing, not cosmetic — see signing below.
- **Security:** secret scanning + push protection, Dependabot alerts + automated security fixes, private vulnerability reporting, CodeQL default setup.
  - `secret_scanning_non_provider_patterns` and `secret_scanning_validity_checks` are GHAS sub-features that stay locked on Free even for public repos.
- **Actions:** `allowed_actions: selected` — GitHub-owned + verified-publisher actions only, plus an explicit per-repo allow-list for anything else a workflow uses. Default workflow token permissions are read-only with no self-approval of PR reviews.
- **Branch protection (ruleset, not legacy branch protection):** on `main` —
  - no deletion, no force-push, linear history required
  - required signatures
  - PR required: 1 approving review, code-owner review required, stale reviews dismissed on push, last-pusher can't self-approve, conversations must be resolved, squash-only
  - required status checks (per repo's actual CI job names), strict (branch must be up to date)
  - bypass: org admins only
- **Tag protection** (repos that publish releases, e.g. `components`): `v*` tags can't be deleted or force-moved.

### Why squash-only + required signatures together

`required_signatures` rejects any commit reaching `main` that isn't signed. External contributors won't have commit signing set up, and we don't want that to be a barrier. Squash-only merges resolve this: GitHub creates the squash commit itself and signs it with GitHub's own key, so the *landed* commit is always Verified regardless of whether the contributor's own commits were signed. `CONTRIBUTING.md` says this explicitly so it doesn't read as a trap.

### Org-level rulesets vs per-repo

GitHub's org-level rulesets (one ruleset, all current + future repos) require **GitHub Team**. This org is on Free — confirmed by attempting the org ruleset API and getting `403 Upgrade to GitHub Team to enable this feature`. Until/unless that changes, `scripts/bootstrap-repo.sh` is the mechanism for applying the same configuration to a new repo in one command.

## Fork contribution path

- Fork-PR workflow runs require approval before they execute for outside collaborators (first-time-contributor approval is GitHub's public-repo default). No REST API exists for this setting — it's Settings → Actions → General → "Fork pull request workflows" on each repo.
- CODEOWNERS lives per-repo (not inherited from this `.github` repo) and currently points at `@branchLeft/branchleft-admin`, which has explicit write access to each repo — required for GitHub to actually request their review.

## Rollback

`gh api -X DELETE repos/branchLeft/<repo>/rulesets/<id>` removes a ruleset. To soften without deleting, `PATCH` the ruleset with `"enforcement": "evaluate"` — rules are reported (visible in PR checks / the ruleset insights UI) but not enforced. Useful as a dry run on a new repo before flipping to `"active"`.
