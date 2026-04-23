#!/bin/bash
#
# Script to reproduce and test the s390x ACPI issue locally
# Run on: a311lp22 (RHEL 9, libvirt 10.10.0, QEMU 9.1.0)
#

set -e

echo "=========================================="
echo "s390x ACPI Issue - Local Reproduction"
echo "=========================================="
echo ""

# Step 1: Create test domain XML WITH ACPI (this will fail)
echo "Step 1: Creating test domain XML with ACPI..."
cat > /tmp/test-s390x-with-acpi.xml <<'EOF'
<domain type='kvm'>
  <name>test-s390x-acpi-fail</name>
  <uuid>12345678-1234-1234-1234-123456789abc</uuid>
  <memory unit='KiB'>1048576</memory>
  <currentMemory unit='KiB'>1048576</currentMemory>
  <vcpu placement='static'>1</vcpu>
  <os>
    <type arch='s390x' machine='s390-ccw-virtio-rhel9.6.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
  </features>
  <cpu mode='host-model' check='partial'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <controller type='pci' index='0' model='pci-root'/>
    <console type='pty'>
      <target type='sclp'/>
    </console>
    <memballoon model='virtio'/>
  </devices>
</domain>
EOF

echo "Created: /tmp/test-s390x-with-acpi.xml"
echo ""

# Step 2: Try to define domain (this WILL FAIL)
echo "Step 2: Attempting to define domain WITH ACPI (this should FAIL)..."
echo "Command: virsh define /tmp/test-s390x-with-acpi.xml"
echo ""

if virsh define /tmp/test-s390x-with-acpi.xml 2>&1; then
    echo "❌ UNEXPECTED: Domain defined successfully (should have failed!)"
    virsh undefine test-s390x-acpi-fail
else
    echo "✅ EXPECTED: Domain definition FAILED with ACPI error"
    echo ""
    echo "This is the error we're trying to fix!"
fi

echo ""
echo "=========================================="
echo ""

# Step 3: Create test domain XML WITHOUT ACPI (this will succeed)
echo "Step 3: Creating test domain XML WITHOUT ACPI..."
cat > /tmp/test-s390x-without-acpi.xml <<'EOF'
<domain type='kvm'>
  <name>test-s390x-no-acpi-success</name>
  <uuid>87654321-4321-4321-4321-cba987654321</uuid>
  <memory unit='KiB'>1048576</memory>
  <currentMemory unit='KiB'>1048576</currentMemory>
  <vcpu placement='static'>1</vcpu>
  <os>
    <type arch='s390x' machine='s390-ccw-virtio-rhel9.6.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <!-- NO ACPI HERE -->
  </features>
  <cpu mode='host-model' check='partial'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <controller type='pci' index='0' model='pci-root'/>
    <console type='pty'>
      <target type='sclp'/>
    </console>
    <memballoon model='virtio'/>
  </devices>
</domain>
EOF

echo "Created: /tmp/test-s390x-without-acpi.xml"
echo ""

# Step 4: Try to define domain (this WILL SUCCEED)
echo "Step 4: Attempting to define domain WITHOUT ACPI (this should SUCCEED)..."
echo "Command: virsh define /tmp/test-s390x-without-acpi.xml"
echo ""

if virsh define /tmp/test-s390x-without-acpi.xml 2>&1; then
    echo "✅ SUCCESS: Domain defined successfully without ACPI"
    echo ""
    echo "Verifying no ACPI in domain XML..."
    if virsh dumpxml test-s390x-no-acpi-success | grep -i acpi; then
        echo "❌ Found ACPI (unexpected)"
    else
        echo "✅ No ACPI found (correct)"
    fi
    echo ""
    echo "Cleaning up..."
    virsh undefine test-s390x-no-acpi-success
else
    echo "❌ UNEXPECTED: Domain definition failed"
fi

echo ""
echo "=========================================="
echo "Summary:"
echo "=========================================="
echo ""
echo "The issue is clear:"
echo "  - Domain WITH <acpi/> → FAILS on RHEL 9 / QEMU 9.x"
echo "  - Domain WITHOUT <acpi/> → SUCCEEDS"
echo ""
echo "This is why OpenShift worker nodes fail to create!"
echo ""

# Made with Bob

