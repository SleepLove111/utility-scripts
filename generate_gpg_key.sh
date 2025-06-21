#!/bin/bash

echo "🔐 GitHub GPG Key Setup Script"

# Step 1: Get user identity
GIT_NAME=$(git config user.name)
GIT_EMAIL=$(git config user.email)

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  echo "❌ Git user name or email not configured. Set them using:"
  echo "   git config --global user.name 'Your Name'"
  echo "   git config --global user.email 'you@example.com'"
  exit 1
fi

echo "👤 Name:  $GIT_NAME"
echo "📧 Email: $GIT_EMAIL"

# Step 2: Generate GPG key (non-interactive for modern systems)
echo "⚙️ Generating GPG key (RSA, 4096-bit)..."
gpg --batch --generate-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: $GIT_NAME
Name-Email: $GIT_EMAIL
Expire-Date: 0
%commit
EOF

# Step 3: Find GPG key ID
KEY_ID=$(gpg --list-secret-keys --keyid-format=long "$GIT_EMAIL" | awk '/sec/{print $2}' | awk -F'/' '{print $2}')
if [ -z "$KEY_ID" ]; then
  echo "❌ Could not find generated GPG key."
  exit 1
fi

echo "🔑 GPG key ID: $KEY_ID"

# Step 4: Configure Git to use GPG key
git config --global user.signingkey "$KEY_ID"
git config --global commit.gpgsign true
git config --global gpg.format gpg
echo "✅ Git is now configured to sign commits with your GPG key."

# Step 5: Export and copy the public key
echo "📋 Copying public key to clipboard..."
if command -v pbcopy &>/dev/null; then
  gpg --armor --export "$KEY_ID" | pbcopy
  echo "✅ Public GPG key copied to clipboard using pbcopy."
elif command -v xclip &>/dev/null; then
  gpg --armor --export "$KEY_ID" | xclip -selection clipboard
  echo "✅ Public GPG key copied to clipboard using xclip."
elif command -v wl-copy &>/dev/null; then
  gpg --armor --export "$KEY_ID" | wl-copy
  echo "✅ Public GPG key copied to clipboard using wl-copy."
else
  echo "⚠️ Could not copy to clipboard automatically. Here's your public key:"
  echo
  gpg --armor --export "$KEY_ID"
  echo
fi

# Step 6: Open GitHub GPG key page
echo "🌐 Opening GitHub GPG key upload page..."
if command -v xdg-open &>/dev/null; then
  xdg-open "https://github.com/settings/keys"
elif command -v open &>/dev/null; then
  open "https://github.com/settings/keys"
else
  echo "🔗 Please manually open this URL to paste your GPG key:"
  echo "https://github.com/settings/keys"
fi

# Step 7: Final message
echo
echo "✅ GPG key setup completed. Paste your key in GitHub, then try:"
echo "   git commit -S -m 'Signed commit'"
