# vCDSitePair.psm1

# Function to return current vCloud Site Name (if any)
Function Get-vCloudSiteName(
    [Parameter(Mandatory=$true)][String]$siteDomain
)
{
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -ApiVersion '29.0'
    return $localAssociationData.SiteAssociationMember.SiteName
}

Function Set-vCloudSiteName(
    [Parameter(Mandatory=$true)][String]$siteDomain,
    [Parameter(Mandatory=$true)][String]$siteName,
    [Int]$Timeout = 30
)
{
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -ApiVersion '29.0'
    $localAssociationData.SiteAssociationMember.SiteName = $siteName
    $editURI = $localAssociationData.SiteAssociationMember.Link | Where-Object{ $_.rel -eq 'edit' }
    $response = Invoke-vCloud -URI $editURI.href -ContentType 'application/vnd.vmware.admin.siteAssociation+xml' -Method Put -ApiVersion '29.0' -Body $localAssociationData.InnerXml -WaitForTask $true
    return $response
}

# Function to list existing vCD site associations
Function Get-vCloudSiteAssociations
(
    [Parameter(Mandatory=$true)][uri]$siteDomain
)
{
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -ApiVersion '29.0'
    $sitename = $localAssociationData.SiteAssociationMember.SiteName
    $siteid   = $localAssociationData.SiteAssociationMember.SiteId
    Write-Host -ForegroundColor Green "Displaying site associations for site Id: $siteid with site Name: $sitename"
    [xml]$siteAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations" -ApiVersion '29.0'
    $members = $siteAssociationData.SiteAssociations.SiteAssociationMember
    if ($members.HasChildNodes) {
        Write-Host -ForegroundColor Green "Associated sites:"
        Write-Host ($members.RestEndpoint)
     } else {
        Write-Host "No site associations found"
     }
     return $members
}

# Function to pair two vCD sites - you must be connected to BOTH sites as a System context user for this to work
Function Invoke-vCDPairSites(
    [Parameter(Mandatory=$true)][uri]$siteAuri,
    [Parameter(Mandatory=$true)][uri]$siteBuri,
    [Boolean]$WhatIf = $true
)
{
    if ($WhatIf) { 
        Write-Host -ForegroundColor Green 'Running in information mode only - no API changes will be made unless you run with -WhatIf $false'
    } else {
        Write-Host -ForegroundColor Green 'Running in implementation mode, API changes will be committed'
    }
    [xml]$sALAD = Invoke-vCloud -URI "https://$siteAuri/api/site/associations/localAssociationData" -ApiVersion '29.0'
    $sAName = $sALAD.SiteAssociationMember.SiteName
    Write-Host -ForegroundColor Green "Site A returned site ID as: $($sALAD.SiteAssociationMember.SiteId)"
    Write-Host -ForegroundColor Green "Site A returned site name as: $sAName"

    [xml]$sBLAD = Invoke-vCloud -URI "https://$siteBuri/api/site/associations/localAssociationData" -ApiVersion '29.0'
    $sBName = $sBLAD.SiteAssociationMember.SiteName
    Write-Host -ForegroundColor Green "Site B returned site ID as: $($sBLAD.SiteAssociationMember.SiteId)"
    Write-Host -ForegroundColor Green "Site B returned site name as: $sBName"

    If (!$sAName -or !$sBName) {
        Write-Host -ForegroundColor Red "Site name is missing for one or more sites, configure with Set-vCloudSiteName before using vCD-PairSites, exiting"
        return
    }

    If ($sALAD.SiteAssociationMember.SiteId -eq $sBLAD.SiteAssociationMember.SiteID) {
        Write-Host -ForegroundColor Red "Site Id's for site A and site B are identical, vCD-PairSites must be used between different vCD Cells, exiting"
        return
    }

    if (!$WhatIf) {
        Write-Host -ForegroundColor Green "Associating $sAName (Site A) with $sBName (Site B)"
        $result = Invoke-vCloud -URI "https://$siteBuri/api/site/associations" -Method POST -Body $sALAD.InnerXml -ContentType 'application/vnd.vmware.admin.siteAssociation+xml' -ApiVersion '29.0' -WaitForTask $true
        Write-Host "Returned Result = $result"
        Write-Host -ForegroundColor Green "Associating $sBName (Site B) with $sAName (Site A)"
        $result = Invoke-vCloud -URI "https://$siteAuri/api/site/associations" -Method POST -Body $sBLAD.InnerXml -ContentType 'application/vnd.vmware.admin.siteAssociation+xml' -ApiVersion '29.0' -WaitForTask $true
        Write-Host "Returned Result = $result"
    } else {
        Write-Host -ForegroundColor Yellow "Not performing site association as running in information mode"
    }
}

#Function to pair Organisations between vCD Sites
Function Invoke-vCDPairOrgs(
    [Parameter(Mandatory=$true)][string]$siteAuri,
    [Parameter(Mandatory=$true)][string]$siteBuri,
    [Parameter(Mandatory=$true)][string]$OrgName
)
{
    Write-Host -ForegroundColor Green "Attempting to configure site pairing for Organisation $OrgName between vCD sites $siteAuri and $siteBuri"
    # Check we can see the org in both sites:
    $OrgA = Get-Org -Server $siteAuri -Name $OrgName -ErrorAction SilentlyContinue
    $OrgB = Get-Org -Server $siteBuri -Name $OrgName -ErrorAction SilentlyContinue

    if (!$OrgA) { Write-Warning "Could not match $OrgName in $siteAuri, exiting."; return $false }
    if (!$OrgB) { Write-Warning "Could not match $OrgName in $siteBuri, exiting."; return $false }

    # Retrieve the localAssociationData from each Site:
    $SiteALAD = Invoke-vCloud -URI "$($OrgA.Href)/associations/localAssociationData" -ApiVersion '29.0'
    $SiteBLAD = Invoke-vCloud -URI "$($OrgB.Href)/associations/localAssociationData" -ApiVersion '29.0'

    # POST the associationData to the partner Site:
    Write-Host -ForegroundColor Green "Associating $OrgName in $siteAuri (Site A) with $siteBuri (Site B)"
    $result = Invoke-vCloud -URI "$($OrgA.Href)/associations" -Method POST -Body $SiteBLAD.InnerXML -ContentType 'application/vnd.vmware.admin.organizationAssociation+xml' -ApiVersion '29.0' -WaitForTask $true
    Write-Host "Returned result = $result"
    Write-Host -ForegroundColor Green "Associating $OrgName in $siteBuri (Site B) with $siteAuri (Site A)"
    $result = Invoke-vCloud -URI "$($OrgB.Href)/associations" -Method POST -Body $SiteALAD.InnerXML -ContentType 'application/vnd.vmware.admin.organizationAssociation+xml' -ApiVersion '29.0' -WaitForTask $true
    Write-Host "Returned result = $result"
    return
}

Export-ModuleMember -Function 'Get-vCloudSiteName'
Export-ModuleMember -Function 'Set-vCloudSiteName'
Export-ModuleMember -Function 'Get-vCloudSiteAssociations'
Export-ModuleMember -Function 'Invoke-vCDPairSites'
Export-ModuleMember -Function 'Invoke-vCDPairOrgs'