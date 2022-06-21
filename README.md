# OBS Virtual Machine

Bicep script used to spin up an Azure VM running OBS

Based originally on work from https://medium.com/codex/deploy-a-virtual-machine-with-skype-ndi-runtime-and-obs-ndi-installed-using-bicep-c216437f88f2


## To deploy ##

Powershell
```
Connect-AzAccount
Set-AzContext -subscription d8e6ef3e-f549-429c-9401-ed3516c1b5a6

New-AzResourceGroup -Name OBS -Location uksouth     # use this command when you need to create a new resource group for your deployment
New-AzResourceGroupDeployment -ResourceGroupName OBS -TemplateFile main.bicep -TemplateParameterFile azuredeploy.parameters.json -Confirm
```

Command line
```
az login
az account set --subscription d8e6ef3e-f549-429c-9401-ed3516c1b5a6

az group create --name OBS --location uksouth       # use this command when you need to create a new resource group for your deployment
az group deployment create --resource-group OBS --template-file main.bicep --parameters @azuredeploy.parameters.json
```


[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FEtchUK%2FEtch.Play.OBS%2Fmain%2Fmain.bicep)




TODO

* Check Windows 10 licensing
* How to delete these resources?
* VM User Authentication
* Runbook automation?
