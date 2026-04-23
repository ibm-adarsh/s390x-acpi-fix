# GitHub Setup Instructions

## Create Repository on GitHub

1. **Go to GitHub**: https://github.com/new

2. **Repository Settings**:
   - Repository name: `s390x-acpi-fix`
   - Description: `LD_PRELOAD library to fix ACPI incompatibility for s390x domains on RHEL 9 / QEMU 9.x`
   - Visibility: Public
   - ✅ Add README (skip - we already have one)
   - ✅ Add .gitignore (skip - we already have one)
   - ✅ Choose a license (skip - we already have MIT)

3. **Click "Create repository"**

## Push to GitHub

Once the repository is created, run these commands from the `s390x-acpi-fix` directory:

```bash
cd s390x-acpi-fix

# Add your GitHub repository as remote
git remote add origin https://github.com/ibm-adarsh/s390x-acpi-fix.git

# Push to GitHub
git push -u origin main
```

## Alternative: Using SSH

If you prefer SSH:

```bash
cd s390x-acpi-fix

# Add remote with SSH
git remote add origin git@github.com:ibm-adarsh/s390x-acpi-fix.git

# Push to GitHub
git push -u origin main
```

## Verify

After pushing, visit:
https://github.com/ibm-adarsh/s390x-acpi-fix

You should see:
- ✅ README.md displayed on the main page
- ✅ 11 files in the repository
- ✅ MIT License badge
- ✅ Initial commit message

## Add Topics (Optional)

On GitHub, add these topics to make the repository discoverable:
- `s390x`
- `libvirt`
- `rhel9`
- `qemu`
- `acpi`
- `openshift`
- `ld-preload`
- `workaround`

## Enable GitHub Pages (Optional)

To create a documentation site:

1. Go to repository Settings → Pages
2. Source: Deploy from a branch
3. Branch: main / (root)
4. Save

Your documentation will be available at:
https://ibm-adarsh.github.io/s390x-acpi-fix/

## Create Release (After Testing)

Once you've tested the fix on a311lp22:

1. Go to Releases → Create a new release
2. Tag: `v1.0.0`
3. Title: `v1.0.0 - Initial Release`
4. Description:
   ```
   First stable release of the s390x ACPI fix for libvirt on RHEL 9.
   
   ## What's Included
   - LD_PRELOAD library to strip ACPI from s390x domains
   - Comprehensive testing scripts
   - Deployment documentation
   
   ## Tested On
   - RHEL 9.6
   - libvirt 10.10.0
   - QEMU 9.1.0
   - s390x architecture
   
   ## Installation
   See README.md for installation instructions.
   ```
5. Attach the compiled `libvirt-acpi-fix.so` (after building)
6. Publish release

## Repository Structure

```
s390x-acpi-fix/
├── README.md                          # Main documentation
├── LICENSE                            # MIT License
├── Makefile                           # Build system
├── .gitignore                         # Git ignore rules
├── libvirt-preload-acpi-fix.c        # Core library source
├── compile-and-test-preload.sh       # Build & test script
├── test-acpi-issue-locally.sh        # Issue reproduction
├── QUICK-LOCAL-TEST.md               # Testing guide
├── DEPLOYMENT-ARCHITECTURE.md        # Architecture docs
├── research-libvirt-hooks.sh         # Research notes
└── test-virsh-create-workaround.sh   # Alternative approaches
```

## Maintenance

### Update README badges (optional)

Add to the top of README.md:

```markdown
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-s390x-blue.svg)](https://github.com/ibm-adarsh/s390x-acpi-fix)
[![RHEL](https://img.shields.io/badge/RHEL-9-red.svg)](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)
```

### Enable Issues

Go to Settings → Features → ✅ Issues

This allows users to report problems or ask questions.

### Add CONTRIBUTING.md (optional)

Create guidelines for contributions:

```markdown
# Contributing

This is a workaround project. The real fixes should go upstream:
- terraform-provider-libvirt
- machine-api-operator

However, improvements to the workaround are welcome:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on RHEL 9 s390x
5. Submit a pull request
```

## Share the Repository

Once published, share with:
- OpenShift CI team
- Platform infrastructure team
- RHEL s390x community
- terraform-provider-libvirt maintainers (as reference for upstream fix)

## Repository URL

After setup, your repository will be at:
**https://github.com/ibm-adarsh/s390x-acpi-fix**

Clone with:
```bash
git clone https://github.com/ibm-adarsh/s390x-acpi-fix.git