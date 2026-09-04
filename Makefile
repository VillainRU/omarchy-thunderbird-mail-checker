.PHONY: xpi check test

xpi:
	@stage="$$(mktemp -d)"; \
	trap 'rm -rf "$$stage"' EXIT; \
	cp thunderbird/manifest.webextension.json "$$stage/manifest.json"; \
	cp thunderbird/background.js "$$stage/background.js"; \
	cp -R thunderbird/_locales "$$stage/_locales"; \
	cd "$$stage" && zip -X -r "$(CURDIR)/thunderbird/thunderbird-mail-checker.xpi" manifest.json background.js _locales

check:
	python -m json.tool manifest.json >/dev/null
	python -m json.tool thunderbird/manifest.webextension.json >/dev/null
	node --check thunderbird/background.js
	node tests/background-test.js
	node tests/panel-reconnect-test.js
	python -m py_compile bin/thunderbird-mail-checker
	bash -n bin/native-host tests/protocol-test.sh
	./tests/protocol-test.sh

test: check
