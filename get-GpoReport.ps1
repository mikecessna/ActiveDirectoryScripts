Import-Module ActiveDirectory
Import-Module GroupPolicy

$outputpath="C:\BIN\GPOreports"

#create output dirs
New-Item -ItemType Directory -Force -Path $outputpath
#create reports sub dir
New-Item -ItemType Directory -Force -Path (Join-Path $outputpath "Reports")

#get a list of all the GPOs
$GPOs= Get-GPO -All

#Get GPOs with All Settings Disabled
$reportFile=$outputpath + "\GPO-AllSettiingsDisabled.csv"

Set-Content -Path $reportFile -Value ("GPO Name,Settings")
$GPOs | ?{$_.GpoStatus -eq "AllSettingsDisabled"} | %{Add-Content -Path $reportFile -Value ($_.displayname+","+$_.gpostatus)}


#get report of GPO Applies to Permissions
$reportFile=$outputpath + "\GPOApplyToPermissions.csv"

Set-Content -Path $reportFile -Value ("GPO Name,User/Group,Denied")
$GPOs | %{
    $gpoName = $_.displayName
    [int]$counter = 0
    $security = $_.GetSecurityInfo()
    $security | where{ $_.Permission -eq "GpoApply" } | %{
        add-Content -Path $reportFile -Value ($gpoName + "," + $_.trustee.name+","+$_.denied)
        $counter += 1
    }
    if ($counter -eq 0)
    {
        add-Content -Path $reportFile -Value ($gpoName + ",NOT APPLIED")
    }
}

#Get a report of GPO Links and WMI Filters
$reportFile=$outputpath + "\GPOLinksAndWMIFilters.csv"

Set-Content -Path $reportFile -Value ("GPO Name,# Links,Link Path,Enabled,No Override,WMI Filter")

$gpmc = New-Object -ComObject GPMgmt.GPM
$constants = $gpmc.GetConstants()
$GPOs | %{
    [int]$counter = 0
    [xml]$report = $_.GenerateReport($constants.ReportXML)
    try
    {
        $wmiFilterName = $report.gpo.filtername
    }
    catch
    {
        $wmiFilterName = "none"
    }
    $report.GPO.LinksTo | % {
        if ($_.SOMPath -ne $null)
        {
            $counter += 1
            add-Content -Path $reportFile -Value ($report.GPO.Name + "," + $report.GPO.linksto.Count + "," + $_.SOMPath + "," + $_.Enabled + "," + $_.NoOverride + "," + $wmiFilterName)
        }
    }
    if ($counter -eq 0)
    {
        add-Content -Path $reportFile -Value ($report.GPO.Name + "," + $counter + "," + "NO LINKS" + "," + "NO LINKS" + "," + "NO LINKS")
    }
}


#create an HTML Report for each GPO

$GPOs | %{
    #remove illegal characters from name
    $displayname= [RegEx]::Replace($_.displayname, "[{0}]" -f ([RegEx]::Escape(-join [System.IO.Path]::GetInvalidFileNameChars())), '')
    $reportFile=$outputpath + "\Reports\" + $displayname +".html"
    Get-GPOReport -name $_.displayname -ReportType html -path $reportFile
}


#Zip up the ouutput folder (requires .NET 4.5)
$src = $outputpath
$dst = $outputpath + "GPOreports.zip"
[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )
[System.IO.Compression.ZipFile]::CreateFromDirectory($src, $dst)
