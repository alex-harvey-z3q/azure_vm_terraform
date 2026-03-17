.PHONY: venv install ping bootstrap clean

PYTHON ?= python3
VENV ?= .venv
INVENTORY ?= inventory/hosts.yml
PLAYBOOK ?= playbooks/bootstrap_api_host.yml

venv:
	$(PYTHON) -m venv $(VENV)

install:
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements.txt

ping:
	$(VENV)/bin/ansible -i $(INVENTORY) api_host -m ping

bootstrap:
	$(VENV)/bin/ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

clean:
	rm -rf $(VENV)
