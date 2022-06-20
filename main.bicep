@description('Location of resources')
param location string = 'uksouth'

@description('Local name for the VM')
param vmName string

@description('User name for the Virtual Machine')
param adminUsername string  ='etchadmin'

@description('Password for the Virtual Machine')
@secure()
param adminPassword string

@description('Desired Size of the VM; pay attention to geographic availability and quota restrictions')
param vmSize string = 'Standard_NV4as_v4'

@description('Existing Virtual Network to deploy network into')
param virtualNetworkId string = '/subscriptions/d8e6ef3e-f549-429c-9401-ed3516c1b5a6/resourceGroups/Internal/providers/Microsoft.Network/virtualNetworks/etch-servers'

@description('Existing subnet to deploy network interface into')
param subnetName string

@description('PowerShell script name to execute')
param scriptFileName string = 'ChocoInstall.ps1'

@description('List of Chocolatey packages to install separated by a semi-colon eg. linqpad;sysinternals')
param chocoPackages string = 'obs-studio'

var vmImagePublisher = 'MicrosoftWindowsDesktop'
var vmImageOffer = 'Windows-10'
var sku = 'win10-21h2-ent'

var nicName = '${vmName}-nic'
param publicIPName string = '${vmName}-pip'
param dnsprefix string = '${vmName}-vm'

param dnsZoneName string = 'etchplay.com'

@description('Public URI of PowerShell Chocolately setup script')
var scriptLocation = 'https://raw.githubusercontent.com/EtchUK/Etch.Play.OBS/main/ChocoInstall.ps1'

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
    networkSecurityGroup: nsg
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
        scriptLocation
      ]
      commandToExecute: 'powershell -ExecutionPolicy bypass -File ${scriptFileName} -chocoPackages ${chocoPackages}'
    }
  }
}
