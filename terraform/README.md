# Azure VM (Terraform) – Quick Start Guide

## 1. Build the VM

From your Terraform directory:

```bash
terraform init
terraform apply
```

After completion, get the public IP:

```bash
terraform output public_ip
```

---

## 2. SSH into the VM

Use the default username:

```bash
ssh azureuser@<public_ip>
```

---

## 3. Basic Setup (optional)

Once logged in:

```bash
sudo apt update
sudo apt install -y python3-pip
pip3 install flask ansible
```

---

## 4. Tear Down (destroy resources)

To remove everything:

```bash
terraform destroy
```

Confirm with:

```text
yes
```

---

## Notes

- If deployment fails, try a different VM size (e.g. `Standard_D2s_v3`)
- If SSH fails, check port 22 is open in the NSG
- Azure may have temporary capacity limits in some regions

---

Done.
