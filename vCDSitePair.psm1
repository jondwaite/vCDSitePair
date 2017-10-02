# vCDSitePair.psm1

# Function to return current vCloud Site Name (if any)
Function Get-vCloudSiteName(
    [Parameter(Mandatory=$true)][String]$siteDomain
)
{
<#
.SYNOPSIS
Return the vCD SiteName for a given site URI (if configured)
.DESCRIPTION
Queries the vCloud REST API and returns the SiteAssociationMember\SiteName
from the /api/site/associations/localAssociationData XML.
.PARAMETER siteDomain
The URI of the site to be accessed, you must be connected to the site
already (Connect-CIServer) with an account that has System level access
to the vCloud Director instance.
.OUTPUTS
Any configured site name from the localAssociationData (or nothing if no site
configuration is returned).
.EXAMPLE
Get-vCloudSiteName -siteDomain 'sitea.api.mycloud.com'
.NOTES
Requires the 'Invoke-vCloud' module to be available in your current session to
function. You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -ApiVersion '29.0'
    return $localAssociationData.SiteAssociationMember.SiteName
}

Function Set-vCloudSiteName(
    [Parameter(Mandatory=$true)][String]$siteDomain,
    [Parameter(Mandatory=$true)][String]$siteName,
    [Int]$Timeout = 30
)
{
<#
.SYNOPSIS
Sets or updates the vCD SiteName for a given site URI
.DESCRIPTION
Configures the vCloud Director 'SiteName' in localAssociationData with the
specified value. If 'SiteNmae' is already configured it will be updated with
the value specified.
.PARAMETER siteDomain
The URI of the site in which the 'SiteName' is to be changed, you must be
connected to the site already (Connect-CIServer) with an account that has
System level access to the vCloud Director instance.
.PARAMETER siteName
The 'SiteName' to be set for this vCloud Director site.
.OUTPUTS
The response from the Invoke-vCloud API call.
.EXAMPLE
Set-vCloudSiteName -siteDomain 'sitea.api.mycloud.com' -siteName 'SiteA'
.NOTES
Requires the 'Invoke-vCloud' module to be available in your current session to
function. You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
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
<#
.SYNOPSIS
Shows any existing vCloud Director site associations for a given vCloud
Director API endpoint.
.DESCRIPTION
Reads the 'siteAssociations' return from /api/site/associations for the
given vCloud Director instance and lists any other vCloud Director sites
which have already been associated with the queried site.
.PARAMETER siteDomain
The URI of the site to query for existing site associations. You must be
connected to the site already (Connect-CIServer) with an account that has
System level access to the vCloud Director instance.
.OUTPUTS
Any configured site associations for the specified vCloud instance.
.EXAMPLE
Get-vCloudSiteAssociations -siteDomain 'sitea.api.mycloud.com'
.NOTES
Requires the 'Invoke-vCloud' module to be available in your current session to
function. You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
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
<#
.SYNOPSIS
Creates a vCloud Director pairing between 2 vCD instances.
.DESCRIPTION
Creates system-level pairing between two vCloud Director sites.
.PARAMETER siteAuri
The URI of the api endpoint for the first site to be paired.
.PARAMETER siteBuri
The URI of the api endpoint for the second site to be paired.
.PARAMETER WhatIf
A flag that determines whether to actually perform the site pairing or just
return information on what would be done.
.OUTPUTS
The results of the pairing attempt from Site A -> Site B and from Site B ->
Site A.
.EXAMPLE
Invoke-vCDPairSites -siteAuri 'sitea.api.mycloud.com' -siteBuri 'siteb.api.mycloud.com' -WhatIf $false
.NOTES
Requires the 'Invoke-vCloud' module to be available in your current session to
function. You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) to both sites in your current PowerShell session for this to
suceed. Will only function against vCloud Director versions 9 and later as the
API calls are not implemented in earlier versions.
#>
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

Export-ModuleMember -Function 'Get-vCloudSiteName'
Export-ModuleMember -Function 'Set-vCloudSiteName'
Export-ModuleMember -Function 'Get-vCloudSiteAssociations'
Export-ModuleMember -Function 'Invoke-vCDPairSites'