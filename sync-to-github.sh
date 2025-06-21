#!/bin/bash

# === CONFIGURABLE ===
GITHUB_URL="$1"  # Pass GitHub repo URL as the first argument
COMMIT_MSG="${2:-'Initial commit or update from script'}"  # Optional commit message
TARGET_DIR="${3:-$(basename -s .git "$GITHUB_URL")}"  # Optional local folder name

if [[ -z "$GITHUB_URL" ]]; then
  echo "❌ Error: No GitHub URL provided here."
  echo "Usage: $0 <github_repo_url> [commit_message] [target_directory]"
  exit 1
fi

# === SCRIPT START ===
echo "📁 Setting up local repo in: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || exit 1

echo "🔧 Initializing Git repository..."
git init

echo "🔗 Adding remote origin..."
git remote add origin "$GITHUB_URL"

echo "⬇️ Fetching from remote (if exists)..."
git pull origin main --allow-unrelated-histories 2>/dev/null || echo "⚠️ Could not pull (maybe remote is empty or branch is missing)."

echo "📦 Adding new files..."
git add .

echo "📝 Committing changes..."
git commit -m "$COMMIT_MSG"

echo "🚀 Pushing to remote..."
git branch -M main
git push -u origin main

echo "✅ Done. Local repo synced with $GITHUB_URL"