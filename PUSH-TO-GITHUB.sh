#!/bin/bash
#
# Script to push s390x-acpi-fix to GitHub
#

set -e

echo "=========================================="
echo "Push s390x-acpi-fix to GitHub"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [[ ! -f "README.md" ]] || [[ ! -f "libvirt-preload-acpi-fix.c" ]]; then
    echo "❌ Error: Must run from s390x-acpi-fix directory"
    echo "Run: cd s390x-acpi-fix && bash PUSH-TO-GITHUB.sh"
    exit 1
fi

echo "Step 1: Checking git status..."
echo "------------------------------"
git status
echo ""

echo "Step 2: Checking for remote..."
echo "-------------------------------"
if git remote | grep -q origin; then
    echo "✅ Remote 'origin' already exists:"
    git remote -v
    echo ""
    read -p "Do you want to remove and re-add the remote? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote remove origin
        echo "✅ Removed existing remote"
    fi
fi

if ! git remote | grep -q origin; then
    echo ""
    echo "Step 3: Adding GitHub remote..."
    echo "--------------------------------"
    echo ""
    echo "First, create the repository on GitHub:"
    echo "  1. Go to: https://github.com/new"
    echo "  2. Repository name: s390x-acpi-fix"
    echo "  3. Description: LD_PRELOAD library to fix ACPI incompatibility for s390x domains on RHEL 9 / QEMU 9.x"
    echo "  4. Public repository"
    echo "  5. DO NOT initialize with README, .gitignore, or license (we have them)"
    echo "  6. Click 'Create repository'"
    echo ""
    read -p "Press Enter after creating the repository on GitHub..."
    echo ""
    
    # Default to ibm-adarsh, but allow override
    read -p "Enter your GitHub username [ibm-adarsh]: " github_user
    github_user=${github_user:-ibm-adarsh}
    
    echo ""
    echo "Choose authentication method:"
    echo "  1. HTTPS (requires GitHub token or password)"
    echo "  2. SSH (requires SSH key configured)"
    read -p "Enter choice (1 or 2) [1]: " auth_choice
    auth_choice=${auth_choice:-1}
    
    if [[ "$auth_choice" == "2" ]]; then
        remote_url="git@github.com:${github_user}/s390x-acpi-fix.git"
    else
        remote_url="https://github.com/${github_user}/s390x-acpi-fix.git"
    fi
    
    echo ""
    echo "Adding remote: $remote_url"
    git remote add origin "$remote_url"
    echo "✅ Remote added"
fi

echo ""
echo "Step 4: Pushing to GitHub..."
echo "----------------------------"
echo ""
echo "This will push the main branch to GitHub."
echo "You may be prompted for authentication."
echo ""
read -p "Press Enter to continue..."

if git push -u origin main; then
    echo ""
    echo "=========================================="
    echo "✅ SUCCESS!"
    echo "=========================================="
    echo ""
    echo "Your repository is now on GitHub!"
    echo ""
    git_remote=$(git remote get-url origin)
    if [[ "$git_remote" == git@* ]]; then
        repo_url=$(echo "$git_remote" | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
    else
        repo_url=$(echo "$git_remote" | sed 's/\.git$//')
    fi
    echo "View at: $repo_url"
    echo ""
    echo "Next steps:"
    echo "  1. Visit your repository on GitHub"
    echo "  2. Add topics: s390x, libvirt, rhel9, qemu, acpi"
    echo "  3. Test the fix on a311lp22"
    echo "  4. Create a release after successful testing"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ Push failed"
    echo "=========================================="
    echo ""
    echo "Common issues:"
    echo ""
    echo "1. Authentication failed:"
    echo "   - HTTPS: Use a Personal Access Token, not password"
    echo "     Generate at: https://github.com/settings/tokens"
    echo "   - SSH: Ensure your SSH key is added to GitHub"
    echo "     Check: ssh -T git@github.com"
    echo ""
    echo "2. Repository doesn't exist:"
    echo "   - Create it first at: https://github.com/new"
    echo ""
    echo "3. Permission denied:"
    echo "   - Ensure you own the repository"
    echo "   - Check the remote URL: git remote -v"
    echo ""
    echo "Try again with:"
    echo "  bash PUSH-TO-GITHUB.sh"
    exit 1
fi

# Made with Bob
