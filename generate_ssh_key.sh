#!/bin/bash

KEY_PATH="$HOME/.ssh/id_rsa"
EMAIL=$(git config user.email || whoami)@localhost

echo "🔐 SSH Key Setup Script"

# Step 1: Check for existing SSH key
if [ -f "$KEY_PATH" ]; then
    echo "⚠️ SSH key already exists at $KEY_PATH"

    read -p "Do you want to overwrite it and generate a new one? (y/n): " choice
    case "$choice" in 
      y|Y ) echo "🗝️  Generating a new SSH key...";;
      n|N ) echo "🚫 Aborting. Keeping existing SSH key."; exit 0;;
      * ) echo "❌ Invalid option. Exiting."; exit 1;;
    esac
fi

# Step 2: Generate new SSH key
ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$KEY_PATH" -N ""

# Step 3: Start ssh-agent and add key
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH"

# Step 4: Verify ssh-agent loaded the key
echo "🧪 Verifying SSH agent setup..."
if ssh-add -l &>/dev/null; then
    echo "✅ SSH key added to ssh-agent."
else
    echo "❌ Failed to add SSH key to ssh-agent."
    exit 1
fi

# Step 5: Copy public key to clipboard
echo "📋 Copying public key to clipboard..."
if command -v pbcopy &>/dev/null; then
    cat "${KEY_PATH}.pub" | pbcopy
    echo "✅ Public key copied to clipboard using pbcopy."
elif command -v xclip &>/dev/null; then
    cat "${KEY_PATH}.pub" | xclip -selection clipboard
    echo "✅ Public key copied to clipboard using xclip."
elif command -v wl-copy &>/dev/null; then
    cat "${KEY_PATH}.pub" | wl-copy
    echo "✅ Public key copied to clipboard using wl-copy."
else
    echo "⚠️ Could not copy to clipboard automatically."
    echo "You can copy it manually:"
    echo
    cat "${KEY_PATH}.pub"
    echo
fi

# Step 6: Open GitHub SSH key page in browser
echo "🌐 Opening GitHub SSH key upload page..."
if command -v xdg-open &>/dev/null; then
    xdg-open "https://github.com/settings/ssh/new"
elif command -v open &>/dev/null; then
    open "https://github.com/settings/ssh/new"  # macOS
else
    echo "🔗 Please manually open this URL in your browser:"
    echo "https://github.com/settings/ssh/new"
fi

# Step 7: Wait for user to confirm
read -p "✅ After adding the key to GitHub, press [Enter] to continue and test the connection..."

# Step 8: Test SSH connection to GitHub
echo "🔗 Testing SSH connection to GitHub..."
ssh -T git@github.com

echo "🎉 SSH setup script completed."
