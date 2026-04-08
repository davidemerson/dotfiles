.PHONY: help validate provision backup

help:
	@echo "Dotfiles Management Commands:"
	@echo "  make validate   - Check that all expected files exist"
	@echo "  make provision  - Run full provisioning (root on Linux/OpenBSD)"
	@echo "  make backup     - Backup existing dotfiles"

validate:
	@chmod +x validate.sh
	@./validate.sh

provision:
	@chmod +x provision.sh
	@./provision.sh

backup:
	@echo "Backing up existing dotfiles..."
	@mkdir -p backups/$$(date +%Y%m%d_%H%M%S)
	@BDIR="backups/$$(date +%Y%m%d_%H%M%S)"; \
	for item in .config .bashrc .bash_profile .zshrc .gitconfig .ssh .wezterm.lua .xinitrc; do \
		if [ -e "$$HOME/$$item" ]; then \
			cp -r "$$HOME/$$item" "$$BDIR/"; \
		fi; \
	done
	@echo "Backup created in backups/"
