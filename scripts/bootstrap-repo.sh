#!/usr/bin/env bash
# Apply branchLeft's standard open-source lockdown to a repo.
#
# Org-level rulesets require GitHub Team; on the Free plan each repo needs
# this applied individually. Run this once against any new branchLeft repo.
#
# Usage:
#   scripts/bootstrap-repo.sh --repo <name> [--check "job name"]... [--tags] \
#     [--action "owner/action@version-pattern"]... [--codeowners "@branchLeft/branchleft-admin"]
#
# Examples:
#   scripts/bootstrap-repo.sh --repo website \
#     --check "Typecheck, Pre-commit & Coverage" --check "End-to-end tests" \
#     --check "Pulumi preview" \
#     --action "docker/build-push-action@*" --action "google-github-actions/auth@*"
#
#   Only require a preview check whose job runs on every PR to the default
#   branch. A job gated by a workflow-level `paths:` filter never reports on
#   PRs outside those paths, and a required check that never reports blocks
#   the PR permanently.
#
#   scripts/bootstrap-repo.sh --repo components \
#     --check "Lint, Format & Test" --tags
#
# Requires: gh (authenticated with admin:org + repo scopes on an org owner account)

set -euo pipefail

ORG="branchLeft"
REPO=""
CHECKS=()
ACTIONS=()
PROTECT_TAGS=false
CODEOWNERS_LINE="* @branchLeft/branchleft-admin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --check) CHECKS+=("$2"); shift 2 ;;
    --action) ACTIONS+=("$2"); shift 2 ;;
    --tags) PROTECT_TAGS=true; shift ;;
    --codeowners) CODEOWNERS_LINE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "Usage: $0 --repo <name> [--check \"job name\"]... [--tags] [--action \"owner/repo@pattern\"]... [--codeowners \"...\"]" >&2
  exit 1
fi

FULL="$ORG/$REPO"
echo "==> Bootstrapping $FULL"

echo "--> Merge strategy, branch cleanup, community features"
gh api -X PATCH "repos/$FULL" \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true -F allow_auto_merge=true -F allow_update_branch=true \
  -F has_wiki=false -F has_discussions=true >/dev/null

echo "--> Secret scanning + push protection"
gh api -X PATCH "repos/$FULL" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' >/dev/null

echo "--> Dependabot alerts, automated security fixes, private vulnerability reporting"
gh api -X PUT "repos/$FULL/vulnerability-alerts"
gh api -X PUT "repos/$FULL/automated-security-fixes"
gh api -X PUT "repos/$FULL/private-vulnerability-reporting"

echo "--> Actions: default workflow token permissions to read-only, no self-approval"
gh api -X PUT "repos/$FULL/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false >/dev/null

echo "--> Actions: restrict to GitHub-owned + verified creators$( [[ ${#ACTIONS[@]} -gt 0 ]] && echo " + explicit allow-list" )"
gh api -X PUT "repos/$FULL/actions/permissions" -F enabled=true -f allowed_actions=selected >/dev/null
SELECTED_ARGS=(-F github_owned_allowed=true -F verified_allowed=true)
for a in "${ACTIONS[@]:-}"; do
  [[ -n "$a" ]] && SELECTED_ARGS+=(-f "patterns_allowed[]=$a")
done
gh api -X PUT "repos/$FULL/actions/permissions/selected-actions" "${SELECTED_ARGS[@]}" >/dev/null

echo "--> CodeQL default setup"
gh api -X PATCH "repos/$FULL/code-scanning/default-setup" \
  -f state=configured -f query_suite=default -f 'languages[]=javascript-typescript' >/dev/null || \
  echo "    (skipped — enable manually if this repo isn't JS/TS, or check /code-scanning/default-setup for supported languages)"

echo "--> Branch protection ruleset (default branch)"
RULESET_JSON="$(mktemp)"
trap 'rm -f "$RULESET_JSON"' EXIT

CHECKS_JSON=""
for c in "${CHECKS[@]:-}"; do
  [[ -z "$c" ]] && continue
  esc="${c//\"/\\\"}"
  CHECKS_JSON+="${CHECKS_JSON:+,}{\"context\":\"$esc\"}"
done

python3 - "$RULESET_JSON" "$CHECKS_JSON" <<'PYEOF'
import json, sys
out_path, checks_json = sys.argv[1], sys.argv[2]
checks = json.loads(f"[{checks_json}]") if checks_json else []
ruleset = {
    "name": "Protect default branch",
    "target": "branch",
    "enforcement": "active",
    "bypass_actors": [{"actor_id": 1, "actor_type": "OrganizationAdmin", "bypass_mode": "always"}],
    "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
    "rules": [
        {"type": "deletion"},
        {"type": "non_fast_forward"},
        {"type": "required_linear_history"},
        {"type": "required_signatures"},
        {"type": "pull_request", "parameters": {
            "required_approving_review_count": 1,
            "dismiss_stale_reviews_on_push": True,
            "require_code_owner_review": True,
            "require_last_push_approval": True,
            "required_review_thread_resolution": True,
            "allowed_merge_methods": ["squash"],
        }},
    ],
}
if checks:
    ruleset["rules"].append({
        "type": "required_status_checks",
        "parameters": {"strict_required_status_checks_policy": True, "required_status_checks": checks},
    })
with open(out_path, "w") as f:
    json.dump(ruleset, f)
PYEOF

if [[ -z "$CHECKS_JSON" ]]; then
  echo "    (warning: no --check given — merging won't require any CI check to pass. Add --check \"<job name>\" per required workflow job.)"
fi

gh api -X POST "repos/$FULL/rulesets" --input "$RULESET_JSON" >/dev/null

if $PROTECT_TAGS; then
  echo "--> Tag protection (v*)"
  gh api -X POST "repos/$FULL/rulesets" --input "$SCRIPT_DIR/rulesets/protected-tags.json" >/dev/null
fi

echo "--> CODEOWNERS"
if gh api "repos/$FULL/contents/.github/CODEOWNERS" >/dev/null 2>&1; then
  echo "    (already exists — leaving as-is)"
else
  DEFAULT_BRANCH="$(gh api "repos/$FULL" --jq .default_branch)"
  CONTENT_B64="$(printf '%s\n' "$CODEOWNERS_LINE" | base64 | tr -d '\n')"
  gh api -X PUT "repos/$FULL/contents/.github/CODEOWNERS" \
    -f message="chore: add CODEOWNERS" \
    -f content="$CONTENT_B64" \
    -f branch="$DEFAULT_BRANCH" >/dev/null
  echo "    created with: $CODEOWNERS_LINE"
fi

cat <<EOF

==> Done. Still manual (no API, or org-wide already set):
    - Org 2FA requirement / member permissions — set once at the org level, not per-repo.
    - "Fork pull request workflows" approval policy — Settings > Actions > General on $FULL
      (recommend "Require approval for all outside collaborators").
    - Verify the CODEOWNERS team ($CODEOWNERS_LINE) actually has write+ access to $FULL,
      or code-owner review requests will silently do nothing.
EOF
