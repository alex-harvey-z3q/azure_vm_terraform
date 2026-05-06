# Azure VM Bicep + Ansible API

This repository provisions a small Azure environment and bootstraps a Linux VM as an Ansible control/API host. The API is intended to receive build requests, then run Ansible automation such as creating or deleting temporary Windows users.

Bicep is the infrastructure-as-code implementation for this project.

- `bicep/`: Azure infrastructure deployment.

## Architecture

At a high level:

1. Provision Azure networking, public IPs, NSG rules, one Ubuntu VM, and one Windows Server VM.
2. Bootstrap the Ubuntu VM with Python, Ansible, Flask, Gunicorn, and a systemd service.
3. Deploy the Ansible project to the Ubuntu VM so it can act as a control node.
4. Submit build requests through Azure Pipelines or `scripts/submit_build_request.sh`.
5. The Flask API can trigger Ansible workflows against the Windows VM.

```text
                 +---------------------------+
                 | Developer / Azure DevOps  |
                 +-------------+-------------+
                               |
                               | make quality
                               | az deployment sub create
                               v
        +----------------------+----------------------+
        |               Azure Subscription            |
        |                                             |
        |  +---------------- Resource Group --------+ |
        |  |                                        | |
        |  |  +---------+       +----------------+  | |
        |  |  |  VNet   |-------| Shared Subnet  |  | |
        |  |  +----+----+       +--------+-------+  | |
        |  |       |                     |          | |
        |  |       |                     |          | |
        |  | +-----v------+       +------v-------+  | |
        |  | | Linux VM   |       | Windows VM   |  | |
        |  | | Flask API  |       | WinRM/RDP    |  | |
        |  | | Ansible    |------>| temp users   |  | |
        |  | +-----+------+       +--------------+  | |
        |  |       ^                                | |
        |  +-------|--------------------------------+ |
        |          |                                  |
        +----------|----------------------------------+
                   |
                   | POST /build
                   |
          +--------+---------+
          | Azure Pipeline / |
          | submit script    |
          +------------------+
```

## Repository Layout

| Path | Purpose |
| --- | --- |
| `bicep/` | Bicep Azure VM deployment, including lint config and deployment docs. |
| `ansible/` | Ansible inventory, playbooks, roles, templates, and local development Makefile. |
| `scripts/submit_build_request.sh` | Helper script that POSTs a build request to the Flask API. |
| `azure-pipelines.yml` | Manual Azure Pipeline that submits a build request to the API. |

## Azure Resources

The IaC provisions:

- Resource group: `rg-personal-ansible-api`
- VNet: `vnet-personal-ansible-api`
- Subnet: `snet-default`
- Linux VM: `vm-personal-ansible-api`
- Windows VM: `vm-personal-windows`
- Static public IPs for both VMs
- Shared NSG with inbound SSH, Flask API, RDP, and WinRM rules
- Windows VM custom script extension to enable WinRM/PowerShell remoting

The open inbound rules are convenient for a personal proof-of-concept. Tighten source CIDRs before using this outside a controlled environment.

## Provision Infrastructure

Run the Bicep checks before deploying:

```bash
az bicep lint --file bicep/main.bicep
az bicep lint --file bicep/resources.bicep
az bicep build --file bicep/main.bicep
```

Preview changes:

```bash
az deployment sub what-if \
  --location australiasoutheast \
  --template-file bicep/main.bicep \
  --parameters @bicep/main.parameters.json
```

Deploy:

```bash
az deployment sub create \
  --location australiasoutheast \
  --template-file bicep/main.bicep \
  --parameters \
    sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)" \
    windowsAdminPassword="<secure-password>"
```

See `bicep/README.md` for Bicep linting, PSRule, Checkov, what-if, and teardown details.

## Bootstrap the Ansible API Host

After provisioning, update the Ansible inventory with the Linux VM public IP:

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
```

Create the local Ansible environment:

```bash
make venv
make install
```

Test SSH and bootstrap the API host:

```bash
make ping
make bootstrap
```

The bootstrap deploys:

- App directory: `/opt/ansible-api`
- Flask app: `/opt/ansible-api/app.py`
- Virtualenv: `/opt/ansible-api/venv`
- systemd service: `ansible-api.service`
- Listen port: `5000`

Deploy the Ansible control-node project onto the Linux VM:

```bash
make deploy
```

Health check:

```bash
curl http://<linux-vm-public-ip>:5000/health
```

Expected response:

```json
{"status":"ok"}
```

## Submit a Build Request

Set the API base URL:

```bash
export API_BASE_URL="http://<linux-vm-public-ip>:5000"
```

Submit a request:

```bash
scripts/submit_build_request.sh \
  nste \
  "Jane Smith" \
  "jane.smith@example.com" \
  "BK-001" \
  "2026-05-02T09:00:00+10:00" \
  "2026-05-02T17:00:00+10:00" \
  "8"
```

The Azure Pipeline performs the same API call using pipeline parameters and the `api_base_url` pipeline variable.

## Windows User Automation

The Ansible playbooks include workflows for temporary Windows users:

```bash
cd ansible
.venv/bin/ansible-playbook -i inventory/hosts.yml playbooks/create_temp_user.yaml \
  -e "booking_username=nste-jsmith booking_id=BK-001"

.venv/bin/ansible-playbook -i inventory/hosts.yml playbooks/delete_temp_user.yaml \
  -e "booking_username=nste-jsmith booking_id=BK-001"
```

The Windows inventory uses WinRM settings from `ansible/inventory/group_vars/windows.yml`.

## Linting and Validation

Useful checks:

```bash
az bicep lint --file bicep/main.bicep
az bicep lint --file bicep/resources.bicep
az bicep build --file bicep/main.bicep
jq empty bicep/main.json bicep/main.parameters.json bicep/bicepconfig.json
ansible-lint ansible/playbooks/*.yml ansible/playbooks/*.yaml
```

Optional security/policy checks for Bicep:

```bash
checkov -d bicep --framework bicep
pwsh -NoLogo -NoProfile -Command \
  "Invoke-PSRule -InputPath bicep -Module PSRule.Rules.Azure -Option bicep/ps-rule.yaml"
```

## Cleanup

```bash
az group delete --name rg-personal-ansible-api
```
