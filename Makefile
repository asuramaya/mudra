.PHONY: smoke check check-repo serve install-polkit install-launcher install
smoke:
	bash tests/smoke.sh
check: check-repo smoke
serve:
	python3 src/bin/mudra serve
install-polkit:
	@echo "Needs root — installs the desk's polkit action system-wide:"
	@echo "  sudo install -m644 src/polkit/com.asuramaya.mudra.policy /usr/share/polkit-1/actions/"
	@echo "Then: systemctl --user restart mudra (no root needed for that part)."
	sudo install -m644 src/polkit/com.asuramaya.mudra.policy /usr/share/polkit-1/actions/
	systemctl --user restart mudra
install-launcher:
	@echo "No root needed — just your own applications menu:"
	install -Dm644 src/desktop/mudra.desktop $(HOME)/.local/share/applications/mudra.desktop
	-update-desktop-database $(HOME)/.local/share/applications 2>/dev/null
	@echo "Launcher installed. \`mudra open\` (or the app-grid icon) opens the desk — no token to remember."
install: install-launcher
	@echo "Run 'make install-polkit' separately once — it needs your sudo password."

# REPO-STANDARD.md's structural gate. mudra has no install.sh/uninstall.sh —
# it installs through make targets (install-polkit, install-launcher), not a
# shell installer — recorded as an exemption in docs/ARCHITECTURE.md rather
# than checked for here, same shape as coldspot's man-page exemption.
check-repo:
	@fail=0; \
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
