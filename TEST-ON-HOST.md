# Testing on a311lp22 (s390x Host)

After pushing to GitHub, test the fix on your s390x host.

## Step 1: SSH to the Host

```bash
ssh root@a311lp22
```

## Step 2: Clone the Repository

```bash
cd /root
git clone https://github.com/ibm-adarsh/s390x-acpi-fix.git
cd s390x-acpi-fix
```

## Step 3: Run the Test Script

This will compile and test the LD_PRELOAD library:

```bash
bash compile-and-test-preload.sh
```

## Expected Output

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
```

## Step 4: If Test Succeeds - Deploy to Production

### Option A: Using Makefile (Recommended)

```bash
# Build
make

# Install system-wide
sudo make install

# Configure libvirtd
sudo mkdir -p /etc/systemd/system/libvirtd.service.d
sudo cat > /etc/systemd/system/libvirtd.service.d/override.conf <<EOF
[Service]
Environment="LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so"
EOF

# Restart libvirtd
sudo systemctl daemon-reload
sudo systemctl restart libvirtd
```

### Option B: Manual Installation

```bash
# Compile
gcc -shared -fPIC -o libvirt-acpi-fix.so libvirt-acpi-fix.c -ldl -lvirt

# Copy to system location
sudo cp libvirt-acpi-fix.so /usr/local/lib64/

# Configure libvirtd
sudo mkdir -p /etc/systemd/system/libvirtd.service.d
sudo cat > /etc/systemd/system/libvirtd.service.d/override.conf <<EOF
[Service]
Environment="LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so"
EOF

# Restart libvirtd
sudo systemctl daemon-reload
sudo systemctl restart libvirtd
```

## Step 5: Verify libvirtd is Running with LD_PRELOAD

```bash
# Check libvirtd status
systemctl status libvirtd

# Verify LD_PRELOAD is set
sudo cat /proc/$(pgrep libvirtd)/environ | tr '\0' '\n' | grep LD_PRELOAD
```

Expected output:
```
LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so
```

## Step 6: Test with Real Domain

Create a test domain to verify the fix works:

```bash
# Create test XML with ACPI
cat > /tmp/test-real-domain.xml <<'EOF'
<domain type='kvm'>
  <name>test-acpi-fix-real</name>
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

# Try to define it (should succeed now)
virsh define /tmp/test-real-domain.xml

# Verify ACPI was stripped
virsh dumpxml test-acpi-fix-real | grep acpi

# Cleanup
virsh undefine test-acpi-fix-real
rm /tmp/test-real-domain.xml
```

## Step 7: Test OpenShift Worker Creation

Now that libvirtd has the fix, re-run your failing CI job:

```bash
# The CI job that was failing should now succeed
# Worker nodes should be created without ACPI errors
```

## Troubleshooting

### If compilation fails:

```bash
# Install dependencies
dnf install -y gcc libvirt-devel

# Try again
bash compile-and-test-preload.sh
```

### If libvirtd won't start:

```bash
# Check logs
journalctl -u libvirtd -n 50

# Check for SELinux issues
getenforce
# If Enforcing, temporarily disable for testing:
setenforce 0
systemctl restart libvirtd
# Re-enable after testing:
setenforce 1
```

### If LD_PRELOAD isn't working:

```bash
# Verify library exists
ls -la /usr/local/lib64/libvirt-acpi-fix.so

# Verify systemd override
cat /etc/systemd/system/libvirtd.service.d/override.conf

# Check if libvirtd sees it
sudo cat /proc/$(pgrep libvirtd)/environ | tr '\0' '\n' | grep LD_PRELOAD
```

## Quick Command Summary

```bash
# On a311lp22
ssh root@a311lp22

# Clone and test
git clone https://github.com/ibm-adarsh/s390x-acpi-fix.git
cd s390x-acpi-fix
bash compile-and-test-preload.sh

# If successful, deploy
make
sudo make install
sudo mkdir -p /etc/systemd/system/libvirtd.service.d
echo -e "[Service]\nEnvironment=\"LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so\"" | sudo tee /etc/systemd/system/libvirtd.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart libvirtd

# Verify
systemctl status libvirtd
```

## Success Criteria

✅ Test script shows "SUCCESS" for LD_PRELOAD test
✅ libvirtd starts with LD_PRELOAD configured
✅ Test domain with ACPI can be defined
✅ Stored domain XML has no `<acpi/>` tag
✅ OpenShift worker nodes can be created

## Next Steps After Success

1. Deploy to all orange zone s390x KVM hosts
2. Re-run failing CI jobs
3. Monitor for any issues
4. Document the deployment in your team wiki
5. File upstream bugs (see BUG-FILING-GUIDE.md)