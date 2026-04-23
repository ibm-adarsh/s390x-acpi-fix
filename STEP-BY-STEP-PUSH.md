# Step-by-Step: Push to GitHub

Your repository is ready at: https://github.com/ibm-adarsh/s390x-acpi-fix

## Step 1: Open Terminal

Open your terminal and navigate to the project:

```bash
cd /Users/adarshyadav/release/s390x-acpi-fix
```

## Step 2: Verify Git Status

Check that everything is committed:

```bash
git status
```

Expected output:
```
On branch main
nothing to commit, working tree clean
```

## Step 3: Add GitHub Remote

Add your GitHub repository as the remote:

```bash
git remote add origin https://github.com/ibm-adarsh/s390x-acpi-fix.git
```

## Step 4: Verify Remote

Check the remote was added correctly:

```bash
git remote -v
```

Expected output:
```
origin  https://github.com/ibm-adarsh/s390x-acpi-fix.git (fetch)
origin  https://github.com/ibm-adarsh/s390x-acpi-fix.git (push)
```

## Step 5: Push to GitHub

Push your code:

```bash
git push -u origin main
```

### Authentication Options

You'll be prompted for authentication. Choose one:

#### Option A: Personal Access Token (Recommended)

1. **Generate token** at: https://github.com/settings/tokens/new
   - Note: "s390x-acpi-fix push"
   - Expiration: 90 days (or your preference)
   - Scopes: ✅ `repo` (full control of private repositories)
   - Click "Generate token"
   - **Copy the token** (you won't see it again!)

2. **When prompted for password**, paste the token (not your GitHub password)

#### Option B: SSH (If you have SSH key configured)

If you prefer SSH, change the remote:

```bash
git remote remove origin
git remote add origin git@github.com:ibm-adarsh/s390x-acpi-fix.git
git push -u origin main
```

## Step 6: Verify on GitHub

After successful push, visit:
https://github.com/ibm-adarsh/s390x-acpi-fix

You should see:
- ✅ README.md displayed
- ✅ 12 files
- ✅ 2 commits
- ✅ MIT License

## Step 7: Add Repository Topics

On GitHub:
1. Click "⚙️ Settings" (or the gear icon near "About")
2. Add topics:
   - `s390x`
   - `libvirt`
   - `rhel9`
   - `qemu`
   - `acpi`
   - `openshift`
   - `ld-preload`
   - `workaround`
3. Save changes

## Step 8: Update Repository Description

On the main page, click "⚙️" next to "About" and add:
- Description: `LD_PRELOAD library to fix ACPI incompatibility for s390x domains on RHEL 9 / QEMU 9.x`
- Website: (leave empty or add your blog)
- ✅ Releases
- ✅ Packages

## Troubleshooting

### Error: "remote origin already exists"

```bash
git remote remove origin
git remote add origin https://github.com/ibm-adarsh/s390x-acpi-fix.git
```

### Error: "Authentication failed"

- For HTTPS: Use Personal Access Token, not password
- For SSH: Check `ssh -T git@github.com`

### Error: "Permission denied"

- Ensure you're logged into the correct GitHub account
- Verify repository ownership at https://github.com/ibm-adarsh/s390x-acpi-fix/settings

### Error: "Repository not found"

- Verify the repository exists: https://github.com/ibm-adarsh/s390x-acpi-fix
- Check the remote URL: `git remote -v`

## Quick Command Summary

```bash
# Navigate to project
cd /Users/adarshyadav/release/s390x-acpi-fix

# Add remote
git remote add origin https://github.com/ibm-adarsh/s390x-acpi-fix.git

# Push
git push -u origin main
```

## After Successful Push

1. ✅ Repository is live on GitHub
2. ✅ Code is backed up
3. ✅ Ready to share with team
4. ✅ Ready to test on a311lp22

Next: Test the fix locally before announcing!