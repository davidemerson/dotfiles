.PHONY: help validate test-syntax provision clean backup

help:
	@echo "Dotfiles Management Commands:"
	@echo "  make validate     - Validate configuration files"
	@echo "  make test-syntax  - Test Salt state syntax"
	@echo "  make provision    - Run full provisioning (requires root)"
	@echo "  make backup       - Backup existing dotfiles"
	@echo "  make clean        - Remove temporary files"

validate:
	@chmod +x validate.sh
	@./validate.sh

test-syntax:
	@if command -v salt-call >/dev/null 2>&1; then \
		salt-call --local state.show_sls base --out=quiet; \
		salt-call --local state.show_sls dotfiles --out=quiet; \
		echo "Salt syntax validation passed"; \
	else \
		echo "Salt not installed, skipping syntax check"; \
	fi

provision:
	@if [ "$$(id -u)" != "0" ]; then \
		echo "Error: must be run as root"; \
		exit 1; \
	fi
	@chmod +x provision.sh
	@./provision.sh

backup:
	@echo "Backing up existing dotfiles..."
	@mkdir -p backups/$$(date +%Y%m%d_%H%M%S)
	@BDIR="backups/$$(date +%Y%m%d_%H%M%S)"; \
	for item in .config .bashrc .gitconfig .ssh; do \
		if [ -e "$$HOME/$$item" ]; then \
			cp -r "$$HOME/$$item" "$$BDIR/"; \
		fi; \
	done
	@echo "Backup complete."

clean:
	@rm -f bootstrap-salt.sh
	@rm -rf /tmp/salt_*
	@echo "Cleanup complete."
