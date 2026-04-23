# LD_PRELOAD ACPI Fix - Deployment Architecture

## Overview

The LD_PRELOAD solution requires deployment at **TWO different levels** depending on what's being fixed:

---

## 1. Master Nodes (Installer) - Already Fixed ✅

**Location**: CI job container (openshift-install pod)

**Current Solution**: XSLT transformation in installer step
- File: `ci-operator/step-registry/ipi/install/libvirt/install/ipi-install-libvirt-install-commands.sh`
- Method: Strips ACPI from terraform files before `terraform apply`
- Status: **Working** (fixed in your PR)

**No LD_PRELOAD needed** - XSLT solution is sufficient for masters.

---

## 2. Worker Nodes (machine-api-operator) - Needs Fix ❌

**Location**: KVM host (e.g., a311lp22) where machine-api-operator runs

**Problem**: 
- machine-api-operator runs as a pod **inside the cluster**
- It makes libvirt API calls to the **host's libvirtd** via TCP/socket
- The operator is compiled Go code - can't modify its behavior from CI

**Solution Architecture**:

```
┌─────────────────────────────────────────────────────────┐
│ KVM Host (a311lp22)                                     │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ libvirtd (listening on socket/TCP)               │  │
│  │                                                   │  │
│  │ LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so │  │
│  │                                                   │  │
│  │ Intercepts: virDomainDefineXML()                 │  │
│  │ Action: Strip <acpi/> from s390x domains         │  │
│  └──────────────────────────────────────────────────┘  │
│                          ▲                              │
│                          │ libvirt API calls            │
│                          │                              │
│  ┌───────────────────────┴──────────────────────────┐  │
│  │ OpenShift Cluster (running on this host)        │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │ machine-api-operator pod                    │ │  │
│  │  │                                             │ │  │
│  │  │ Creates worker VMs via libvirt API          │ │  │
│  │  │ (sends XML with <acpi/> - unmodified)       │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Deployment Steps

### Step 1: Test on a311lp22 (One-time)

Run on the KVM host to verify the fix works:

```bash
# On a311lp22
bash compile-and-test-preload.sh
```

This compiles and tests the LD_PRELOAD library locally.

---

### Step 2: Deploy to Production KVM Hosts

**This is an INFRASTRUCTURE task**, not a release repo change.

The platform infrastructure team needs to:

1. **Compile the library** (on a RHEL 9 build host):
   ```bash
   gcc -shared -fPIC -o libvirt-acpi-fix.so libvirt-preload-acpi-fix.c -ldl -lvirt
   ```

2. **Deploy to all orange zone s390x KVM hosts**:
   ```bash
   # Copy to each KVM host
   scp libvirt-acpi-fix.so root@a311lp22:/usr/local/lib64/
   scp libvirt-acpi-fix.so root@a311lp23:/usr/local/lib64/
   # ... repeat for all s390x KVM hosts
   ```

3. **Configure libvirtd to use LD_PRELOAD**:
   
   Edit `/etc/systemd/system/libvirtd.service.d/override.conf`:
   ```ini
   [Service]
   Environment="LD_PRELOAD=/usr/local/lib64/libvirt-acpi-fix.so"
   ```

4. **Restart libvirtd**:
   ```bash
   systemctl daemon-reload
   systemctl restart libvirtd
   ```

---

## What Goes in the Release Repo?

**Nothing for the LD_PRELOAD solution!**

The LD_PRELOAD library is a **host-level fix**, not a CI configuration change.

### What's Already in Release Repo (for masters):
- ✅ `ci-operator/step-registry/ipi/install/libvirt/install/ipi-install-libvirt-install-commands.sh`
  - Enhanced `ipi_install_xsltproc_user_local_stream9()` function
  - XSLT transformation to strip ACPI from master nodes

### What's NOT in Release Repo:
- ❌ LD_PRELOAD library (deployed to KVM hosts by infra team)
- ❌ libvirtd configuration (managed by infra team)

---

## Alternative: If You Want CI-Managed Deployment

If you want the CI job to deploy the LD_PRELOAD fix automatically, you would need:

1. **Pre-built library in a container image**:
   ```dockerfile
   FROM registry.ci.openshift.org/ocp/builder:rhel-9-base
   COPY libvirt-acpi-fix.so /usr/local/lib64/
   ```

2. **CI step to deploy to host** (requires privileged access):
   ```bash
   # In a CI step with host access
   scp /usr/local/lib64/libvirt-acpi-fix.so root@$LIBVIRT_HOST:/usr/local/lib64/
   ssh root@$LIBVIRT_HOST "systemctl restart libvirtd"
   ```

3. **Security concerns**:
   - CI jobs shouldn't have root SSH access to infrastructure hosts
   - This violates security boundaries
   - **Not recommended**

---

## Recommended Approach

### Short-term (Immediate):
1. **Infra team deploys LD_PRELOAD** to orange zone s390x KVM hosts
2. **Test with one CI job run** to verify workers can be created
3. **Roll out to all s390x KVM hosts** if successful

### Long-term (6-12 months):
1. **File upstream bugs**:
   - terraform-provider-libvirt (GitHub)
   - machine-api-operator (Jira)
2. **Wait for fixes** to be merged and released
3. **Remove LD_PRELOAD workaround** once upstream fixes are available

---

## Summary

| Component | Fix Location | Deployment Method | Status |
|-----------|--------------|-------------------|--------|
| **Master nodes** | CI job container | XSLT in installer step | ✅ Fixed |
| **Worker nodes** | KVM host (libvirtd) | LD_PRELOAD library | ❌ Needs infra team |

**Action Required**: Platform infrastructure team must deploy LD_PRELOAD to KVM hosts.

**No changes needed in release repo** for the worker node fix.