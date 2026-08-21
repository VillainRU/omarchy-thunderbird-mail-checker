.PHONY: xpi check test

xpi:
	cd thunderbird && zip -X -r thunderbird-mail-checker.xpi manifest.json background.js _locales

check:
	python -m json.tool manifest.json >/dev/null
	python -m json.tool thunderbird/manifest.json >/dev/null
	python -m py_compile bin/thunderbird-mail-checker
	bash -n bin/native-host tests/protocol-test.sh
	./tests/protocol-test.sh

test: check
