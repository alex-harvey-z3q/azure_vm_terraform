# Azure VM Terraform Example

This Terraform configuration creates:

- Resource Group
- Virtual Network + Subnet
- Public IP
- Network Security Group (SSH + Flask port 5000)
- Network Interface
- Ubuntu Linux VM

## Usage

1. Copy the example tfvars file:

   cp terraform.tfvars.example terraform.tfvars

2. Add your SSH public key.

3. Run:

   terraform init
   terraform plan
   terraform apply

After creation, Terraform will output the public IP and SSH command.