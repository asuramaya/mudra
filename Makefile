.PHONY: smoke check serve
smoke:
	bash tests/smoke.sh
check: smoke
serve:
	python3 bin/mudra serve
