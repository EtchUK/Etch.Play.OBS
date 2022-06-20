param dnsZoneName string
param vmName string
param location string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
}

resource dnsRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: vmName
  properties: {
    TTL: 300
    'CNAMERecord': {
      cname: '${vmName}.${location}.cloudapp.azure.com'
    }
  }
}
