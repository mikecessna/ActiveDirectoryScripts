# Script to find servers in AD and output any services running as a 'non-normal' account.

#Load the AD module if not already loaded.
If (!(Get-module Activedirectory )) {Import-Module Activedirectory}


$systemservicenames=@("LocalSystem",
    "NT AUTHORITY\LocalService",
    "NT AUTHORITY\Local Service",
    "NT AUTHORITY\NetworkService",
    "NT AUTHORITY\Network Service")
$outputfile="C:\bin\ServiceAccounts.csv"

$services=@()
$servers=@()
$output=@()
$alive=0
$dead=0
$cred=Get-Credential
#get server list from AD
Write-Host "Finding Computer Objects in AD"
$ADservers=Get-ADComputer -filter * -Properties OperatingSystem | ?{$_.OperatingSystem -like "*SERVER*"}
$found=$ADservers.count
Write-Output "Found $found Server objects in Active Directory."
#test is server is alive
$i=1
Foreach($ADserver in $ADservers){
    Write-Progress -Activity "Checking for Live Servers" -Status "Working on [$i out of $found] $ADserver" -PercentComplete ($i++/$Found*100)
    if(Test-Connection -Count 1 -ComputerName $ADserver.name -ErrorAction SilentlyContinue){
        #Write-Output "Got a live one:" $ADserver.name
        $servers+=$ADserver
        $alive++
    } else {
        #Write-Output "Got a Dead One:" $ADserver.name
        $dead++
    }
}

$i=1
foreach ($server in $servers) {
    Write-progress -Activity "Getting Services from Servers" "Working on host[$i out of $alive]: $server" -PercentComplete ($i++/$alive*100)
    $services=Get-WmiObject win32_service -ComputerName $server.name -Credential $cred | where {$systemservicenames -notcontains $_.startname}
    if($services.count -ne $null) {
        foreach ($service in $services) {
            #Write-Output "Service Account found!"
            $objService=New-Object system.object
            $objservice | Add-Member -Type NoteProperty -Name Server -Value $server
            $objservice | Add-Member -Type NoteProperty -Name ServiceName -Value $service.name
            $objservice | Add-Member -Type NoteProperty -Name StartName -Value $service.startname
            $output+=$objservice
        }
    }
}
$output | Export-Csv $outputfile -NoTypeInformation

Write-Output "Servers found in AD: $found"
Write-Output "Live Servers: $alive"
Write-Output "Dead Servers: $dead"
