#!/usr/bin/env bash

# Enable strict mode: exit on error, treat unset variables as errors, pipefail
set -euo pipefail

echo "🔐 GitHub GPG Key Setup Script (with revocation cleanup)"
echo "---"

# Check for gpg command
if ! command -v gpg &>/dev/null; then
    echo "❌ Error: 'gpg' command not found. Please install GnuPG."
    exit 1
fi

# Step 1: Get user identity
GIT_NAME=$(git config user.name)
GIT_EMAIL=$(git config user.email)

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    echo "❌ Git user name or email not configured. Set them using:"
    echo "    git config --global user.name 'Your Name'"
    echo "    git config --global user.email 'you@example.com'"
    exit 1
fi

echo "👤 Name:  ${GIT_NAME}"
echo "📧 Email: ${GIT_EMAIL}"
echo "---"

# Confirm details before generating key
read -p "❓ Do you want to generate a GPG key for ${GIT_NAME} <${GIT_EMAIL}>? (y/N) " -n 1 -r
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborting GPG key generation."
    exit 0
fi

# Step 2: Generate GPG key (non-interactive for modern systems)
echo "⚙️ Generating GPG key (RSA, 4096-bit, no passphrase)..."
# Using a temporary file for the batch input to avoid issues with here-strings
GPG_BATCH_FILE=$(mktemp)
cat <<EOF > "$GPG_BATCH_FILE"
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: ${GIT_NAME}
Name-Email: ${GIT_EMAIL}
Expire-Date: 0
%commit
EOF

# Trap to clean up temporary file on exit
trap 'rm -f "$GPG_BATCH_FILE"' EXIT

if ! gpg --batch --generate-key "$GPG_BATCH_FILE"; then
    echo "❌ Failed to generate GPG key."
    exit 1
fi

echo "---"

# Step 3: Find the newly generated GPG key ID (latest matching key)
# Filter for secret keys, sort by creation date (implicitly by tail -n1 after grep 'sec'), and extract key ID
KEY_ID=$(gpg --list-secret-keys --keyid-format=long "${GIT_EMAIL}" 2>/dev/null | grep 'sec' | tail -n1 | awk '{print $2}' | cut -d'/' -f2)

if [ -z "$KEY_ID" ]; then
    echo "❌ Could not find generated GPG key for ${GIT_EMAIL}. Manual inspection needed."
    exit 1
fi

echo "🔑 Newly generated GPG key ID: \033[1;32m${KEY_ID}\033[0m" # Green for key ID
echo "---"

# Step 4: Revoke and delete older GPG keys matching this email
echo "🧹 Checking for and revoking older GPG keys matching ${GIT_EMAIL}..."
ALL_KEY_IDS=$(gpg --list-secret-keys --keyid-format=long "${GIT_EMAIL}" 2>/dev/null | grep 'sec' | awk '{print $2}' | cut -d'/' -f2)
OLD_KEYS_FOUND=0

for ID in $ALL_KEY_IDS; do
    if [ "$ID" != "$KEY_ID" ]; then
        OLD_KEYS_FOUND=1
        echo "❗ Found old key: \033[1;33m${ID}\033[0m" # Yellow for old key ID
    fi
done

if [ "$OLD_KEYS_FOUND" -eq 1 ]; then
    read -p "❓ Do you want to revoke and delete these older keys? (This is irreversible!) (y/N) " -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        for ID in $ALL_KEY_IDS; do
            if [ "$ID" != "$KEY_ID" ]; then
                echo "Revoking old key: \033[1;33m${ID}\033[0m"

                # Generate and import revocation certificate
                REVOKE_FILE=$(mktemp "/tmp/revoke-${ID}-XXXXXX.asc")
                if ! gpg --batch --yes --output "$REVOKE_FILE" --gen-revoke "$ID" <<< "y"$'\n'"0"$'\n'"Superseded by new key ${KEY_ID}"; then
                    echo "⚠️ Warning: Failed to generate revocation certificate for ${ID}. Skipping revocation and deletion for this key."
                    rm -f "$REVOKE_FILE"
                    continue
                fi

                if ! gpg --import "$REVOKE_FILE" &>/dev/null; then
                    echo "⚠️ Warning: Failed to import revocation certificate for ${ID}."
                fi
                rm -f "$REVOKE_FILE"

                echo "Deleting old key: \033[1;33m${ID}\033[0m"
                # Suppress output from delete commands unless there's a critical error
                if ! gpg --batch --yes --delete-secret-keys "$ID" &>/dev/null; then
                    echo "⚠️ Warning: Failed to delete secret key for ${ID}."
                fi
                if ! gpg --batch --yes --delete-keys "$ID" &>/dev/null; then
                    echo "⚠️ Warning: Failed to delete public key for ${ID}."
                fi
            fi
        done
        echo "🧹 Older GPG key cleanup complete."
    else
        echo "Skipping revocation and deletion of older keys."
    fi
else
    echo "No older GPG keys found to revoke/delete for ${GIT_EMAIL}."
fi
echo "---"

# Step 5: Configure Git to use the new GPG key
echo "⚙️ Configuring Git to use the new GPG key..."
git config --global user.signingkey "${KEY_ID}"
git config --global commit.gpgsign true
git config --global gpg.format gpg
echo "✅ Git is now configured to sign commits with your GPG key: \033[1;32m${KEY_ID}\033[0m."
echo "---"

# Step 6: Export and copy the public key
echo "📋 Copying public key to clipboard..."
PUBLIC_KEY=$(gpg --armor --export "${KEY_ID}")

if command -v pbcopy &>/dev/null; then
    echo "$PUBLIC_KEY" | pbcopy
    echo "✅ Public GPG key copied to clipboard using pbcopy."
elif command -v xclip &>/dev/null; then
    echo "$PUBLIC_KEY" | xclip -selection clipboard
    echo "✅ Public GPG key copied to clipboard using xclip."
elif command -v wl-copy &>/dev/null; then
    echo "$PUBLIC_KEY" | wl-copy
    echo "✅ Public GPG key copied to clipboard using wl-copy."
else
    echo "⚠️ Could not copy to clipboard automatically. Here's your public key:"
    echo
    echo "${PUBLIC_KEY}"
    echo
fi
echo "---"

# Step 7: Open GitHub GPG key page
echo "🌐 Opening GitHub GPG key upload page..."
GITHUB_KEYS_URL="https://github.com/settings/keys"
if command -v xdg-open &>/dev/null; then
    xdg-open "$GITHUB_KEYS_URL" &>/dev/null
    echo "✅ Opened GitHub GPG key upload page in your default browser."
elif command -v open &>/dev/null; then
    open "$GITHUB_KEYS_URL" &>/dev/null
    echo "✅ Opened GitHub GPG key upload page in your default browser."
else
    echo "🔗 Please manually open this URL to paste your GPG key:"
    echo "${GITHUB_KEYS_URL}"
fi
echo "---"

# Step 8: Final message
echo
echo "✅ GPG key setup completed!"
echo "➡️ Please paste the copied GPG public key into the 'New GPG key' field on the GitHub page that just opened."
echo "Then, you can try signing a commit:"
echo "    git commit -S -m 'Signed commit'"
echo
echo "🎉 Happy GPG signing!"
