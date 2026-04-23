# s390x ACPI Fix for Libvirt

A workaround for the ACPI incompatibility issue when running s390x domains on RHEL 9 / QEMU 9.x with libvirt.

## Problem

When migrating from RHEL 8 (QEMU 6.2.0) to RHEL 9 (QEMU 9.1.0), s390x libvirt domains fail to start with:

```
error: unsupported configuration: machine type 's390-ccw-virtio-rhel9.6.0' does not support ACPI
```

**Root Cause**: terraform-provider-libvirt and machine-api-operator incorrectly inject `<acpi/>` into s390x domain XML. QEMU 9.x correctly rejects this (s390x uses SCLP, not ACPI), while QEMU 6.x silently ignored it.

## Solution

This project provides an **LD_PRELOAD library** that intercepts libvirt API calls and automatically strips `<acpi/>` from s390x domains before they reach QEMU.

## Components

### Core Library
- **`libvirt-acpi-fix.c`** - LD_PRELOAD library that intercepts `virDomainDefineXML()` and `virDomainCreateXML()`

### Testing & Deployment
- **`compile-and-test-preload.sh`** - Compiles and tests the library
- **`test-acpi-issue-locally.sh`** - Reproduces the ACPI issue
- **`QUICK-LOCAL-TEST.md`** - Step-by-step testing guide

### Documentation
- **`DEPLOYMENT-ARCHITECTURE.md`** - Complete deployment architecture
- **`COMPLETE-ISSUE-SUMMARY.md`** - Comprehensive technical analysis
- **`BUG-FILING-GUIDE.md`** - Upstream bug filing instructions

### Research & Alternatives
- **`research-libvirt-hooks.sh`** - Why libvirt hooks don't work
- **`test-virsh-create-workaround.sh`** - Alternative approaches tested
- **`qemu-hook.sh`** - Non-working hook approach (for reference)

## Quick Start

### Test Locally (RHEL 9 / s390x)

```bash
# 1. Clone the repository
git clone https://github.com/ibm-adarsh/s390x-acpi-fix.git
cd s390x-acpi-fix

# 2. Run the test script
bash compile-and-test-preload.sh
```

### Expected Output

```
Test A: WITHOUT LD_PRELOAD (should FAIL)...
error: unsupported configuration: machine type 's390-ccw-virtio-rhel9.6.0' does not support ACPI
✅ Expected: Domain definition failed (ACPI error)

Test B: WITH LD_PRELOAD (should SUCCEED)...
[libvirt-acpi-fix] Stripping <acpi/> from s390x domain
Domain 'test-preload-acpi' defined from /tmp/test-preload-acpi.xml
✅ SUCCESS: Domain defined with LD_PRELOAD!
```

## Production Deployment

### For KVM Hosts (libvirtd)

1. **Compile the library**:
   ```bash
   gcc -shared -fPIC -o libvirt-acpi-fix.so libvirt-acpi-fix.c -ldl -lvirt
   ```

2. **Deploy to system**:
   ```bash
   cp libvirt-acpi-fix.so /usr/local/lib64/
   ```

3. **Configure libvirtd**:
   
   Create `/etc/systemd/system/libvirtd.service.d/override.conf`:
   ```ini
   [Service]
   Environment="LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so"
   ```

4. **Restart libvirtd**:
   ```bash
   systemctl daemon-reload
   systemctl restart libvirtd
   ```

### For OpenShift machine-api-operator

Add to operator deployment:
```yaml
env:
  - name: LD_PRELOAD
    value: /usr/local/lib64/libvirt-acpi-fix.so
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ KVM Host (RHEL 9 / s390x)                               │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ libvirtd                                         │  │
│  │ LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so │  │
│  │                                                   │  │
│  │ Intercepts: virDomainDefineXML()                 │  │
│  │ Action: Strip <acpi/> from s390x domains         │  │
│  └──────────────────────────────────────────────────┘  │
│                          ▲                              │
│                          │ libvirt API calls            │
│                          │                              │
│  ┌───────────────────────┴──────────────────────────┐  │
│  │ Clients (virsh, terraform, machine-api-operator) │  │
│  │ Send XML with <acpi/> (unmodified)               │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Use Cases

### 1. OpenShift IPI on s390x
- **Master nodes**: Fixed via XSLT in installer (see `ci-operator/` directory)
- **Worker nodes**: Fixed via LD_PRELOAD on KVM hosts (this project)

### 2. Standalone libvirt on RHEL 9 s390x
- Any libvirt client creating s390x domains with ACPI

### 3. Terraform with libvirt provider
- terraform-provider-libvirt incorrectly adds ACPI to all architectures

## Upstream Fixes

This is a **temporary workaround**. Permanent fixes are needed in:

1. **terraform-provider-libvirt** - Don't inject ACPI for s390x
   - Repository: https://github.com/dmacvicar/terraform-provider-libvirt
   - Issue: TBD (see BUG-FILING-GUIDE.md)

2. **machine-api-operator** - Don't inject ACPI for s390x
   - Repository: https://github.com/openshift/machine-api-operator
   - Issue: TBD (see BUG-FILING-GUIDE.md)

3. **openshift-installer** - Already has XSLT workaround
   - Repository: https://github.com/openshift/installer

## Testing

### Reproduce the Issue

```bash
bash test-acpi-issue-locally.sh
```

### Test the Fix

```bash
bash compile-and-test-preload.sh
```

### Manual Test

```bash
# Compile
gcc -shared -fPIC -o /tmp/libvirt-acpi-fix.so libvirt-acpi-fix.c -ldl -lvirt

# Test WITHOUT fix (fails)
virsh define domain-with-acpi.xml

# Test WITH fix (succeeds)
LD_PRELOAD=/tmp/libvirt-acpi-fix.so virsh define domain-with-acpi.xml
```

## Requirements

- RHEL 9 or compatible (Rocky Linux 9, AlmaLinux 9)
- s390x architecture
- libvirt 10.x
- QEMU 9.x
- gcc and libvirt-devel (for compilation)

## Limitations

- Only works for s390x architecture (by design)
- Requires LD_PRELOAD (may conflict with SELinux in enforcing mode)
- Temporary workaround until upstream fixes are available

## Contributing

This is a workaround project. The real fix should be in upstream projects:
- terraform-provider-libvirt
- machine-api-operator

See `BUG-FILING-GUIDE.md` for how to contribute upstream fixes.

## License

MIT License - See LICENSE file

## Author

Adarsh Yadav (@ibm-adarsh)

## Related Issues

- OpenShift CI: Migration from RHEL 8 to RHEL 9 s390x infrastructure
- QEMU 9.x: Stricter ACPI validation for s390x
- terraform-provider-libvirt: Incorrect ACPI injection

## Support

For issues or questions:
1. Check `COMPLETE-ISSUE-SUMMARY.md` for detailed technical analysis
2. Review `DEPLOYMENT-ARCHITECTURE.md` for deployment guidance
3. See `QUICK-LOCAL-TEST.md` for testing instructions
4. Open an issue on GitHub

## Acknowledgments

- OpenShift CI team for identifying the issue
- Platform infrastructure team for testing and deployment
- QEMU team for correct s390x ACPI validation