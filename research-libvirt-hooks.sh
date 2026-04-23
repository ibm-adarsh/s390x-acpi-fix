#!/bin/bash
#
# Research all possible libvirt hook mechanisms
#

echo "=========================================="
echo "Researching Libvirt Hook Mechanisms"
echo "=========================================="
echo ""

echo "1. Standard QEMU Hook Locations:"
echo "---------------------------------"
echo "Checking for hook directories and files..."
echo ""

for hook_path in \
    /etc/libvirt/hooks/qemu \
    /etc/libvirt/hooks/daemon \
    /etc/libvirt/hooks/network \
    /etc/libvirt/hooks/lxc \
    /usr/libexec/libvirt/hooks/qemu \
    /usr/local/libexec/libvirt/hooks/qemu
do
    if [[ -e "$hook_path" ]]; then
        echo "✅ Found: $hook_path"
        ls -la "$hook_path"
    else
        echo "❌ Not found: $hook_path"
    fi
done

echo ""
echo "2. Libvirt Hook Operations (from man libvirt-hooks):"
echo "-----------------------------------------------------"
cat << 'EOF'
QEMU hooks are called with these operations:
  - prepare:  Before domain starts (XML on stdin)
  - start:    After domain starts
  - started:  After domain fully started
  - stopped:  After domain stops
  - release:  After domain released
  - migrate:  During migration
  - restore:  During restore
  - reconnect: When libvirtd reconnects to running domain
  - attach:   When attaching to existing domain

⚠️  CRITICAL: None of these are called during 'virsh define'!
EOF

echo ""
echo "3. Alternative Hook Mechanisms:"
echo "--------------------------------"
echo ""

echo "A. Libvirt NSS (Name Service Switch) Module:"
echo "   - Not applicable for XML modification"
echo ""

echo "B. Libvirt Storage Pool Hooks:"
echo "   - Not applicable for domain XML"
echo ""

echo "C. Libvirt Network Hooks:"
echo "   - Not applicable for domain XML"
echo ""

echo "D. QEMU Namespace Hooks:"
echo "   - Only for container/namespace setup"
echo ""

echo "E. Libvirt Domain XML Validation:"
echo "   - Uses RelaxNG schemas, not hooks"
echo "   - Located in: /usr/share/libvirt/schemas/"
ls -la /usr/share/libvirt/schemas/domain*.rng 2>/dev/null | head -5 || echo "   (schemas not found)"
echo ""

echo "4. Checking Libvirt Configuration for Hook Settings:"
echo "-----------------------------------------------------"
grep -i hook /etc/libvirt/libvirtd.conf 2>/dev/null || echo "(No hook settings in libvirtd.conf)"
echo ""

echo "5. Testing Hook Execution Timing:"
echo "----------------------------------"
echo "Creating a test hook with logging..."

cat > /tmp/test-hook-timing.sh << 'HOOKEOF'
#!/bin/bash
GUEST_NAME="$1"
OPERATION="$2"
SUB_OPERATION="$3"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Hook called: guest=$GUEST_NAME op=$OPERATION sub=$SUB_OPERATION" >> /tmp/libvirt-hook.log

# Read XML from stdin
XML=$(cat)

# Log if XML contains ACPI
if echo "$XML" | grep -q "<acpi/>"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] XML contains ACPI" >> /tmp/libvirt-hook.log
fi

# Pass through XML unchanged for now
echo "$XML"
HOOKEOF

chmod +x /tmp/test-hook-timing.sh

# Backup existing hook if present
if [[ -f /etc/libvirt/hooks/qemu ]]; then
    cp /etc/libvirt/hooks/qemu /etc/libvirt/hooks/qemu.backup.$(date +%s)
    echo "✅ Backed up existing hook"
fi

# Install test hook
cp /tmp/test-hook-timing.sh /etc/libvirt/hooks/qemu
echo "✅ Installed test hook with logging"
echo ""

# Clear log
> /tmp/libvirt-hook.log

echo "6. Testing Hook Invocation:"
echo "---------------------------"
echo ""

# Test with define
echo "Test A: virsh define (expecting NO hook call)..."
cat > /tmp/test-define.xml <<'EOF'
<domain type='kvm'>
  <name>hook-test-define</name>
  <memory unit='KiB'>524288</memory>
  <vcpu>1</vcpu>
  <os>
    <type arch='s390x' machine='s390-ccw-virtio-rhel9.6.0'>hvm</type>
  </os>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/tmp/test-disk.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
  </devices>
</domain>
EOF

# Create dummy disk
qemu-img create -f qcow2 /tmp/test-disk.qcow2 1G 2>&1 > /dev/null

virsh define /tmp/test-define.xml 2>&1 > /dev/null || true

echo "Hook log after define:"
cat /tmp/libvirt-hook.log || echo "(No log entries - hook not called)"
echo ""

# Test with start
echo "Test B: virsh start (expecting hook call)..."
> /tmp/libvirt-hook.log

timeout 3 virsh start hook-test-define 2>&1 > /dev/null || true

echo "Hook log after start:"
cat /tmp/libvirt-hook.log || echo "(No log entries)"
echo ""

# Cleanup
virsh destroy hook-test-define 2>&1 > /dev/null || true
virsh undefine hook-test-define 2>&1 > /dev/null || true
rm -f /tmp/test-disk.qcow2 /tmp/test-define.xml

echo ""
echo "=========================================="
echo "Research Conclusions"
echo "=========================================="
echo ""
echo "Based on testing:"
echo ""
if [[ -s /tmp/libvirt-hook.log ]]; then
    echo "✅ Hook WAS called during domain operations"
    echo ""
    echo "Hook can intercept XML during:"
    grep "Hook called" /tmp/libvirt-hook.log | sed 's/^/  - /'
    echo ""
    echo "💡 INSIGHT: Hook works during 'start', not 'define'"
    echo ""
    echo "Possible workaround:"
    echo "  1. Allow 'virsh define' to fail initially (expected)"
    echo "  2. Use 'virsh create' instead of 'define + start'"
    echo "     (create = define + start in one operation)"
    echo "  3. Hook strips ACPI during 'prepare' phase of create"
    echo ""
else
    echo "❌ Hook was NOT called during any operation"
    echo ""
    echo "This suggests:"
    echo "  - Hook script has syntax error"
    echo "  - libvirtd not restarted after hook installation"
    echo "  - Hook permissions incorrect"
    echo ""
fi

echo "Next steps:"
echo "  1. Test 'virsh create' (define+start in one command)"
echo "  2. Check if hook can modify XML during 'prepare' phase"
echo "  3. Investigate libvirt API for pre-define hooks"
echo ""

# Made with Bob
