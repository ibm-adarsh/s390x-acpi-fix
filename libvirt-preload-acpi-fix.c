/*
 * LD_PRELOAD library to strip ACPI from s390x domains
 * 
 * Compile:
 *   gcc -shared -fPIC -o libvirt-acpi-fix.so libvirt-preload-acpi-fix.c -ldl -lvirt
 * 
 * Usage:
 *   LD_PRELOAD=/path/to/libvirt-acpi-fix.so virsh define domain.xml
 *   LD_PRELOAD=/path/to/libvirt-acpi-fix.so machine-api-operator
 * 
 * This intercepts virDomainDefineXML and strips <acpi/> from s390x domains
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <libvirt/libvirt.h>

/* Function pointer for the real virDomainDefineXML */
typedef virDomainPtr (*orig_virDomainDefineXML_t)(virConnectPtr conn, const char *xml);

/*
 * Simple XML parser to check if domain is s390x and strip ACPI
 */
static char* strip_acpi_from_s390x(const char *xml) {
    /* Check if this is an s390x domain */
    if (strstr(xml, "arch='s390x'") == NULL && 
        strstr(xml, "arch=\"s390x\"") == NULL) {
        /* Not s390x, return original XML */
        return strdup(xml);
    }
    
    /* Check if XML contains ACPI */
    if (strstr(xml, "<acpi/>") == NULL && 
        strstr(xml, "<acpi />") == NULL) {
        /* No ACPI to strip */
        return strdup(xml);
    }
    
    /* Allocate buffer for modified XML */
    size_t len = strlen(xml);
    char *modified = malloc(len + 1);
    if (!modified) {
        return strdup(xml);
    }
    
    /* Simple approach: copy XML while skipping <acpi/> lines */
    const char *src = xml;
    char *dst = modified;
    
    while (*src) {
        /* Check for <acpi/> or <acpi /> */
        if (strncmp(src, "<acpi/>", 7) == 0) {
            fprintf(stderr, "[libvirt-acpi-fix] Stripping <acpi/> from s390x domain\n");
            src += 7;
            /* Skip whitespace after tag */
            while (*src == ' ' || *src == '\t' || *src == '\n' || *src == '\r') {
                src++;
            }
            continue;
        } else if (strncmp(src, "<acpi />", 8) == 0) {
            fprintf(stderr, "[libvirt-acpi-fix] Stripping <acpi /> from s390x domain\n");
            src += 8;
            /* Skip whitespace after tag */
            while (*src == ' ' || *src == '\t' || *src == '\n' || *src == '\r') {
                src++;
            }
            continue;
        }
        
        *dst++ = *src++;
    }
    *dst = '\0';
    
    return modified;
}

/*
 * Intercepted virDomainDefineXML function
 */
virDomainPtr virDomainDefineXML(virConnectPtr conn, const char *xml) {
    static orig_virDomainDefineXML_t orig_func = NULL;
    
    /* Get the original function pointer */
    if (!orig_func) {
        orig_func = (orig_virDomainDefineXML_t)dlsym(RTLD_NEXT, "virDomainDefineXML");
        if (!orig_func) {
            fprintf(stderr, "[libvirt-acpi-fix] ERROR: Could not find original virDomainDefineXML\n");
            return NULL;
        }
    }
    
    /* Strip ACPI from s390x domains */
    char *modified_xml = strip_acpi_from_s390x(xml);
    
    /* Call the original function with modified XML */
    virDomainPtr result = orig_func(conn, modified_xml);
    
    /* Cleanup */
    if (modified_xml != xml) {
        free(modified_xml);
    }
    
    return result;
}

/*
 * Also intercept virDomainCreateXML for transient domains
 */
typedef virDomainPtr (*orig_virDomainCreateXML_t)(virConnectPtr conn, const char *xml, unsigned int flags);

virDomainPtr virDomainCreateXML(virConnectPtr conn, const char *xml, unsigned int flags) {
    static orig_virDomainCreateXML_t orig_func = NULL;
    
    if (!orig_func) {
        orig_func = (orig_virDomainCreateXML_t)dlsym(RTLD_NEXT, "virDomainCreateXML");
        if (!orig_func) {
            fprintf(stderr, "[libvirt-acpi-fix] ERROR: Could not find original virDomainCreateXML\n");
            return NULL;
        }
    }
    
    char *modified_xml = strip_acpi_from_s390x(xml);
    virDomainPtr result = orig_func(conn, modified_xml, flags);
    
    if (modified_xml != xml) {
        free(modified_xml);
    }
    
    return result;
}

/* Constructor to log when library is loaded */
__attribute__((constructor))
static void init(void) {
    fprintf(stderr, "[libvirt-acpi-fix] LD_PRELOAD library loaded - will strip ACPI from s390x domains\n");
}

// Made with Bob
