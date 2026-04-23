# Makefile for s390x ACPI Fix Library

CC = gcc
CFLAGS = -shared -fPIC -Wall -Wextra
LDFLAGS = -ldl -lvirt
TARGET = libvirt-acpi-fix.so
SOURCE = libvirt-acpi-fix.c

# Installation paths
PREFIX ?= /usr/local
LIBDIR = $(PREFIX)/lib64

.PHONY: all clean install uninstall test

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE) $(LDFLAGS)
	@echo "✅ Built $(TARGET)"

clean:
	rm -f $(TARGET) *.o
	@echo "✅ Cleaned build artifacts"

install: $(TARGET)
	install -d $(DESTDIR)$(LIBDIR)
	install -m 755 $(TARGET) $(DESTDIR)$(LIBDIR)/
	@echo "✅ Installed $(TARGET) to $(DESTDIR)$(LIBDIR)/"
	@echo ""
	@echo "To use system-wide, configure libvirtd:"
	@echo "  1. Create /etc/systemd/system/libvirtd.service.d/override.conf"
	@echo "  2. Add: [Service]"
	@echo "          Environment=\"LD_PRELOAD=$(LIBDIR)/$(TARGET)\""
	@echo "  3. Run: systemctl daemon-reload && systemctl restart libvirtd"

uninstall:
	rm -f $(DESTDIR)$(LIBDIR)/$(TARGET)
	@echo "✅ Uninstalled $(TARGET)"

test: $(TARGET)
	@echo "Running tests..."
	@bash test-acpi-issue-locally.sh
	@echo ""
	@echo "Running LD_PRELOAD tests..."
	@bash compile-and-test-preload.sh

help:
	@echo "s390x ACPI Fix - Makefile targets:"
	@echo ""
	@echo "  make          - Build the library"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make install  - Install to $(LIBDIR)"
	@echo "  make uninstall- Remove from $(LIBDIR)"
	@echo "  make test     - Run test suite"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  LIBDIR=$(LIBDIR)"
	@echo ""
	@echo "Example:"
	@echo "  make"
	@echo "  sudo make install"