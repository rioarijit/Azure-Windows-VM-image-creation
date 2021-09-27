##POWERSHELL SCRIPT TO CREATE A WINDOWS 2019 DATACENTER IMAGE FOR SHARED IMAGE GALLERY##
##THIS SCRIPT IS NOT USING AZURE IMAGE BUILDER##
##FOR AUTOMATED IMAGE CREATION THE SCRIPT CAN BE USED WITH AZURE RUNBOOK##
##THE SCRIPT ASSUMES THAT PRE-REUISITES FOR CRETING IMAGE IS ALREADY PRESENT. 
##THIS INCLUDES RESOURCE GROUP, VIRTUAL NETWORK, STORAGE ACCOUNT, SHARED IMAGE GALLERY AND SHARED IMAGE GALLERY DEFINITION##
##INCLUDED COMMANDS TO CREATE SHARED IMAGE GALLERY AND IMAGE GALLERY DEFINITION##
##THE SCRIPT WILL NOT REQUIRE ANY PUBLIC IP FOR THE VM. IF ANY CUSTOMIZATION SCRIPT IS STORED IN BLOB, PRIVATE ENDPOINT MUST BE CREATED WITH THE VIRTUAL NETWORK##
##DEFINING PARAMETERS REQURIED FOR THIS SCRIPT##
$location = "<Location>"
$ResourceGroupName = "<ResourceGroupName>"
$StorageAccountName = "<StorageAccountName>"
$VnetName = "<virtualnetworkname>"
$UserName='<username>'
$Password='<Password>'| ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($UserName,$Password)
$VmName = "tempvm"
$VmSize = "Standard_B2s"
$VnetName = "<virtualnetworkname>"
#################################################
##CREATION OF TEMPORARY VM##
Set-AzCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
$vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName
$nic = New-AzNetworkInterface -Name "<tempvmnicname>" -ResourceGroupName $ResourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id
$VirtualMachine = New-AzVMConfig -VMName $VmName -VMSize $VmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName "Computer" -Credential $Credential -ProvisionVMAgent
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2019-Datacenter" -Version "latest"
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -CreateOption FromImage | Set-AzVMBootDiagnostic -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -Enable | Add-AzVMNetworkInterface -Id $nic.Id
$VM = New-AzVM -ResourceGroupName $ResourceGroupName -Location $location -VM $VirtualMachine
############################
##CUSTOMIZATION OF VM##
##INCLUDE SYSPREP IN THE CUSTOM SCRIPT##
##THE SSCRIPT IS USING SAS CONNECTIVITY OVER PRIVATE ENDPOINT TO THE BLOB FOR THE CUSTOM SCRIPT##
$fileUri = @("https://<path of custom powershell script.ps1>")
$Settings = @{"fileUris" = $fileUri};
$ProtectedSettings = @{"commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File 1_Add_Tools.ps1"};
Set-AzVMExtension -ResourceGroupName $ResourceGroupName -Location $location -VMName $VmName -Name "buildserver" -Publisher "Microsoft.Compute" -ExtensionType "CustomScriptExtension" -TypeHandlerVersion "1.10" -Settings $settings -ProtectedSettings $protectedSettings
sleep -seconds 120
Stop-AzVM -Name $VmName -ResourceGroupName $ResourceGroupName
sleep -seconds 60
Set-azvm -Name $VmName -ResourceGroupName $ResourceGroupName -Generalized
sleep -seconds 60
#######################
##GETTING DETAILS OF SHARED IMAGE GALLERY AND IMAGE DEFINITION##
$gallery = Get-AzGallery -GalleryName "<nameOfImageGallery>" -ResourceGroupName $ResourceGroupName
##IF GALLERY IS NOT CREATED PELASE USE THE BELOW COMMAND TO CREATE THE SAME##
##$gallery = New-AzGallery -GalleryName 'ameOfImageGallery' -ResourceGroupName $ResourceGroupName -Location $Location -Description 'Shared Image Gallery for my organization'
$galleryImage = Get-AzGalleryImageDefinition -GalleryName $gallery.Name -ResourceGroupName $ResourceGroupName -Name "<ImageDefinition>"
##IF GALLERY IMAGE DEFINITION IS NOT CREATED PELASE USE THE BELOW COMMAND TO CREATE THE SAME##
##$galleryImage = New-AzGalleryImageDefinition -GalleryName $gallery.Name -ResourceGroupName $ResourceGroupName -Location $Location -Name '<ImageDefinition>' -OsState Generalized -OsType Windows -Publisher '<publishername>' -Offer '<Offer>' -Sku '<SKU>'
################################################################
##CREATING IMAGE VERSION##
$region1 = @{Name='West US';ReplicaCount=1}
$region2 = @{Name='East US';ReplicaCount=2}
$targetRegions = @($region1,$region2)
##THE GALLERY IMAGE VERSION NAME WILL BE CREATED AS YYYY.MM.0##
##THE GALLERY IMAGE VERSION WILL BE EXPIRED AFTER THREE MONTHS OF CREATION##
$GalleryImageVersionName = [string](Get-date).Year + "." + [string](Get-date).Month + ".0"
$GalleryImageVerisonExpiryDate = (Get-date).AddDays(90)
New-AzGalleryImageVersion -GalleryImageDefinitionName $galleryImage.Name -GalleryImageVersionName $GalleryImageVersionName -GalleryName $gallery.Name -ResourceGroupName $ResourceGroupName -Location $Location -TargetRegion $targetRegions  -Source $VM.Id.ToString() -PublishingProfileEndOfLifeDate $GalleryImageVerisonExpiryDate
###########################
##CLEANING RESOURCES##
$osdisk = $VM.StorageProfile.OSDisk.Name
$null = $VM | Remove-az -Force
Get-AzResource -Name $osdisk | Remove-AzResource -Force
#####################
#######################################################################
 
