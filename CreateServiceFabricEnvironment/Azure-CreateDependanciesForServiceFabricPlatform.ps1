cls
$SubscriptionId = '<myAzureSubscriptionIdHere>'
$location = "northeurope"

#static IP number parameters
$ipNumberResourceGroupName = "myclusterip"
$ipNumberNameFrontEnd = "mycluster"

#Key vault parameters
$keyVaultResourceGroupName = "myclustervault"
$keyVaultName = "myclustervault"
$keyVaultAdminName = "myAdminNameHere"
$serviceFabricClusterNameDNSName = "mycluster.northeurope.cloudapp.azure.com"

#Service fabric parameters
$serviceFabricResourceGroupName = "mycluster"
$vnetName = "VNet-mycluster"
$serviceFabricVNetAddressPrefix = "10.0.0.0/16"

$serviceFabricFrontEndSubnetName = "sfFrontEnd"
$serviceFabricFrontEndSubnetAddressPrefix = "10.0.0.0/24"

$serviceFabricBackEndSubnetName = "sfBackEnd"
$serviceFabricBackEndSubnetAddressPrefix = "10.0.1.0/24"

$serviceFabricManagementSubnetName = "sfManagement"
$serviceFabricManagementSubnetAddressPrefix = "10.0.2.0/24"

$serviceFabricWAFSubnetName = "WAF"
$serviceFabricWAFSubnetAddressPrefix = "10.0.3.0/24"

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}


