.PHONY: venv install ping bootstrap deploy clean

PYTHON ?= python3
VENV ?= .venv
INVENTORY ?= inventory/hosts.yml

BOOTSTRAP_PLAYBOOK ?= playbooks/bootstrap_api_host.yml
DEPLOY_PLAYBOOK ?= playbooks/deploy_control_node_code.yml

venv:
	$(PYTHON) -m venv $(VENV)

install:
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements.txt

ping:
	$(VENV)/bin/ansible -i $(INVENTORY) api_host -m ping

bootstrap:
	$(VENV)/bin/ansible-playbook -i $(INVENTORY) $(BOOTSTRAP_PLAYBOOK)

deploy:
	$(VENV)/bin/ansible-playbook -i $(INVENTORY) $(DEPLOY_PLAYBOOK)

clean:
	rm -rf $(VENV)
