targetScope = 'subscription'

@description('Azure region for the resource group and all resources.')
param location string = 'australiasoutheast'

@description('Resource group name.')
param resourceGroupName string = 'rg-personal-ansible-api'

@description('Your SSH public key contents.')
param sshPublicKey string

@secure()
@description('Administrator password for the Windows VM.')
param windowsAdminPassword string

@description('Private key path used only to render the ssh_command output.')
param sshPrivateKeyPath string = '~/.ssh/id_ed25519'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module resources 'resources.bicep' = {
  name: 'personal-ansible-api-resources'
  scope: rg
  params: {
    location: location
    sshPublicKey: sshPublicKey
    windowsAdminPassword: windowsAdminPassword
    sshPrivateKeyPath: sshPrivateKeyPath
  }
}

output resourceGroupName string = rg.name
output linuxPublicIp string = resources.outputs.linuxPublicIp
output linuxPrivateIp string = resources.outputs.linuxPrivateIp
output sshCommand string = resources.outputs.sshCommand
output windowsPublicIp string = resources.outputs.windowsPublicIp
output windowsPrivateIp string = resources.outputs.windowsPrivateIp
output windowsAdminUsername string = resources.outputs.windowsAdminUsername
