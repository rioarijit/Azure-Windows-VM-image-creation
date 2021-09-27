# Azure-Windows-VM-image-creation
creation of windows 2019 custom images for azure vm
This powershell script will create a Windows 2019 custom image for Azure VM in shared inmage gallery
The script assumes that existing environment is already created, like ReosuceGroup, VirtualNetwork, StorageAccount, SharedImageGallery, ImageDefinition
The script can be used with Azure Runbook for creation fo automated Windows 2019 images
Since the temporary VM created during this process does not have any Public interface, the custom script kept at blob storage is accessed via PrivateEndpoint
