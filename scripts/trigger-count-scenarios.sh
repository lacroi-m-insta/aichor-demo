#!/usr/bin/env bash
#
# Trigger one AIchor experiment per count scenario via the git commit webhook.
#
# AIchor reads ONLY the head commit of a push (api GitPayloadManager
# .GetHeadCommitMessage matches payload.after against payload.commits), so a
# push carrying 20 commits triggers exactly one experiment. This script
# therefore commits and pushes one scenario at a time.
#
# Commit format (api CommitMessagePolicy):
#   ^aichor\((?<selector>[^)]+\.ya?ml)\):     <- used here
#   ^aichor\[(?<selector>[^\]]+)\]:
# The selector is the manifest path relative to aichor_manifests/.
#
# Usage:
#   scripts/trigger-count-scenarios.sh [options]
#     --operator <list>   comma-separated: jax,jobset,kuberay,pytorch,xgboost
#     --scenario <list>   comma-separated: count-minus-1,count-0,count-1,count-absent
#     --delay <seconds>   wait between pushes (default 5)
#     --dry-run           print what would be committed and pushed, change nothing
#     --yes               skip the confirmation prompt
#     --remote <name>     git remote (default origin)
#   Examples:
#     scripts/trigger-count-scenarios.sh --dry-run
#     scripts/trigger-count-scenarios.sh --operator kuberay
#     scripts/trigger-count-scenarios.sh --scenario count-0,count-1 --yes

set -euo pipefail

MANIFEST_ROOT="aichor_manifests"
SCENARIO_DIR="count-scenarios"
OPERATORS="jax,jobset,kuberay,pytorch,xgboost"
SCENARIOS="count-minus-1,count-0,count-1,count-absent"
DELAY=5
DRY_RUN=0
ASSUME_YES=0
REMOTE="origin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --operator) OPERATORS="$2"; shift 2 ;;
    --scenario) SCENARIOS="$2"; shift 2 ;;
    --delay)    DELAY="$2"; shift 2 ;;
    --remote)   REMOTE="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --yes|-y)   ASSUME_YES=1; shift ;;
    -h|--help)  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# Human-readable tail of the commit message, mirroring the manifest under test.
describe_scenario() {
  case "$1" in
    count-minus-1) echo "count: -1" ;;
    count-0)       echo "count: 0" ;;
    count-1)       echo "count: 1" ;;
    count-absent)  echo "no count present" ;;
    *)             echo "$1" ;;
  esac
}

cd "$(git rev-parse --show-toplevel)"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- preflight ------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean." >&2
  echo "       Commit or stash first: the trigger commits are empty ones on top of HEAD," >&2
  echo "       and the manifests must already be pushed for AIchor to find them." >&2
  exit 1
fi

if ! git rev-parse --abbrev-ref "@{upstream}" >/dev/null 2>&1; then
  echo "error: branch '$BRANCH' has no upstream. Run: git push -u $REMOTE $BRANCH" >&2
  exit 1
fi

# Build the run list, checking each manifest is present AND committed.
declare -a SELECTORS MESSAGES
IFS=',' read -r -a OPERATOR_LIST <<< "$OPERATORS"
IFS=',' read -r -a SCENARIO_LIST <<< "$SCENARIOS"

for operator in "${OPERATOR_LIST[@]}"; do
  for scenario in "${SCENARIO_LIST[@]}"; do
    selector="$SCENARIO_DIR/$operator/$scenario.yaml"
    path="$MANIFEST_ROOT/$selector"

    [[ -f "$path" ]] || { echo "error: no such manifest: $path" >&2; exit 1; }
    git ls-files --error-unmatch "$path" >/dev/null 2>&1 || {
      echo "error: $path is not committed. AIchor reads the manifest from the pushed commit." >&2
      exit 1
    }
    # Same constraints the API enforces on the selector.
    case "$selector" in
      /*|*\\*|*../*) echo "error: invalid selector '$selector'" >&2; exit 1 ;;
    esac
    [[ "$selector" == *.yaml || "$selector" == *.yml ]] || {
      echo "error: selector must end in .yaml or .yml: $selector" >&2; exit 1; }

    SELECTORS+=("$selector")
    MESSAGES+=("aichor($selector): $operator, $(describe_scenario "$scenario")")
  done
done

total="${#MESSAGES[@]}"

echo "Repository : $(git config --get "remote.$REMOTE.url")"
echo "Branch     : $BRANCH -> $REMOTE"
echo "Experiments: $total (one empty commit + one push each)"
echo
for message in "${MESSAGES[@]}"; do
  echo "  $message"
done
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dry run: nothing committed or pushed."
  exit 0
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
  echo "This pushes $total commits to $REMOTE/$BRANCH and starts $total experiments."
  read -r -p "Continue? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { echo "aborted."; exit 1; }
  echo
fi

# --- trigger --------------------------------------------------------------
for i in "${!MESSAGES[@]}"; do
  message="${MESSAGES[$i]}"
  echo "[$((i + 1))/$total] $message"

  # Empty commit: the manifests are already in the tree, only the message matters.
  git commit --allow-empty -q -m "$message"
  git push -q "$REMOTE" "$BRANCH"
  echo "         pushed $(git rev-parse --short HEAD)"

  if [[ $((i + 1)) -lt "$total" && "$DELAY" -gt 0 ]]; then
    sleep "$DELAY"
  fi
done

echo
echo "done: $total experiments triggered."