function CreateVirtualNetworkAndSubnetsForServiceFabric {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $promptResult = [Microsoft.VisualBasic.Interaction]::MsgBox("Create new Virtual Network and 4 subnets for Service Fabric?",'YesNo,Question', "Respond please")

    if($promptResult -eq "Yes")
    {
        Write-Host "Creating Virtual Network and Subnets"
        $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $serviceFabricResourceGroupName `
            -Name $vnetName `
            -AddressPrefix $serviceFabricVNetAddressPrefix `
            -Location $location

        Add-AzureRmVirtualNetworkSubnetConfig -Name $serviceFabricFrontEndSubnetName `
            -VirtualNetwork $vnet `
            -AddressPrefix $serviceFabricFrontEndSubnetAddressPrefix

        Add-AzureRmVirtualNetworkSubnetConfig -Name $serviceFabricBackEndSubnetName `
            -VirtualNetwork $vnet `
            -AddressPrefix $serviceFabricBackEndSubnetAddressPrefix

        Add-AzureRmVirtualNetworkSubnetConfig -Name $serviceFabricManagementSubnetName `
            -VirtualNetwork $vnet `
            -AddressPrefix $serviceFabricManagementSubnetAddressPrefix

        Add-AzureRmVirtualNetworkSubnetConfig -Name $serviceFabricWAFSubnetName `
            -VirtualNetwork $vnet `
            -AddressPrefix $serviceFabricWAFSubnetAddressPrefix

        # Save vnet changes to Azure
        Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

        Write-Host "Finished creating Virtual Network and Subnets"
    }
}


function CreateActiveDirectoryApplicationForServiceFabric {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $promptResult = [Microsoft.VisualBasic.Interaction]::MsgBox("Setup Azure Active Directory so the cluster can use it to authenticate?",'YesNo,Question', "Respond please")

    if($promptResult -eq "Yes")
    {
        $azureSubscription = Get-AzureSubscription -SubscriptionId $SubscriptionId
        $replyUrl = "https://" + $serviceFabricClusterNameDNSName + ":19080/Explorer"
        $serviceFabricClusterName = $serviceFabricClusterNameDNSName
        .\MicrosoftAzureServiceFabric-AADHelpers\SetupApplications.ps1 -TenantId $azureSubscription.TenantId -ClusterName $serviceFabricClusterName -WebApplicationReplyUrl $replyUrl

        Write-Host "Make sure you now add the ARM template parameters above for azureActiveDirectory to the Service Fabric parameters file before you run the script to create the Service Fabric environment" -ForegroundColor Green
    }
}

function CreateStaticIP {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $promptResult = [Microsoft.VisualBasic.Interaction]::MsgBox("Create a static public IP number?",'YesNo,Question', "Respond please")

    if($promptResult -eq "Yes")
    {
        Write-Host "Create Public IP Address Resource group if it does not exist"
        $ipNumberResourceGroup = Get-AzureRMResourceGroup -Name $ipNumberResourceGroupName -EA SilentlyContinue
        if ($ipNumberResourceGroup -eq $null)
        {
            Write-Host "Creating resource group: $ipNumberResourceGroupName"

            New-AzureRmResourceGroup -Name $ipNumberResourceGroupName -Location $location
        }
        else
        {
            Write-Host "Resource group $ipNumberResourceGroupName already exists so skipping the creation of it"
        }


        Write-Host "Create Public Static IP Address if it does not exist"
        $ipNumber = Get-AzureRmPublicIpAddress -Name $ipNumberNameFrontEnd -ResourceGroupName $ipNumberResourceGroupName -EA SilentlyContinue
        if ($ipNumber -eq $null)
        {
            Write-Host "Creating IP number: $ipNumberNameFrontEnd"

            $ipNumber = New-AzureRmPublicIpAddress -AllocationMethod Static -ResourceGroupName $ipNumberResourceGroupName -Location $location -Name $ipNumberNameFrontEnd -DomainNameLabel $ipNumberNameFrontEnd
        }
        else
        {
            Write-Host "IP number $ipNumberNameFrontEnd already exists so skipping the creation of it"
        }
    }
}

function CreateKeyVault {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $promptResult = [Microsoft.VisualBasic.Interaction]::MsgBox("Create a key vault?",'YesNo,Question', "Respond please")

    if($promptResult -eq "Yes")
    {
        Write-Host "Create Key Vault Resource group if it does not exist"
        $keyVaultResourceGroup = Get-AzureRMResourceGroup -Name $keyVaultResourceGroupName -EA SilentlyContinue
        if ($keyVaultResourceGroup -eq $null)
        {
            Write-Host "Creating resource group: $keyVaultResourceGroupName"

            New-AzureRmResourceGroup -Name $keyVaultResourceGroupName -Location $location
        }
        else
        {
            Write-Host "Resource group $keyVaultResourceGroupName already exists so skipping the creation of it"
        }

        Write-Host "Create or Get Key Vault if it does not exist"
        $keyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName -EA SilentlyContinue
        if ($keyVault -eq $null)
        {
            Write-Host "Creating key vault: $keyVaultName"

            $keyVault = New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName -Location $location -EnabledForDeployment

            # Grant key vault permissions to this user
            Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -UserPrincipalName $keyVaultAdminName -PermissionsToCertificates all
        }
        else
        {
            Write-Host "Key vault $keyVaultName already exists so skipping the creation of it"
        }


        $promptResult = [Microsoft.VisualBasic.Interaction]::MsgBox("Create a self signed cert for NON PRODUCTION clusters in the key vault?",'YesNo,Question', "Respond please")

        if($promptResult -eq "Yes")
        {
            # *** Create a self signed cert for NON PRODUCTION cluster ***
            $newCertName = "sfclustercertificate"
            $dnsName = $serviceFabricClusterNameDNSName #The certificate's subject name must match the domain used to access the Service Fabric cluster.

            Write-Host "Creating cert in Azure Key Vault"

            $policy = New-AzureKeyVaultCertificatePolicy -SubjectName "CN=$dnsName" -IssuerName Self -ValidityInMonths 48
            $cert = Add-AzureKeyVaultCertificate -VaultName $keyVaultName -Name $newCertName -CertificatePolicy $policy 
            

            # Need to wait here until cert is created in Azure then get it again

            Write-Host "Check the Azure portal and press any key to continue once the cert has been created"
            [Microsoft.VisualBasic.Interaction]::MsgBox("Check the Azure portal and click ok to continue once the cert has been created",'OkOnly,Question', "Respond please")
            
            $cert = Get-AzureKeyVaultCertificate -Name $newCertName -VaultName $keyVaultName -ErrorAction SilentlyContinue
 
            Write-Host "Source key vault: " $keyVault.ResourceId -ForegroundColor Green
            Write-Host "Certificate URL: " $cert.SecretId -ForegroundColor Green
            Write-Host "Certificate thumbprint: " $cert.Thumbprint -ForegroundColor Green

            Write-Host "Add these to the service fabric parameters json file" -ForegroundColor Green
        }
    }
}


function CreateServiceFabricResourceGroup {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $promptResult = [Microsoft.VisualBasic.Interaction]::MsgBox("Create service fabric resource group?",'YesNo,Question', "Respond please")

    if($promptResult -eq "Yes")
    {
        Write-Host "Create Service Fabric Cluster Resource group if it does not exist"
        $serviceFabricClusterResourceGroup = Get-AzureRMResourceGroup -Name $serviceFabricResourceGroupName -EA SilentlyContinue
        if ($serviceFabricClusterResourceGroup -eq $null)
        {
            Write-Host "Creating resource group: $serviceFabricResourceGroupName"

            New-AzureRmResourceGroup -Name $serviceFabricResourceGroupName -Location $location
        }
        else
        {
            Write-Host "Resource group $serviceFabricResourceGroupName already exists so skipping the creation of it"
        }
    }
}


$ErrorActionPreference = "Stop"    # Stop as soon as an error occurs
$WebAppApiVersion = "2015-08-01"

Login-AzureRmAccount


Select-AzureRmSubscription -SubscriptionId $SubscriptionId
Get-AzureRmSubscription
Set-AzureRmContext -SubscriptionId $SubscriptionId


# Lets create it
CreateStaticIP

CreateKeyVault
     
CreateActiveDirectoryApplicationForServiceFabric

CreateServiceFabricResourceGroup

CreateVirtualNetworkAndSubnetsForServiceFabric


#--------------------------------------------------------------------------------------------------------------------------------
Write-Host "Now go and create the service fabric environment by running script .\secureTemplateAnd3NodeTypeWithApplicationGatewayAndExistingSubnet\deploy.ps1 after you have updated the parameters json file" -ForegroundColor Green
Write-Host "e.g: .\deploy.ps1 -subscriptionId $SubscriptionId -resourceGroupName $serviceFabricResourceGroupName -deploymentName sfcluster -parametersFilePath .\parameters.json"

Write-Host "All done" -ForegroundColor Green



#If you just need to get the certificate values you can use the below script
#$newCertName = "sfclustercertificate"
#$keyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName -EA SilentlyContinue
#$cert = Get-AzureKeyVaultCertificate -Name $newCertName -VaultName $keyVaultName -ErrorAction SilentlyContinue
#Write-Host "Source key vault: " $keyVault.ResourceId -ForegroundColor Green
#Write-Host "Certificate URL: " $cert.SecretId -ForegroundColor Green
#Write-Host "Certificate thumbprint: " $cert.Thumbprint -ForegroundColor Green


