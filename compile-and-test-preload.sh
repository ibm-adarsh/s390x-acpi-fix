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

# Check if gcc is available
if ! command -v gcc &> /dev/null; then
    echo "Installing gcc..."
    dnf install -y gcc 2>&1 | tail -5
fi

# Check for libvirt development headers
# Try multiple package names (RHEL 9 uses different names)
if ! rpm -q libvirt-devel &> /dev/null && ! rpm -q libvirt-libs &> /dev/null; then
    echo "Installing libvirt development packages..."
    
    # Try libvirt-devel first (standard name)
    if dnf install -y libvirt-devel 2>&1 | tail -5; then
        echo "✅ Installed libvirt-devel"
    else
        # If that fails, try installing from available packages
        echo "Trying alternative package names..."
        
        # Search for available libvirt packages
        available_pkg=$(dnf list available 'libvirt*' 2>/dev/null | grep -E 'libvirt-devel|libvirt-libs' | head -1 | awk '{print $1}')
        
        if [[ -n "$available_pkg" ]]; then
            echo "Found: $available_pkg"
            dnf install -y "$available_pkg" 2>&1 | tail -5
        else
            echo "⚠️  Warning: Could not find libvirt-devel package"
            echo "Attempting to compile without it (may fail)..."
        fi
    fi
fi

# Check if libvirt.h is available
if [[ -f /usr/include/libvirt/libvirt.h ]]; then
    echo "✅ libvirt headers found"
elif [[ -f /usr/local/include/libvirt/libvirt.h ]]; then
    echo "✅ libvirt headers found in /usr/local"
else
    echo "❌ libvirt headers not found!"
    echo ""
    echo "Manual installation required:"
    echo "  1. Check available packages: dnf search libvirt"
    echo "  2. Install development package: dnf install -y <package-name>"
    echo ""
    echo "Common package names:"
    echo "  - libvirt-devel (RHEL/CentOS)"
    echo "  - libvirt-dev (Debian/Ubuntu)"
    echo "  - libvirt-libs (some RHEL 9 variants)"
    echo ""
    exit 1
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
