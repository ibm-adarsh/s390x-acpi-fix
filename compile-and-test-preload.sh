#!/bin/bash
#
# Compile and test the LD_PRELOAD library for ACPI stripping
#

set -e

echo "=========================================="
echo "LD_PRELOAD ACPI Fix - Compile and Test"
echo "=========================================="
echo ""

echo "Step 1: Installing build dependencies..."
echo "-----------------------------------------"

# Check if gcc and libvirt-devel are available
if ! command -v gcc &> /dev/null; then
    echo "Installing gcc..."
    dnf install -y gcc 2>&1 | tail -5
fi

if ! rpm -q libvirt-devel &> /dev/null; then
    echo "Installing libvirt-devel..."
    dnf install -y libvirt-devel 2>&1 | tail -5
fi

echo "✅ Build dependencies ready"
echo ""

echo "Step 2: Compiling LD_PRELOAD library..."
echo "----------------------------------------"

gcc -shared -fPIC -o /tmp/libvirt-acpi-fix.so libvirt-preload-acpi-fix.c -ldl -lvirt

if [[ $? -eq 0 ]]; then
    echo "✅ Compiled successfully: /tmp/libvirt-acpi-fix.so"
    ls -lh /tmp/libvirt-acpi-fix.so
else
    echo "❌ Compilation failed!"
    exit 1
fi

echo ""
echo "Step 3: Testing LD_PRELOAD with virsh..."
echo "-----------------------------------------"

# Create test XML with ACPI
cat > /tmp/test-preload-acpi.xml <<'EOF'
<domain type='kvm'>
  <name>test-preload-acpi</name>
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

echo "Input XML contains: <acpi/>"
echo ""

echo "Test A: WITHOUT LD_PRELOAD (should FAIL)..."
if virsh define /tmp/test-preload-acpi.xml 2>&1; then
    echo "❌ Unexpected: Domain defined without LD_PRELOAD"
    virsh undefine test-preload-acpi 2>&1 > /dev/null
else
    echo "✅ Expected: Domain definition failed (ACPI error)"
fi

echo ""
echo "Test B: WITH LD_PRELOAD (should SUCCEED)..."

if LD_PRELOAD=/tmp/libvirt-acpi-fix.so virsh define /tmp/test-preload-acpi.xml 2>&1; then
    echo ""
    echo "✅ SUCCESS: Domain defined with LD_PRELOAD!"
    echo ""
    
    echo "Verifying ACPI was stripped..."
    if virsh dumpxml test-preload-acpi | grep -q "<acpi/>"; then
        echo "❌ ACPI still present in stored XML"
        echo "This means the library didn't work as expected."
    else
        echo "✅ VERIFIED: ACPI successfully stripped!"
        echo ""
        echo "Domain XML features section:"
        virsh dumpxml test-preload-acpi | sed -n '/<features>/,/<\/features>/p' || echo "(No features section)"
    fi
    
    # Cleanup
    virsh undefine test-preload-acpi 2>&1 > /dev/null
    
else
    echo "❌ FAILED: Domain definition still failed with LD_PRELOAD"
    echo ""
    echo "Possible reasons:"
    echo "  1. Library not intercepting correctly"
    echo "  2. virsh uses different API calls"
    echo "  3. Compilation issues"
fi

rm -f /tmp/test-preload-acpi.xml

echo ""
echo "=========================================="
echo "Step 4: Testing with Python libvirt API"
echo "=========================================="
echo ""

echo "Creating Python test script..."

cat > /tmp/test-preload-python.py << 'PYEOF'
#!/usr/bin/env python3
import libvirt
import sys

xml = """
<domain type='kvm'>
  <name>test-python-preload</name>
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
"""

try:
    conn = libvirt.open('qemu:///system')
    print("Connected to libvirt")
    
    print("Attempting to define domain with ACPI...")
    dom = conn.defineXML(xml)
    print("✅ SUCCESS: Domain defined!")
    
    # Check if ACPI was stripped
    stored_xml = dom.XMLDesc(0)
    if '<acpi/>' in stored_xml:
        print("❌ ACPI still present in stored XML")
    else:
        print("✅ ACPI successfully stripped!")
    
    dom.undefine()
    conn.close()
    sys.exit(0)
    
except libvirt.libvirtError as e:
    print(f"❌ FAILED: {e}")
    sys.exit(1)
PYEOF

chmod +x /tmp/test-preload-python.py

echo "Test C: Python WITHOUT LD_PRELOAD (should FAIL)..."
python3 /tmp/test-preload-python.py 2>&1 || echo "Expected failure"

echo ""
echo "Test D: Python WITH LD_PRELOAD (should SUCCEED)..."
LD_PRELOAD=/tmp/libvirt-acpi-fix.so python3 /tmp/test-preload-python.py 2>&1

echo ""
echo "=========================================="
echo "Summary and Deployment"
echo "=========================================="
echo ""

if [[ -f /tmp/libvirt-acpi-fix.so ]]; then
    echo "✅ Library compiled: /tmp/libvirt-acpi-fix.so"
    echo ""
    echo "To deploy system-wide:"
    echo ""
    echo "1. Copy library to system location:"
    echo "   cp /tmp/libvirt-acpi-fix.so /usr/local/lib64/"
    echo ""
    echo "2. Configure LD_PRELOAD for machine-api-operator:"
    echo "   Edit the operator deployment to add:"
    echo "   env:"
    echo "     - name: LD_PRELOAD"
    echo "       value: /usr/local/lib64/libvirt-acpi-fix.so"
    echo ""
    echo "3. Or configure system-wide in /etc/ld.so.preload:"
    echo "   echo '/usr/local/lib64/libvirt-acpi-fix.so' >> /etc/ld.so.preload"
    echo ""
    echo "⚠️  WARNING: System-wide LD_PRELOAD affects ALL processes!"
    echo "   Only use for machine-api-operator specifically."
    echo ""
else
    echo "❌ Library not found - compilation may have failed"
fi

echo ""
echo "Alternative: Use LD_PRELOAD in systemd service"
echo "-----------------------------------------------"
echo ""
echo "For services managed by systemd, add to service file:"
echo ""
echo "[Service]"
echo "Environment=\"LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so\""
echo ""

# Made with Bob
