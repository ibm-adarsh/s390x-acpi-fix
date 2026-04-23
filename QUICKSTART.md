# Quick Start Guide

Complete setup in 5 minutes on any RHEL 9 s390x host.

## Prerequisites

- RHEL 9 (or compatible) on s390x architecture
- libvirt and QEMU installed
- Root access
- gcc compiler

## Installation Commands

Copy and paste these commands on your s390x host:

```bash
# 1. Clone the repository
git clone https://github.com/ibm-adarsh/s390x-acpi-fix.git
cd s390x-acpi-fix

# 2. Compile the library (simplified version, no libvirt-devel needed)
gcc -shared -fPIC -o /tmp/libvirt-acpi-fix.so -xc - -ldl << 'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

typedef void* virConnectPtr;
typedef void* virDomainPtr;
typedef virDomainPtr (*orig_virDomainDefineXML_t)(virConnectPtr, const char*);

static char* strip_acpi(const char *xml) {
    if (!strstr(xml, "arch='s390x'") && !strstr(xml, "arch=\"s390x\"")) return strdup(xml);
    if (!strstr(xml, "<acpi/>") && !strstr(xml, "<acpi />")) return strdup(xml);
    
    fprintf(stderr, "[libvirt-acpi-fix] Stripping ACPI from s390x domain\n");
    char *result = malloc(strlen(xml) + 1);
    const char *src = xml; char *dst = result;
    
    while (*src) {
        if (strncmp(src, "<acpi/>", 7) == 0) { src += 7; while (*src == ' ' || *src == '\n') src++; }
        else if (strncmp(src, "<acpi />", 8) == 0) { src += 8; while (*src == ' ' || *src == '\n') src++; }
        else *dst++ = *src++;
    }
    *dst = '\0';
    return result;
}

virDomainPtr virDomainDefineXML(virConnectPtr conn, const char *xml) {
    static orig_virDomainDefineXML_t orig = NULL;
    if (!orig) orig = (orig_virDomainDefineXML_t)dlsym(RTLD_NEXT, "virDomainDefineXML");
    char *clean = strip_acpi(xml);
    virDomainPtr result = orig(conn, clean);
    free(clean);
    return result;
}
EOF

# 3. Test the fix (optional but recommended)
bash test-acpi-issue-locally.sh

# 4. Deploy to production
sudo cp /tmp/libvirt-acpi-fix.so /usr/local/lib64/
sudo mkdir -p /etc/systemd/system/libvirtd.service.d
echo -e "[Service]\nEnvironment=\"LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so\"" | sudo tee /etc/systemd/system/libvirtd.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart libvirtd

# 5. Verify it's working
sudo systemctl status libvirtd | head -20
```

## Verification

Test that the fix is active:

```bash
# Create test domain with ACPI
cat > /tmp/test-fix.xml <<'EOF'
<domain type='kvm'>
  <name>test-acpi-fix</name>
  <memory unit='KiB'>524288</memory>
  <vcpu>1</vcpu>
  <os>
    <type arch='s390x' machine='s390-ccw-virtio-rhel9.6.0'>hvm</type>
  </os>
  <features>
    <acpi/>
  </features>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
  </devices>
</domain>
EOF

# This should now succeed (would fail without the fix)
virsh define /tmp/test-fix.xml

# Verify ACPI was stripped
virsh dumpxml test-acpi-fix | grep -i acpi || echo "✅ Fix is working - no ACPI found!"

# Cleanup
virsh undefine test-acpi-fix
rm /tmp/test-fix.xml
```

## Expected Output

```
[libvirt-acpi-fix] Stripping ACPI from s390x domain
Domain 'test-acpi-fix' defined from /tmp/test-fix.xml
✅ Fix is working - no ACPI found!
```

## Troubleshooting

### If compilation fails:

```bash
# Install gcc
dnf install -y gcc

# Try compilation again
```

### If libvirtd won't start:

```bash
# Check logs
journalctl -u libvirtd -n 50

# Check SELinux
getenforce
# If Enforcing, temporarily disable for testing:
setenforce 0
systemctl restart libvirtd
# Re-enable after testing:
setenforce 1
```

### If fix doesn't work:

```bash
# Verify library exists
ls -la /usr/local/lib64/libvirt-acpi-fix.so

# Verify systemd override
cat /etc/systemd/system/libvirtd.service.d/override.conf

# Check if libvirtd sees LD_PRELOAD
cat /proc/$(pgrep libvirtd)/environ | tr '\0' '\n' | grep LD_PRELOAD
```

## What This Fixes

- ✅ OpenShift worker node creation on s390x
- ✅ terraform-provider-libvirt domains on s390x
- ✅ Any libvirt domain with ACPI on s390x RHEL 9

## Uninstall

To remove the fix:

```bash
# Remove systemd override
sudo rm /etc/systemd/system/libvirtd.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart libvirtd

# Remove library (optional)
sudo rm /usr/local/lib64/libvirt-acpi-fix.so
```

## More Information

- **Full documentation**: See [README.md](README.md)
- **Architecture details**: See [DEPLOYMENT-ARCHITECTURE.md](DEPLOYMENT-ARCHITECTURE.md)
- **Testing guide**: See [TEST-ON-HOST.md](TEST-ON-HOST.md)
- **Issue analysis**: See [COMPLETE-ISSUE-SUMMARY.md](COMPLETE-ISSUE-SUMMARY.md)

## Support

- GitHub Issues: https://github.com/ibm-adarsh/s390x-acpi-fix/issues
- Repository: https://github.com/ibm-adarsh/s390x-acpi-fix

## Time Required

- Compilation: ~30 seconds
- Testing: ~2 minutes
- Deployment: ~1 minute
- **Total: ~5 minutes**