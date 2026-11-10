VMAJOR := $(shell if [ -f ".version/major" ]; then cat .version/major; else echo 1; fi)
VMINOR := $(shell if [ -f ".version/minor" ]; then cat .version/minor; else echo 0; fi)

VERSION := $(VMAJOR).$(VMINOR)

SRC := src/main.typ
BUILD := src/main.pdf

VDIR := complete/ver.$(VMAJOR)

TARGET := $(VDIR)/ver$(VERSION).pdf

TITLE := @TITLE@.pdf

release: .version/minor .version/major $(TARGET)
	cp $(TARGET) complete/$(TITLE)

version:
	@echo ver$(VMAJOR).$$(( $(VMINOR) - 1 ))

upgrade: .version
	expr $(VMAJOR) + 1 > .version/major
	echo 0 > .version/minor
	make release

build: $(BUILD)

open: $(BUILD)
	evince $(BUILD)&

.version/minor: .version $(TARGET)
	expr $(VMINOR) + 1 > .version/minor

.version/major: .version
	echo $(VMAJOR) > .version/major

$(TARGET): $(VDIR) $(BUILD)
	cp $(BUILD) $(TARGET)

$(VDIR):
	mkdir $(VDIR)

$(BUILD): $(SRC)
	cd src && typst compile main.typ

.version:
	mkdir .version
