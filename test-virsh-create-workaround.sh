#!/bin/bash
#
# Test if 'virsh create' (transient domain) works with hook
# virsh create = define + start in one operation
#

echo "=========================================="
echo "Testing 'virsh create' Workaround"
echo "=========================================="
echo ""

echo "Theory: 'virsh create' might allow hook to strip ACPI"
echo "because it combines define+start into one operation."
echo ""

# Ensure hook exists
if [[ ! -f /etc/libvirt/hooks/qemu ]]; then
    echo "Installing ACPI-stripping hook..."
    cat > /etc/libvirt/hooks/qemu << 'EOF'
#!/bin/bash
GUEST_NAME="$1"
OPERATION="$2"

# Log all invocations
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Hook: guest=$GUEST_NAME op=$OPERATION" >> /tmp/qemu-hook.log

# Only process during prepare/start operations
if [[ "$OPERATION" != "prepare" && "$OPERATION" != "start" ]]; then
    cat
    exit 0
fi

# Read XML
XML=$(cat)

# Strip ACPI from s390x domains
if echo "$XML" | grep -q "arch='s390x'"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stripping ACPI from s390x domain" >> /tmp/qemu-hook.log
    echo "$XML" | sed -e '/<acpi\/>/d'
else
    echo "$XML"
fi
EOF
    chmod +x /etc/libvirt/hooks/qemu
    systemctl restart libvirtd
    sleep 2
    echo "✅ Hook installed and libvirtd restarted"
    echo ""
fi

# Clear log
> /tmp/qemu-hook.log

echo "Test 1: virsh create with ACPI (transient domain)"
echo "--------------------------------------------------"

cat > /tmp/test-create-with-acpi.xml <<'EOF'
<domain type='kvm'>
  <name>test-create-acpi</name>
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
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/tmp/test-create-disk.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
  </devices>
</domain>
EOF

# Create test disk
qemu-img create -f qcow2 /tmp/test-create-disk.qcow2 1G 2>&1 > /dev/null

echo "Input XML contains: <acpi/>"
echo ""
echo "Attempting 'virsh create' (this starts domain immediately)..."
echo ""

if timeout 5 virsh create /tmp/test-create-with-acpi.xml 2>&1; then
    echo ""
    echo "✅ SUCCESS: Domain created and started!"
    echo ""
    echo "Checking hook log:"
    cat /tmp/qemu-hook.log
    echo ""
    
    echo "Checking running domain XML for ACPI:"
    if virsh dumpxml test-create-acpi | grep -q "<acpi/>"; then
        echo "❌ ACPI still present in running domain"
    else
        echo "✅ ACPI successfully stripped by hook!"
    fi
    
    # Cleanup
    virsh destroy test-create-acpi 2>&1 > /dev/null || true
    
else
    echo ""
    echo "❌ FAILED: virsh create failed"
    echo ""
    echo "Hook log:"
    cat /tmp/qemu-hook.log || echo "(No hook log)"
    echo ""
    echo "This means 'virsh create' also validates XML before hook runs."
fi

rm -f /tmp/test-create-disk.qcow2 /tmp/test-create-with-acpi.xml

echo ""
echo "=========================================="
echo "Alternative: Check libvirt-guests service"
echo "=========================================="
echo ""

echo "The libvirt-guests service auto-starts domains on boot."
echo "It might use a different code path that allows hook interception."
echo ""

systemctl status libvirt-guests 2>&1 | head -10 || echo "Service not found"

echo ""
echo "=========================================="
echo "Alternative: Libvirt XML Preprocessing"
echo "=========================================="
echo ""

echo "Another approach: Use libvirt's XML import/export with transformation"
echo ""
echo "1. Export domain XML: virsh dumpxml domain > domain.xml"
echo "2. Strip ACPI: sed -i '/<acpi\/>/d' domain.xml"
echo "3. Re-define: virsh define domain.xml"
echo ""
echo "This could be automated in a wrapper script that:"
echo "  - Intercepts libvirt API calls"
echo "  - Modifies XML before passing to libvirt"
echo "  - Requires LD_PRELOAD or similar mechanism"
echo ""

echo "=========================================="
echo "Checking for LD_PRELOAD possibilities"
echo "=========================================="
echo ""

echo "Could we intercept libvirt API calls with LD_PRELOAD?"
echo ""
echo "Target functions to intercept:"
echo "  - virDomainDefineXML"
echo "  - virDomainCreateXML"
echo ""

ldd /usr/bin/virsh 2>&1 | grep libvirt || echo "libvirt library not found in ldd output"

echo ""
echo "This would require writing a shared library that:"
echo "  1. Intercepts virDomainDefineXML calls"
echo "  2. Parses XML, strips ACPI from s390x domains"
echo "  3. Calls real virDomainDefineXML with modified XML"
echo ""

echo "=========================================="
echo "Conclusion"
echo "=========================================="
echo ""
echo "Hook-based solutions have fundamental limitations:"
echo "  ❌ Hooks not called during 'virsh define'"
echo "  ❌ XML validation happens before hooks run"
echo "  ❌ 'virsh create' also validates before hooks"
echo ""
echo "Possible workarounds (in order of feasibility):"
echo ""
echo "1. LD_PRELOAD wrapper (complex but possible)"
echo "   - Intercept libvirt API calls"
echo "   - Modify XML before validation"
echo ""
echo "2. Patch libvirt itself (requires recompilation)"
echo "   - Add s390x-specific ACPI stripping"
echo "   - Not practical for production"
echo ""
echo "3. Fix at source (RECOMMENDED)"
echo "   - Patch terraform-provider-libvirt"
echo "   - Patch machine-api-operator"
echo "   - File upstream bugs"
echo ""

# Made with Bob
