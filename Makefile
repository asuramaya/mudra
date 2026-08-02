.PHONY: smoke check check-repo serve install-polkit install-launcher install-service install sync-signers
smoke:
	bash tests/smoke.sh
check: check-repo smoke
serve:
	python3 src/bin/mudra serve
sync-signers:
	@echo "Rebuilds packaging/release-signing/allowed_signers from your canonical"
	@echo "keys — do NOT run casually. Only as part of arming a release, at your"
	@echo "own hand (see docs/RELEASING.md). Just the generic sync-signers CLI"
	@echo "verb, pointed at mudra's own repo — no separate script to keep in sync."
	python3 src/bin/mudra sync-signers mudra
install-polkit:
	@echo "Needs root — installs the desk's polkit action system-wide:"
	@echo "  sudo install -m644 src/polkit/com.mudra.open-desk.policy /usr/share/polkit-1/actions/"
	@echo "Then: systemctl --user restart mudra (no root needed for that part)."
	sudo install -m644 src/polkit/com.mudra.open-desk.policy /usr/share/polkit-1/actions/
	systemctl --user restart mudra
install-launcher:
	@echo "No root needed — just your own applications menu:"
	mkdir -p $(HOME)/.local/share/applications
	sed 's|__MUDRA_BIN__|$(CURDIR)/src/bin/mudra|' src/desktop/mudra.desktop \
	  > $(HOME)/.local/share/applications/mudra.desktop
	chmod 644 $(HOME)/.local/share/applications/mudra.desktop
	-update-desktop-database $(HOME)/.local/share/applications 2>/dev/null
	@echo "Launcher installed. \`mudra open\` (or the app-grid icon) opens the desk — no token to remember."
install-service:
	@echo "No root needed — installs mudra as your own systemd --user unit,"
	@echo "autostarting with your graphical session (needed for the seal"
	@echo "ceremony's zenity PIN dialog and hardware-key touch):"
	mkdir -p $(HOME)/.config/systemd/user
	sed 's|__MUDRA_DIR__|$(CURDIR)|g' src/systemd/mudra.service \
	  > $(HOME)/.config/systemd/user/mudra.service
	systemctl --user daemon-reload
	systemctl --user enable --now mudra
	@echo "Running. \`journalctl --user -u mudra -n 20\` for the one-boot token, or just \`mudra open\`."
install: install-launcher install-service
	@echo "Run 'make install-polkit' separately once — it needs your sudo password."
	@echo "Run 'mudra init' if you haven't configured your own roster yet."

# This family's own multi-repo structural gate (REPO-STANDARD.md) — checks
# things like root file count and a README nav block that are about keeping
# THIS FAMILY's OWN repos uniform with each other, not about whether mudra
# itself works. Runs by default (including in this repo's own CI); set
# MUDRA_SKIP_CHECK_REPO=1 to skip it entirely, e.g. in a fork organized
# differently that doesn't want this family's conventions imposed on it.
check-repo:
	@if [ -n "$$MUDRA_SKIP_CHECK_REPO" ]; then \
	    echo "check-repo: skipped (MUDRA_SKIP_CHECK_REPO set) — this is one family's own repo-layout convention, not required for mudra to function"; \
	    exit 0; \
	fi; \
	fail=0; \
	for f in README.md LICENSE Makefile .gitignore .gitattributes \
	         docs/USAGE.md docs/ARCHITECTURE.md docs/RELEASING.md; do \
	    if [ ! -e "$$f" ]; then echo "check-repo FAIL: missing $$f"; fail=1; fi; \
	done; \
	if [ ! -e install.sh ] && ! grep -q 'install\.sh' docs/ARCHITECTURE.md 2>/dev/null; then \
	    echo "check-repo FAIL: no install.sh and no exemption for it in docs/ARCHITECTURE.md"; fail=1; \
	fi; \
	rows=$$(git ls-files | cut -d/ -f1 | sort -u | wc -l); \
	if [ "$$rows" -gt 12 ]; then \
	    echo "check-repo FAIL: root has $$rows rows, standard caps it at 12"; fail=1; \
	else \
	    echo "check-repo: root row count ok ($$rows)"; \
	fi; \
	if ! grep -q '^## Map' README.md 2>/dev/null; then \
	    echo "check-repo FAIL: README.md has no navigation block (## Map)"; fail=1; \
	fi; \
	if [ ! -f packaging/VERSION ]; then \
	    echo "check-repo FAIL: no packaging/VERSION"; fail=1; \
	fi; \
	if grep -n "MUDRA_VERSION[[:space:]]*=[[:space:]]*['\"][0-9]" src/bin/mudra 2>/dev/null; then \
	    echo "check-repo FAIL: a literal version string exists outside packaging/VERSION"; fail=1; \
	fi; \
	if [ "$$fail" -eq 0 ]; then echo "check-repo: all mechanical checks passed"; else exit 1; fi
