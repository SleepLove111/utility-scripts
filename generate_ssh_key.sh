#!/usr/bin/env bash

# Enable strict mode: exit on error, treat unset variables as errors, pipefail
set -euo pipefail

# ANSI escape codes for colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "🔐 ${GREEN}SSH Key Setup Script${NC}"
echo "---"

# Step 0: Check for required commands
if ! command -v ssh-keygen &>/dev/null; then
    echo -e "${RED}❌ Error: 'ssh-keygen' command not found. Please install OpenSSH.${NC}"
    exit 1
fi
if ! command -v ssh-agent &>/dev/null; then
    echo -e "${RED}❌ Error: 'ssh-agent' command not found. Please install OpenSSH.${NC}"
    exit 1
fi

# Determine key path and email
KEY_PATH="${HOME}/.ssh/id_rsa"
# Get user email from Git config, or fall back to username@hostname
EMAIL=$(git config user.email 2>/dev/null || echo "$(whoami)@$(hostname)")

echo "Key will be generated at: ${YELLOW}${KEY_PATH}${NC}"
echo "Key comment (email) will be: ${YELLOW}${EMAIL}${NC}"
echo "---"

# Step 1: Check for existing SSH key
if [ -f "$KEY_PATH" ]; then
    echo -e "${YELLOW}⚠️ An SSH key already exists at ${KEY_PATH}${NC}"
    read -p "Do you want to ${RED}overwrite${NC} it and generate a new one? (y/N): " choice
    case "$choice" in
        y|Y ) echo -e "🗝️  Generating a new SSH key...";;
        * ) echo -e "${GREEN}🚫 Aborting. Keeping existing SSH key.${NC}"; exit 0;;
    esac
fi

# Step 2: Generate new SSH key
echo -e "⚙️ Generating new SSH key (RSA, 4096-bit)..."
# Prompt for passphrase, or generate without one if user prefers.
read -p "Do you want to set a passphrase for your SSH key? (Recommended for security) (y/N): " use_passphrase_choice
PASSPHRASE=""
if [[ "$use_passphrase_choice" =~ ^[Yy]$ ]]; then
    echo "Enter passphrase (leave empty for no passphrase):"
    read -s -p "Passphrase: " PASSPHRASE
    echo
    read -s -p "Confirm passphrase: " PASSPHRASE_CONFIRM
    echo

    if [ "$PASSPHRASE" != "$PASSPHRASE_CONFIRM" ]; then
        echo -e "${RED}❌ Passphrases do not match. Aborting key generation.${NC}"
        exit 1
    fi
    ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$KEY_PATH" -N "$PASSPHRASE"
else
    echo "Generating key without a passphrase."
    ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$KEY_PATH" -N ""
fi

# Check if key generation was successful
if [ ! -f "$KEY_PATH" ]; then
    echo -e "${RED}❌ Failed to generate SSH key. Please check for errors above.${NC}"
    exit 1
fi

# Set secure permissions for the private key
chmod 600 "$KEY_PATH"
echo -e "${GREEN}✅ SSH key generated at ${KEY_PATH}${NC}"
echo "---"

# Step 3: Start ssh-agent and add key
echo "🚀 Starting ssh-agent and adding key..."
eval "$(ssh-agent -s)" # Start agent in the current shell session
if ! ssh-add "$KEY_PATH" &>/dev/null; then
    echo -e "${RED}❌ Failed to add SSH key to ssh-agent. Ensure the key exists and permissions are correct.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ SSH key added to ssh-agent.${NC}"
echo "---"

# Step 4: Copy public key to clipboard
echo "📋 Copying public key to clipboard..."
PUBLIC_KEY_CONTENT=$(cat "${KEY_PATH}.pub" 2>/dev/null || true) # Read public key content

if [ -z "$PUBLIC_KEY_CONTENT" ]; then
    echo -e "${RED}❌ Could not read public key file: ${KEY_PATH}.pub${NC}"
    echo "Please ensure the key was generated successfully."
    exit 1
fi

if command -v pbcopy &>/dev/null; then
    echo "$PUBLIC_KEY_CONTENT" | pbcopy
    echo -e "${GREEN}✅ Public key copied to clipboard using pbcopy.${NC}"
elif command -v xclip &>/dev/null; then
    echo "$PUBLIC_KEY_CONTENT" | xclip -selection clipboard
    echo -e "${GREEN}✅ Public key copied to clipboard using xclip.${NC}"
elif command -v wl-copy &>/dev/null; then
    echo "$PUBLIC_KEY_CONTENT" | wl-copy
    echo -e "${GREEN}✅ Public key copied to clipboard using wl-copy.${NC}"
else
    echo -e "${YELLOW}⚠️ Could not copy to clipboard automatically.${NC}"
    echo "Please copy the public key manually from below:"
    echo
    echo "${PUBLIC_KEY_CONTENT}"
    echo
fi
echo "---"

# Step 5: Open GitHub SSH key page in browser
echo "🌐 Opening GitHub SSH key upload page in your default browser..."
GITHUB_SSH_URL="https://github.com/settings/ssh/new"
if command -v xdg-open &>/dev/null; then
    xdg-open "$GITHUB_SSH_URL" &>/dev/null & # Background the process
    echo -e "${GREEN}✅ Opened GitHub SSH key upload page.${NC}"
elif command -v open &>/dev/null; then # macOS
    open "$GITHUB_SSH_URL" &>/dev/null & # Background the process
    echo -e "${GREEN}✅ Opened GitHub SSH key upload page.${NC}"
else
    echo -e "${YELLOW}🔗 Please manually open this URL in your browser:${NC}"
    echo "$GITHUB_SSH_URL"
fi
echo "---"

# Step 6: Wait for user to confirm
echo "Please paste the copied public key into the 'Key' field on the GitHub page."
read -p "✅ After adding the key to GitHub, press [Enter] to continue and test the connection..."

# Step 7: Test SSH connection to GitHub
echo "🔗 Testing SSH connection to GitHub (this may prompt for passphrase)..."
if ssh -T git@github.com 2>&1 | grep -q "Hi $(whoami)! You've successfully authenticated"; then
    echo -e "${GREEN}✅ SSH connection to GitHub successful!${NC}"
    echo "You should see a message similar to 'Hi YOUR_USERNAME! You've successfully authenticated...' above."
elif ssh -T git@github.com &>/dev/null; then # Catch cases where output is different but still success
    echo -e "${GREEN}✅ SSH connection to GitHub successful! (Output may vary)${NC}"
else
    echo -e "${RED}❌ Failed to establish SSH connection to GitHub.${NC}"
    echo "Please review the output above for errors and ensure your key is correctly added to GitHub."
    echo "You might try running 'ssh -vT git@github.com' for more verbose output."
    exit 1
fi

echo "---"
echo -e "🎉 ${GREEN}SSH key setup script completed!${NC}"
echo "Remember to set up your ssh-agent to load keys automatically on system startup for convenience."
echo "For more details, refer to GitHub's documentation on 'Connecting to GitHub with SSH'."