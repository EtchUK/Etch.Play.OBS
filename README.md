# OBS Virtual Machine

Bicep script used to spin up an Azure VM running OBS

Followed this tutorial: https://medium.com/codex/deploy-a-virtual-machine-with-skype-ndi-runtime-and-obs-ndi-installed-using-bicep-c216437f88f2



To deploy;
```
$date = Get-Date -Format "yyyy-MM-dd-hhmm"
$deploymentName = "OBS-"+"$date"

Connect-AzAccount
Set-AzContext -subscription d8e6ef3e-f549-429c-9401-ed3516c1b5a6

New-AzResourceGroup -Name 'OBS' -Location 'uksouth'
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName OBS -TemplateFile .\main.bicep -TemplateParameterFile .\azuredeploy.parameters.json -c
```


[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FEtchUK%2FEtch.Play.OBS%2Fmain%2Fmain.bicep)






TODO

* Check Windows 10 licensing
* Get quota increased to allow use of Standard_NV8as_v4
* How to delete these resources?
