#!/bin/sh
# Minimal helper to commit & push changes under your GitHub account.
# Usage:
#   npm run git-push "commit message"
# Environment overrides:
#   GIT_USER_NAME (default: dianemushimiyimana413)
#   GIT_USER_EMAIL (default: you@example.com)
#   REMOTE (default: origin)
#   BRANCH (default: main)

set -e

GIT_USER_NAME="${GIT_USER_NAME:-dianemushimiyimana413}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-you@example.com}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"
MSG="${1:-auto: update $(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

# set local repo identity for this repo
git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

# ensure we have a remote configured
if ! git remote | grep -q "^${REMOTE}$"; then
  echo "No remote named '${REMOTE}' configured."
  echo "Add your remote, e.g.:"
  echo "  git remote add ${REMOTE} git@github.com:${GIT_USER_NAME}/REPO.git"
  exit 1
fi

# stage, commit and push
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "$MSG"
fi

git push "$REMOTE" "$BRANCH"
echo "Pushed to ${REMOTE}/${BRANCH} as ${GIT_USER_NAME}"
