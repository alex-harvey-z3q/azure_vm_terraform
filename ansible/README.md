# Ansible API Host Bootstrap

This project bootstraps your Azure Linux VM as a simple Ansible + Flask API host.

It installs:

- Python 3 venv support
- git
- jq
- curl
- Ansible
- Flask
- Gunicorn

It also deploys:

- a very small Flask API
- a systemd service for Gunicorn

## Quick start

1. Copy the example inventory and edit the IP:

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

2. Create the local virtualenv:

```bash
make venv
```

3. Activate it:

```bash
source .venv/bin/activate
```

4. Install Python dependencies:

```bash
make install
```

5. Test SSH access:

```bash
make ping
```

6. Run the playbook:

```bash
make bootstrap
```

## Expected target host

This assumes:

- Ubuntu Linux VM
- SSH access as `azureuser`
- sudo access
- your SSH private key is already available locally

## What gets deployed on the VM

- App directory: `/opt/ansible-api`
- Virtualenv: `/opt/ansible-api/venv`
- Flask app: `/opt/ansible-api/app.py`
- systemd service: `ansible-api.service`
- Listen port: `5000`

## Test after deployment

From your laptop:

```bash
curl http://<vm-public-ip>:5000/health
```

Expected response:

```json
{"status":"ok"}
```
