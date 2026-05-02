targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Your SSH public key contents.')
param sshPublicKey string

@secure()
@description('Administrator password for the Windows VM.')
param windowsAdminPassword string

@description('Private key path used only to render the ssh_command output.')
param sshPrivateKeyPath string = '~/.ssh/id_ed25519'

param linuxAdminUsername string = 'azureuser'
param windowsAdminUsername string = 'azureuser'

var vnetName = 'vnet-personal-ansible-api'
var subnetName = 'snet-default'

var linuxVmName = 'vm-personal-ansible-api'
var linuxVmSize = 'Standard_D2s_v3'

var windowsVmName = 'vm-personal-windows'
var windowsComputerName = 'winpoc01'
var windowsVmSize = 'Standard_D2s_v3'

var addressSpace = [
  '10.10.0.0/16'
]
var subnetPrefix = [
  '10.10.1.0/24'
]

var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
var winRmCommand = '''powershell -ExecutionPolicy Bypass -Command "winrm quickconfig -q; Enable-PSRemoting -Force; Set-Item -Path WSMan:\localhost\Service\Auth\NTLM -Value $true; $cert = New-SelfSignedCertificate -DnsName 'winrm-selfsigned' -CertStoreLocation Cert:\LocalMachine\My; winrm create winrm/config/Listener?Address=*+Transport=HTTPS \"@{Hostname='winrm-selfsigned';CertificateThumbprint='$($cert.Thumbprint)'}\"; New-NetFirewallRule -DisplayName 'WinRM HTTPS' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow"; New-NetFirewallRule -Name Allow-ICMPv4 -DisplayName Allow ICMPv4-In -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow"'''

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefixes: subnetPrefix
        }
      }
    ]
  }
}

resource linuxPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-personal-ansible-api'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource windowsPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-personal-windows'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-personal-ansible-api'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-flask-api'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-rdp'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-winrm-https'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5986'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource linuxNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-personal-ansible-api'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: linuxPublicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource windowsNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-personal-windows'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: windowsPublicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource linuxVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: linuxVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: linuxVmSize
    }
    osProfile: {
      computerName: linuxVmName
      adminUsername: linuxAdminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${linuxAdminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${linuxVmName}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: linuxNic.id
        }
      ]
    }
  }
}

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: windowsVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: windowsVmSize
    }
    osProfile: {
      computerName: windowsComputerName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${windowsVmName}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: windowsNic.id
        }
      ]
    }
  }
}

resource windowsWinRmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: 'enable-winrm'
  parent: windowsVm
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      commandToExecute: winRmCommand
    }
  }
}

output linuxPublicIp string = linuxPublicIp.properties.ipAddress
output linuxPrivateIp string = linuxNic.properties.ipConfigurations[0].properties.privateIPAddress
output sshCommand string = 'ssh -i ${sshPrivateKeyPath} ${linuxAdminUsername}@${linuxPublicIp.properties.ipAddress}'
output windowsPublicIp string = windowsPublicIp.properties.ipAddress
output windowsPrivateIp string = windowsNic.properties.ipConfigurations[0].properties.privateIPAddress
output windowsAdminUsername string = windowsAdminUsername
