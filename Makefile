# Install paths (override with: make INSTALL_DIR=... etc.)
INSTALL_DIR      ?= $(HOME)/.local/bin
COMPLETION_DIR   ?= $(HOME)/.local/share/bash-completion/completions
MAN1_DIR         ?= $(HOME)/.local/share/man/man1

# Sources
SCRIPT_SRC       := ./src/neopop.sh
DATA_SRC_DIR     := ./src/neopop
COMP_SRC         := ./aux/bsh/neopop.bash
MAN_SRC          := ./doc/man.1

# Destinations
SCRIPT_DEST      := $(INSTALL_DIR)/neopop
DATA_DEST_DIR    := $(INSTALL_DIR)/.neopop
COMP_DEST        := $(COMPLETION_DIR)/neopop
MAN_DEST         := $(MAN1_DIR)/neopop.1

.PHONY: all install uninstall man-db

all: install

install:
	@echo "🔧 Installing neopop → $(SCRIPT_DEST)"
	@mkdir -p "$(INSTALL_DIR)" "$(COMPLETION_DIR)" "$(MAN1_DIR)"
	@cp "$(SCRIPT_SRC)" "$(SCRIPT_DEST)"
	@chmod +x "$(SCRIPT_DEST)"
	@echo "📁 Installing resources → $(DATA_DEST_DIR)"
	@rm -rf "$(DATA_DEST_DIR)"; mkdir -p "$(DATA_DEST_DIR)"
	@cp -R "$(DATA_SRC_DIR)/awk" "$(DATA_DEST_DIR)/"
	@cp -R "$(DATA_SRC_DIR)/usg" "$(DATA_DEST_DIR)/"
	@cp    "$(DATA_SRC_DIR)/ec.sh" "$(DATA_DEST_DIR)/"
	@# Patch LIB in installed script: LIB="neopop" → LIB=".neopop"
	@sed -E -i.bak 's#^([[:space:]]*LIB=)\"neopop\"#\1\".neopop\"#' "$(SCRIPT_DEST)" && rm -f "$(SCRIPT_DEST).bak"
	@echo "✅ Script + resources installed"

	@echo "🔧 Installing bash-completion → $(COMP_DEST)"
	@cp "$(COMP_SRC)" "$(COMP_DEST)"
	@echo "✅ Bash-completion installed"

	@echo "🔧 Installing manpage → $(MAN_DEST)"
	@cp "$(MAN_SRC)" "$(MAN_DEST)"
	@$(MAKE) man-db
	@echo "✅ Manpage installed (try: man neopop)"

	@command -v neopop >/dev/null || echo "ℹ️  Add $(INSTALL_DIR) to PATH."
	@case ":$$MANPATH:" in *":$(HOME)/.local/share/man:"*) :;; \
	  *) echo "ℹ️  Add user manpath to your shell rc, e.g.:"; \
	     echo "    export MANPATH=\"/opt/homebrew/share/man:\$$HOME/.local/share/man\${MANPATH+:\\\$$MANPATH}:\"";; \
	esac

# Rebuild man DB if tool available
man-db:
	@if command -v mandb >/dev/null 2>&1; then mandb >/dev/null 2>&1 || true; \
	elif command -v makewhatis >/dev/null 2>&1; then makewhatis >/dev/null 2>&1 || true; \
	else echo "ℹ️  No mandb/makewhatis found; man index not refreshed."; fi

uninstall:
	@echo "🗑️  Removing $(SCRIPT_DEST)"; rm -f "$(SCRIPT_DEST)"
	@echo "🗑️  Removing resources $(DATA_DEST_DIR)"; rm -rf "$(DATA_DEST_DIR)"
	@echo "🗑️  Removing completion $(COMP_DEST)"; rm -f "$(COMP_DEST)"
	@echo "🗑️  Removing manpage $(MAN_DEST)"; rm -f "$(MAN_DEST)"
	@$(MAKE) man-db || true
	@echo "✅ Uninstalled."

