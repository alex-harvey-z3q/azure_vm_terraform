# Azure VM Bicep Deployment

This directory is a Bicep rewrite of the Terraform deployment in `../terraform`.

The entrypoint is subscription-scoped because it creates the resource group first. The Azure resources themselves are deployed through `resources.bicep`, which runs at resource-group scope.

## Files

| File | Purpose |
| --- | --- |
| `main.bicep` | Subscription-scoped entrypoint. Creates the resource group and calls the resource module. |
| `resources.bicep` | Resource-group-scoped VM, network, NSG, public IP, NIC, and VM extension resources. |
| `main.parameters.json` | Example deployment parameters. Replace the Windows password before use. |
| `main.json` | Compiled ARM JSON generated from `main.bicep`. |
| `bicepconfig.json` | Native Bicep linter configuration. |
| `ps-rule.yaml` | Optional PSRule for Azure configuration. |

## Tooling

Install or update Azure CLI and the Bicep CLI:

```bash
az --version
az bicep version
az bicep upgrade
```

Useful editor support:

- VS Code with the Microsoft Bicep extension for completions, diagnostics, formatting, and ARM type help.
- Azure CLI for local build, lint, deployment, and what-if previews.

## Local Checks

Run these from the repository root.

Format Bicep files:

```bash
az bicep format --file bicep/main.bicep
az bicep format --file bicep/resources.bicep
```

Lint Bicep files:

```bash
az bicep lint --file bicep/main.bicep
az bicep lint --file bicep/resources.bicep
```

For CI systems that understand SARIF:

```bash
az bicep lint --file bicep/main.bicep --diagnostics-format sarif
az bicep lint --file bicep/resources.bicep --diagnostics-format sarif
```

Build Bicep to ARM JSON:

```bash
az bicep build --file bicep/main.bicep
```

Validate generated JSON:

```bash
jq empty bicep/main.json bicep/main.parameters.json
```

## Deployment Preview

Use what-if before applying changes:

```bash
az deployment sub what-if \
  --location australiasoutheast \
  --template-file bicep/main.bicep \
  --parameters @bicep/main.parameters.json
```

For a lower-permission static pass, use template-only validation:

```bash
az deployment sub what-if \
  --location australiasoutheast \
  --template-file bicep/main.bicep \
  --parameters @bicep/main.parameters.json \
  --validation-level Template
```

## Deploy

Do not commit a real Windows admin password. Either edit `main.parameters.json` locally or pass the password at the command line.

```bash
az deployment sub create \
  --location australiasoutheast \
  --template-file bicep/main.bicep \
  --parameters @bicep/main.parameters.json
```

Or pass secrets without editing the parameter file:

```bash
az deployment sub create \
  --location australiasoutheast \
  --template-file bicep/main.bicep \
  --parameters \
    sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)" \
    windowsAdminPassword="<secure-password>"
```

The deployment outputs the resource group name, Linux and Windows public/private IPs, the Windows admin username, and an SSH command for the Linux VM.

## Policy and Security Scans

The native Bicep linter catches syntax, type, style, and selected best-practice issues. For policy-as-code checks, add one of these in CI.

PSRule for Azure checks Bicep/ARM against Azure well-architected and service-specific rules:

```bash
pwsh -NoLogo -NoProfile -Command \
  "Install-Module PSRule.Rules.Azure -Scope CurrentUser -Force; Invoke-PSRule -InputPath bicep -Module PSRule.Rules.Azure -Option bicep/ps-rule.yaml"
```

This requires PowerShell. On macOS, install it with `brew install powershell`.

Checkov scans Bicep for common Azure misconfigurations:

```bash
checkov -d bicep --framework bicep
```

Expected findings for this proof-of-concept may include intentionally open SSH, RDP, Flask API, and WinRM rules. Treat those as design decisions to tighten before this is exposed beyond a controlled personal environment.

## Remove Resources

```bash
az group delete --name rg-personal-ansible-api
```

## References

- [Bicep CLI commands](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli)
- [Bicep linter configuration](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-config-linter)
- [Bicep what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if)
- [PSRule for Azure Bicep source](https://azure.github.io/PSRule.Rules.Azure/using-bicep/)
- [Checkov Bicep scanning](https://www.checkov.io/7.Scan%20Examples/Bicep.html)
