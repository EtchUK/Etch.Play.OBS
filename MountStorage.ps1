
param([Parameter(Mandatory=$true)][string]$storageAccountName)

param([Parameter(Mandatory=$true)][string]$fileShareName)

param([Parameter(Mandatory=$true)][string]$storageAccountKey)


$connectTestResult = Test-NetConnection -ComputerName $storageAccountName.file.core.windows.net -Port 445

if ($connectTestResult.TcpTestSucceeded) {
    # Save the password so the drive will persist on reboot
    cmd.exe /C "cmdkey /add:`"$storageAccountName.file.core.windows.net`" /user:`"localhost\$storageAccountName`" /pass:`"$storageAccountKey`""
    # Mount the drive
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$storageAccountName.file.core.windows.net\media" -Persist
} else {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
}