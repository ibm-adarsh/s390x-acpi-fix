# Quick Local Test on a311lp22

## Prerequisites
You're already on a311lp22 with:
- ✅ RHEL 9
- ✅ libvirt 10.10.0
- ✅ QEMU 9.1.0
- ✅ Root access

## Step-by-Step Test

### 1. Copy Files to a311lp22

```bash
# On your local machine, copy these files to a311lp22:
scp libvirt-preload-acpi-fix.c root@a311lp22:/tmp/
scp compile-and-test-preload.sh root@a311lp22:/tmp/
```

### 2. Run the Test Script

```bash
# SSH to a311lp22
ssh root@a311lp22

# Go to /tmp
cd /tmp

# Run the comprehensive test
bash compile-and-test-preload.sh
```

### 3. What the Script Does

The script will:

1. **Install dependencies** (gcc, libvirt-devel)
2. **Compile the library**: `libvirt-acpi-fix.so`
3. **Test WITHOUT LD_PRELOAD**:
   ```bash
   virsh define domain-with-acpi.xml
   # Expected: ❌ FAILS with ACPI error
   ```
4. **Test WITH LD_PRELOAD**:
   ```bash
   LD_PRELOAD=/tmp/libvirt-acpi-fix.so virsh define domain-with-acpi.xml
   # Expected: ✅ SUCCEEDS (ACPI stripped)
   ```
5. **Verify** the stored XML has no ACPI

### 4. Expected Output

```
==========================================
LD_PRELOAD ACPI Fix - Compile and Test
==========================================

Step 1: Installing build dependencies...
-----------------------------------------
✅ Build dependencies ready

Step 2: Compiling LD_PRELOAD library...
----------------------------------------
✅ Compiled successfully: /tmp/libvirt-acpi-fix.so
-rw-r--r--. 1 root root 18K Apr 23 10:10 /tmp/libvirt-acpi-fix.so

Step 3: Testing LD_PRELOAD with virsh...
-----------------------------------------
Input XML contains: <acpi/>

Test A: WITHOUT LD_PRELOAD (should FAIL)...
error: Failed to define domain from /tmp/test-preload-acpi.xml
error: unsupported configuration: machine type 's390-ccw-virtio-rhel9.6.0' does not support ACPI
✅ Expected: Domain definition failed (ACPI error)

Test B: WITH LD_PRELOAD (should SUCCEED)...
[libvirt-acpi-fix] LD_PRELOAD library loaded - will strip ACPI from s390x domains
[libvirt-acpi-fix] Stripping <acpi/> from s390x domain
Domain 'test-preload-acpi' defined from /tmp/test-preload-acpi.xml

✅ SUCCESS: Domain defined with LD_PRELOAD!

Verifying ACPI was stripped...
✅ VERIFIED: ACPI successfully stripped!

Domain XML features section:
(No features section)
```

### 5. Manual Test (Alternative)

If you want to test manually without the script:

```bash
# 1. Compile
gcc -shared -fPIC -o /tmp/libvirt-acpi-fix.so /tmp/libvirt-preload-acpi-fix.c -ldl -lvirt

# 2. Create test XML
cat > /tmp/test.xml <<'EOF'
<domain type='kvm'>
  <name>test-acpi</name>
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

# 3. Test WITHOUT LD_PRELOAD (will fail)
virsh define /tmp/test.xml
# Expected: error: unsupported configuration: machine type 's390-ccw-virtio-rhel9.6.0' does not support ACPI

# 4. Test WITH LD_PRELOAD (should work)
LD_PRELOAD=/tmp/libvirt-acpi-fix.so virsh define /tmp/test.xml
# Expected: Domain 'test-acpi' defined from /tmp/test.xml

# 5. Verify ACPI was stripped
virsh dumpxml test-acpi | grep acpi
# Expected: (no output - ACPI removed)

# 6. Cleanup
virsh undefine test-acpi
```

## Troubleshooting

### If compilation fails:

```bash
# Install missing dependencies
dnf install -y gcc libvirt-devel

# Try compiling again
gcc -shared -fPIC -o /tmp/libvirt-acpi-fix.so /tmp/libvirt-preload-acpi-fix.c -ldl -lvirt
```

### If LD_PRELOAD doesn't work:

```bash
# Check library was created
ls -lh /tmp/libvirt-acpi-fix.so

# Check for errors
LD_PRELOAD=/tmp/libvirt-acpi-fix.so virsh version 2>&1 | grep -i error

# Test library loading
LD_PRELOAD=/tmp/libvirt-acpi-fix.so bash -c 'echo "Library loaded"'
```

### If domain still fails with LD_PRELOAD:

This could mean:
1. The library isn't intercepting correctly
2. virsh uses a different code path
3. SELinux is blocking LD_PRELOAD

Check SELinux:
```bash
getenforce
# If Enforcing, try:
setenforce 0
# Test again, then re-enable:
setenforce 1
```

## Success Criteria

✅ **Test passes if**:
- WITHOUT LD_PRELOAD: Domain definition fails with ACPI error
- WITH LD_PRELOAD: Domain definition succeeds
- Stored XML has no `<acpi/>` tag

## Next Steps After Successful Test

If the test succeeds, you've proven the fix works! Then:

1. **Share results** with platform infrastructure team
2. **Request deployment** to all orange zone s390x KVM hosts
3. **Provide them**:
   - Compiled library: `/tmp/libvirt-acpi-fix.so`
   - Source code: `libvirt-preload-acpi-fix.c`
   - Deployment instructions: `DEPLOYMENT-ARCHITECTURE.md`

## Time Required

- Compilation: ~30 seconds
- Full test script: ~2-3 minutes
- Manual test: ~1 minute