#!/bin/bash

echo "🔧 Git Configuration Setup Script"

# Step 1: Ask for basic Git user info
read -p "👤 Enter your full name: " GIT_NAME
read -p "📧 Enter your email address: " GIT_EMAIL

# Step 2: Set global Git config
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Step 3: Set default editor
read -p "📝 Preferred Git editor (default: nano, options: nano/vim/code/etc): " GIT_EDITOR
GIT_EDITOR=${GIT_EDITOR:-nano}
git config --global core.editor "$GIT_EDITOR"

# Step 4: Enable colored output
git config --global color.ui auto

# Step 5: Set default branch name to `main`
git config --global init.defaultBranch main

# Step 6: Optional - Sign commits with GPG
read -p "🔐 Do you want to enable commit signing with GPG? (y/n): " SIGN_COMMITS
if [[ "$SIGN_COMMITS" =~ ^[Yy]$ ]]; then
    echo "🔍 Available GPG keys:"
    gpg --list-secret-keys --keyid-format=long

    read -p "Enter your GPG key ID (e.g. ABCDEF1234567890): " GPG_KEY
    git config --global user.signingkey "$GPG_KEY"
    git config --global commit.gpgsign true
    git config --global gpg.format gpg
    echo "✅ Git commit signing enabled."
else
    echo "❌ Skipping GPG signing setup."
fi

# Step 7: Confirm config
echo ""
echo "📄 All Your Git global configuration:"
git config --global --list

echo "✅ Git config setup complete!"