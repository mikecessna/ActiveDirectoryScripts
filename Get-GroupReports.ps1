if(!(Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
$outputpath="C:\BIN\GroupReports"
#create output dir if it doesn't exit
If(!(Test-Path -Path $outputpath)) {
    try {New-Item -ItemType Directory -Force -Path $outputpath
    } catch {
        "Can't create Output Directory: $outputpath"
    }
}

$groups=Get-ADGroup -Filter * -Properties *
#get empty groups
$empty= $groups | ?{$_.Members.Count –eq 0 }
#get-nonempty groups
$notempty= $groups | ?{$_.Members.Count -ne 0}
#Get security groups
$secgrps= $groups | ?{$_.GroupCategory -eq 'Security'}
$secgrpsempty=$secgrps | ?{$_.Members.Count –eq 0 }
#Get Distro groups
$distrogrps= $groups | ?{$_.GroupCategory -eq 'Distribution'}
$distrogrpsempty= $distrogrps | ?{$_.Members.Count –eq 0 }

#Export Groups info
#set up the properties to output
$propArray=@("CN",
            "DisplayName",
            "SamAccountName",
            "Description",
            "Created",
            "Modified",
            "GroupCategory",
            "GroupScope",
            "DistinguishedName",
            "CanonicalName"
)

$groups | select $propArray | Export-Csv -Path (Join-Path $outputpath "Groups.csv") -NoTypeInformation
$empty | select $propArray | Export-Csv -Path (Join-Path $outputpath "EmptyGroups.csv") -NoTypeInformation
$notempty | select $propArray | Export-Csv -Path (Join-Path $outputpath "NonEmptySecurityGroups.csv") -NoTypeInformation
$secgrps | select $propArray | Export-Csv -Path (Join-Path $outputpath "SecurityGroups.csv") -NoTypeInformation
$secgrpsempty | select $propArray | Export-Csv -Path (Join-Path $outputpath "EmptySecurityGroups.csv") -NoTypeInformation
$distrogrps | select $propArray | Export-Csv -Path (Join-Path $outputpath "DistroGroups.csv") -NoTypeInformation
$distrogrpsempty | select $propArray | Export-Csv -Path (Join-Path $outputpath "EmptyDistroGroups.csv") -NoTypeInformation

#output stats
Write-Output "Total Groups: "$groups.Count
Write-Output "Empty Groups: " $empty.Count
Write-Output "Non-empty Groups: " $notempty.Count
Write-Output "Security Groups: " $secgrps.Count
Write-Output "Empty Sec Groups: " $secgrpsempty.Count
Write-Output "Distribution Groups: " $distrogrps.Count
Write-Output "Empty Distro Groups: " $distrogrpsempty.Count
