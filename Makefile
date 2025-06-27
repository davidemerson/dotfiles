.PHONY: help validate test-syntax provision clean backup

# Default target
help:
	@echo "Dotfiles Management Commands:"
	@echo "  make validate     - Validate configuration files"
	@echo "  make test-syntax  - Test Salt state syntax"
	@echo "  make provision    - Run full provisioning (requires root)"
	@echo "  make backup       - Backup existing dotfiles"
	@echo "  make clean        - Remove temporary files"

# Validate configuration
validate:
	@echo "Validating dotfiles configuration..."
	@chmod +x validate.sh
	@./validate.sh

# Test Salt syntax
test-syntax:
	@echo "Testing Salt state syntax..."
	@if command -v salt-call >/dev/null 2>&1; then \
		salt-call --local state.show_sls base --out=quiet; \
		salt-call --local state.show_sls dotfiles --out=quiet; \
		echo "Salt syntax validation passed"; \
	else \
		echo "Salt not installed, skipping syntax check"; \
	fi

# Full provisioning (requires root)
provision:
	@if [ "$(shell id -u)" != "0" ]; then \
		echo "Error: This target must be run as root"; \
		exit 1; \
	fi
	@chmod +x provision.sh
	@./provision.sh

# Backup existing dotfiles
backup:
	@echo "Creating backup of existing dotfiles..."
	@mkdir -p backups/$(shell date +%Y%m%d_%H%M%S)
	@if [ -d "$$HOME/.config" ]; then \
		cp -r "$$HOME/.config" "backups/$(shell date +%Y%m%d_%H%M%S)/"; \
	fi
	@for file in .bashrc .gitconfig .ssh; do \
		if [ -e "$$HOME/$$file" ]; then \
			cp -r "$$HOME/$$file" "backups/$(shell date +%Y%m%d_%H%M%S)/"; \
		fi; \
	done
	@echo "Backup created in backups/$(shell date +%Y%m%d_%H%M%S)/"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -f bootstrap-salt.sh
	@rm -rf /tmp/salt_*
	@echo "Cleanup complete"
