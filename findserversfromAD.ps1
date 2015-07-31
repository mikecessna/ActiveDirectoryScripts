# Script to find servers in AD and output info

#Load the AD module if not already loaded.
If (!(Get-module Activedirectory )) {Import-Module ActiveDirectory}


$outputfile="C:\bin\DiscoveredServers.csv"

$output=@()
$alive=0
$dead=0
#get server list from AD
Write-Host "Finding Computer Objects in AD"
#$ADservers=Get-ADComputer -filter * -Properties OperatingSystem,Description | ?{$_.OperatingSystem -like "*SERVER*"}
$ADservers=Get-ADComputer -Properties Operatingsystem,Description,DistinguishedName -Filter 'operatingsystem -like "*SERVER*" -and enabled -eq "true"'
$found=$ADservers.count
Write-Output "Found $found Server objects in Active Directory."
#test is server is alive
$i=1
Foreach($ADserver in $ADservers){
    Write-Progress -Activity "Gathering Info from Servers" -Status "Working on [$i out of $found] $ADserver" -PercentComplete ($i++/$Found*100)
    #setup obj for output
    $objService=New-Object system.object
    $server=$ADserver.Name
    $objservice | Add-Member -Type NoteProperty -Name Server-AD -Value $server
    #get the DNS resolved IP
    $ip = $null
    try {
        $ip = ([System.Net.Dns]::GetHostAddresses("$server").IPAddressToString | Out-String).Trim()
    } catch {
        $ip = "N/A"
    } 
    $objservice | Add-Member -Type NoteProperty -Name ResolvedIP -Value $ip
    $DNSHostname=$null
    $MACAddress=$null
    $IPAddress=$null
    $DNSServerSearchOrder=$null
    if(Test-Connection -Count 1 -ComputerName $ADserver.name -ErrorAction SilentlyContinue){
        #Write-Output "Got a live one:" $ADserver.name
        $objservice | Add-Member -Type NoteProperty -Name Pingable -Value "Yes"
        $alive++
        $WmiInfo=@()
        try{
            $ErrorActionPreference="Stop"
            $WMIinfo=get-wmiobject win32_networkadapterconfiguration -computer $server -filter "IPEnabled='True'" | Select DNSHostname,MACAddress,IPAddress,DNSServerSearchOrder
        } catch {
            "Error Connecting to $ADserver"
            $objservice | Add-Member -Type NoteProperty -Name WMI-Connect -Value "No"
            continue
        } Finally {
            $ErrorActionPreference="Continue"
        }
        $DNSHostname=($WmiInfo.DNSHostname | Out-String).Trim()
        $MACAddress=($WMIinfo.MACAddress | Out-String).Trim()
        $IPAddress=($WMIinfo.IPAddress | Out-String).Trim()
        $DNSServerSearchOrder=$WmiInfo.DNSServerSearchOrder
        $objservice | Add-Member -Type NoteProperty -Name WMI-Connect -Value "Yes"
        $objservice | Add-Member -Type NoteProperty -Name OperatingSystem -Value $ADserver.OperatingSystem
        $objservice | Add-Member -Type NoteProperty -Name AD-Description -Value $ADserver.Description
        $objservice | Add-Member -Type NoteProperty -Name WMI-Hostname -Value $DNSHostname
        $objservice | Add-Member -Type NoteProperty -Name WMI-MACaddress -Value $MACAddress
        $objservice | Add-Member -Type NoteProperty -Name WMI-IPaddress -Value $IPAddress
        $dnscounter=0
        foreach($dns in $DNSServerSearchOrder) {
            $name="DNS" + $dnscounter
            $objservice | Add-Member -Type NoteProperty -Name $name -Value $DNSServerSearchOrder[$dnscounter]
            $dnscounter++
        }
        $OU=($ADserver.DistinguishedName.Split(","))[1..($ADserver.DistinguishedName.Split(",").length)] -join ","
        $objservice | Add-Member -Type NoteProperty -Name OU -Value $OU
    } else {
        $objservice | Add-Member -Type NoteProperty -Name Pingable -Value "No"
        $objservice | Add-Member -Type NoteProperty -Name WMI-Connect -Value "No"
        $objservice | Add-Member -Type NoteProperty -Name OperatingSystem -Value $ADserver.OperatingSystem
        $objservice | Add-Member -Type NoteProperty -Name AD-Description -Value $ADserver.Description
        $dead++
    }
    
    #push the collected data into the output
    $output+=$objservice
}

$output | Export-Csv $outputfile -NoTypeInformation

Write-Output "Servers found in AD: $found"
Write-Output "Live Servers: $alive"
Write-Output "Dead Servers: $dead"