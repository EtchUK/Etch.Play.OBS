@description('Location of resources')
param location string = 'uksouth'

@description('Local name for the VM')
param vmName string

@description('User name for the Virtual Machine')
param adminUsername string

@description('Password for the Virtual Machine')
@secure()
param adminPassword string

@description('Desired Size of the VM; pay attention to geographic availability and quota restrictions')
param vmSize string = 'Standard_NV4as_v4'

@description('Existing Virtual Network to deploy network into')
param virtualNetworkId string

@description('Existing subnet to deploy network interface into')
param subnetName string

@description('Existing DNS zone to register the VM in')
param dnsZoneName string

@description('Chocolatey PowerShell script name to execute')
param chocoScriptFileName string = 'ChocoInstall.ps1'

@description('Storage PowerShell script name to execute')
param storageScriptFileName string = 'MountStorage.ps1'

@description('Public URI of PowerShell Chocolately setup script')
var chocoScriptLocation = 'https://raw.githubusercontent.com/EtchUK/Etch.Play.OBS/main/ChocoInstall.ps1'

@description('Public URI of PowerShell Storage setup script')
var storageScriptLocation = 'https://raw.githubusercontent.com/EtchUK/Etch.Play.OBS/main/MountStorage.ps1'


@description('List of Chocolatey packages to install separated by a semi-colon eg. linqpad;sysinternals')
param chocoPackages string = 'obs-studio'

var vmImagePublisher = 'MicrosoftWindowsDesktop'
var vmImageOffer = 'Windows-10'
var sku = 'win10-21h2-ent'

var nicName = '${vmName}-nic'
param publicIPName string = '${vmName}-pip'
param dnsprefix string = vmName



resource pip 'Microsoft.Network/publicIPAddresses@2020-08-01' = {
  name: publicIPName
  location: location
  tags: {
    team: 'Play'
  }  
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsprefix
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: '${vmName}-nsg'
  location: location
  tags: {
    team: 'Play'
  }
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '212.59.69.42/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: nicName
  location: location
  tags: {
    team: 'Play'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: '${virtualNetworkId}/subnets/${subnetName}'
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// module deployed to resource group in the same subscription
module dns 'dns.bicep' = {
  name: 'dns'
  scope: resourceGroup('DNS')
  params: {
    dnsZoneName: dnsZoneName
    vmName: vmName
    location: location
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  tags: {
    team: 'Play'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: sku
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${vmName}_OsDisk'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        caching: 'ReadWrite'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: vmName
  location: location
  tags: {
    team: 'Play'
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' {
  name: '${storage.name}/default/media'
  properties: {
    shareQuota: 5120
    enabledProtocols: 'SMB'
  }
}

resource vm_GPU 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'GPUDrivers'
  location: location
  tags: {
    displayName: 'gpu-nvidia-drivers'
  }
  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'NvidiaGpuDriverWindows'
    typeHandlerVersion: '1.2'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    vm_SetupChocolatey
  ]
}

resource vm_AAD 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'AAD'
  location: location
  tags: {
    displayName: 'aad'
  }
  properties:{
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '0.4'
    autoUpgradeMinorVersion: true
  }
}

resource vm_SetupBgInfo 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'SetupBgInfo'
  location: location
  tags: {
    displayName: 'config-bginfo'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'BGInfo'
    typeHandlerVersion: '1.1'
    settings: {}
    protectedSettings: null
  }
}

resource vm_SetupChocolatey 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'SetupChocolatey'
  location: location
  tags: {
    displayName: 'config-choco'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        chocoScriptLocation
      ]
      commandToExecute: 'powershell -ExecutionPolicy bypass -File ${chocoScriptFileName} -chocoPackages ${chocoPackages}'
    }
  }
}

resource vm_MountStorage 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'MountStorage'
  location: location
  tags: {
    displayName: 'mount-storage'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        storageScriptLocation
      ]
      commandToExecute: 'powershell -ExecutionPolicy bypass -File ${storageScriptFileName} -storageAccountName ${storage.name} -fileShareName ${fileshare.name} -storageAccountKey ${listKeys(storage.name, '2019-04-01').keys[0].value}'
    }
  }
}
