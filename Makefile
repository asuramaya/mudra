.PHONY: smoke check serve install-polkit install-launcher install
smoke:
	bash tests/smoke.sh
check: smoke
serve:
	python3 bin/mudra serve
install-polkit:
	@echo "Needs root — installs the desk's polkit action system-wide:"
	@echo "  sudo install -m644 polkit/com.asuramaya.mudra.policy /usr/share/polkit-1/actions/"
	@echo "Then: systemctl --user restart mudra (no root needed for that part)."
	sudo install -m644 polkit/com.asuramaya.mudra.policy /usr/share/polkit-1/actions/
	systemctl --user restart mudra
install-launcher:
	@echo "No root needed — just your own applications menu:"
	install -Dm644 desktop/mudra.desktop $(HOME)/.local/share/applications/mudra.desktop
	-update-desktop-database $(HOME)/.local/share/applications 2>/dev/null
	@echo "Launcher installed. \`mudra open\` (or the app-grid icon) opens the desk — no token to remember."
install: install-launcher
	@echo "Run 'make install-polkit' separately once — it needs your sudo password."
