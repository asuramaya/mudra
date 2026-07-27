.PHONY: smoke check serve install-polkit
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
