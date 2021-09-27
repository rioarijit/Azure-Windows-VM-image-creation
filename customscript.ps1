mkdir c:\\build
#############################
######ADD CUSTOM SCRIPT######
Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList '/generalize /code /shutdown'