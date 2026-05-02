.PHONY: help quality bicep-lint bicep-build json-lint terraform-fmt shellcheck ansible-deps ansible-lint

SHELL := /bin/bash

BICEP_FILES := bicep/main.bicep bicep/resources.bicep
JSON_FILES := bicep/main.json bicep/main.parameters.json bicep/bicepconfig.json
SHELL_FILES := scripts/submit_build_request.sh ansible/scripts/cleanup_stale_account.sh ansible/scripts/test_health.sh
ANSIBLE_LOCAL_TEMP ?= /tmp/ansible-local
ANSIBLE_REMOTE_TEMP ?= /tmp/ansible-remote

help:
	@printf '%s\n' \
		'Targets:' \
		'  quality        Run all local quality checks' \
		'  bicep-lint     Lint Bicep templates' \
		'  bicep-build    Build Bicep to ARM JSON' \
		'  json-lint      Validate JSON files' \
		'  terraform-fmt  Check Terraform formatting' \
		'  shellcheck     Run ShellCheck on shell scripts' \
		'  ansible-lint   Run ansible-lint from the Ansible project directory'

quality: bicep-lint bicep-build json-lint terraform-fmt shellcheck ansible-lint

bicep-lint:
	@for file in $(BICEP_FILES); do \
		echo "Linting $$file"; \
		az bicep lint --file "$$file"; \
	done

bicep-build:
	az bicep build --file bicep/main.bicep

json-lint:
	jq empty $(JSON_FILES)

terraform-fmt:
	terraform -chdir=terraform fmt -check -diff

shellcheck:
	shellcheck $(SHELL_FILES)

ansible-deps:
	cd ansible && ansible-galaxy collection install -r requirements.yml

ansible-lint: ansible-deps
	cd ansible && \
		ANSIBLE_LOCAL_TEMP="$(ANSIBLE_LOCAL_TEMP)" \
		ANSIBLE_REMOTE_TEMP="$(ANSIBLE_REMOTE_TEMP)" \
		ansible-lint playbooks roles
