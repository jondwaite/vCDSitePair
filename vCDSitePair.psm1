## vCDSitePair.psm1 - PowerShell Module for configuring vCloud Director multi-
##                    site pairing operations.
## Version:           2.0.1
## Author:            Jon Waite
## Copyright:         Copyright (c) Jon Waite 2020, All Rights Reserved
## Licence:           MIT

# Release Notes:
# Note that a previous version of this module was released which did not support
# operations against vCloud API endpoints which had invalid SSL certificates.
# This module uses the new (in PowerShell 6.x and later) 'SkipCertificateCheck'
# switch added to Invoke-RestMethod. As such it will not work with previous
# versions of PowerShell and requires PowerShell or PowerShell Core v6.0
# or later.

# Each cmdlet is documented, use Get-Help <cmdlet name> for details
# e.g. Get-Help Get-vCloudSiteName

# cmdlets included in this module:
# 
# Name                          Function
# Invoke-vCloud                 Internal Helper function to submit to the vCD API
# Get-vCloudSiteName            Shows current name assigned to a vCloud site
# Set-vCloudSiteName            Sets the name assigned to a vCloud site
# Get-vCloudSiteAssoc           Shows current site associations for a site
# Remove-vCloudSiteAssoc        Removes a site association from a site
# Invoke-vCDPairSites           Create a new site association between 2 sites

# Note:
# This module is intended for use by cloud providers to configure the overall
# ('System' level) site pairing between vCloud Director sites. It is not
# intended to be used by tenants to configure their own pairing between
# tenant organizations in multiple provider sites - the built-in UI has
# the capability for this already by downloading and uploading the site
# association XML files.

# Helper function to interact with the vCloud API (Not exported):
Function Invoke-vCloud{
    [cmdletbinding()]Param(
    [Parameter(Mandatory)][uri]$URI,
    [string]$method = "get",
    [string]$apiVersion = "34.0",
    [string]$body,
    [string]$contentType,
    [int]$timeout = 40,
    [boolean]$waitForTask = $false,
    [boolean]$allowInsecure
)

    # Check if we have a valid PowerCLI session to use:
    $sessionID = ($Global:DefaultCIServers | Where-Object { $_.Name -eq $URI.Host }).SessionID
    if (!$sessionID) {                              # If we didn't find an existing PowerCLI session for our URI
        Write-Error ("No PowerCLI session found for $($uri), exiting.")
        break
    }

    $headers = @{ "x-vcloud-authorization" = $sessionID; "Accept" = "application/*+xml;version=$($apiVersion)" }

    $parms =  @{'Method'=$method; 'URI'=$uri; 'headers'=$headers; 'timeout'=$timeout;}

    if ($ContentType)   { $parms.Add("ContentType", $ContentType) }
    if ($Body)          { $parms.Add("Body",$Body) }
    if ($allowInsecure) { $parms.Add("SkipCertificateCheck",$true) }

    # Send request:
    Try {
        [xml]$response = Invoke-RestMethod @parms
    } catch { # Error returned
        Write-Warning ("Exception: $($_.Exception.Message)")
        if ( $_.Exception.ItemName ) { Write-Warning ("Failed Item: $($_.Exception.ItemName)") }
        Return
    }

    if ($waitForTask) {                             # If we've asked to wait for async task to complete
        if ($response.Task.href) {                  # and we've got a Task event returned

            $taskparams = @{'Method'='Get'; 'URI'=$response.Task.href; 'headers'=$headers; 'TimeoutSec'=5}
            if ($allowInsecure) { $taskparams.Add("SkipCertificateCheck",$true) }

            Write-Host ("Task submitted successfully, waiting for completion or timeout.")
            Write-Host ("q=queued, P=pre-running, .=Running:")
            while ($timeout -gt 0) {                # while within our timeout
                Try {
                    $taskxml = Invoke-RestMethod @taskparams
                } catch {
                    Write-Warning ("Exception while waiting for task to complete: $($_.Exception.Message)")
                    if ( $_.Exception.ItemName ) { Write-Warning ("Failed Item: $($_.Exception.ItemName)") }
                    Write-Warning ("Task may still be running.")
                    Return
                }
                switch ($taskxml.Task.status) {
                    "success"    { Write-Host " "; Write-Host "Task completed successfully"; return $true; break }
                    "running"    { Write-Host -NoNewline "." }
                    "error"      { write-Host " "; Write-Warning "Error running task"; return $false; break }
                    "canceled"   { Write-Host " "; Write-Warning "Task was cancelled"; return $false; break }
                    "aborted"    { Write-Host " "; Write-Warning "Task was aborted"; return $false; break }
                    "queued"     { Write-Host -NoNewline "q" }
                    "preRunning" { Write-Host -NoNewline "P" }
                }
                $timeout -= 1
                Start-Sleep -s 1
            } # Timeout expired
            Write-Warning "Task timeout reached (task may still be in progress)"
            return $false
        } else {
            Write-Host ("Wait for task requested, but no Task returned from API")
        }
    }
    return $response                                # return API query response
}

Function Get-vCloudSiteName{
<#
.SYNOPSIS
Return the vCD SiteName for a given site URI (if configured)
.DESCRIPTION
Queries the vCloud REST API and returns the SiteAssociationMember\SiteName
from the /api/site/associations/localAssociationData XML.
.PARAMETER siteDomain
The URI of the site to be accessed, you must be connected to the site
already (Connect-CIServer) with an account that has System level access
to this vCloud Director instance.
.PARAMETER allowInsecure
If specified this parameter allows interaction with vCloud API endpoints
using an invalid SSL certificate (not recommended in production). If not
specified the vCloud API must use a trusted SSL certificate.
.OUTPUTS
Any configured site name from the localAssociationData (or nothing if no site
configuration is returned).
.EXAMPLE
Get-vCloudSiteName -siteDomain 'sitea.mycloud.com'
.NOTES
You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
    [cmdletbinding()]Param(
        [Parameter(Mandatory=$true)][string]$siteDomain,
        [switch]$allowInsecure
    )
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -Method 'Get' -ApiVersion $apiVersion # -allowInsecure $allowInsecure
    return $localAssociationData.SiteAssociationMember.SiteName
}

Function Set-vCloudSiteName{
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
.PARAMETER allowInsecure
If specified this parameter allows interaction with vCloud API endpoints
using an invalid SSL certificate (not recommended in production). If not
specified the vCloud API must use a trusted SSL certificate.
.OUTPUTS
The response from the Invoke-vCloud API call.
.EXAMPLE
Set-vCloudSiteName -siteDomain 'sitea.mycloud.com' -siteName 'SiteA'
.NOTES
You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
    [CmdletBinding()]Param(
        [Parameter(Mandatory=$true)][string]$siteDomain,
        [Parameter(Mandatory=$true)][String]$siteName,
        [switch]$allowInsecure,
        [Int]$Timeout = 30
    )
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -Method 'Get' -ApiVersion $apiVersion  -allowInsecure $allowInsecure
    $localAssociationData.SiteAssociationMember.SiteName = $siteName
    $editURI = $localAssociationData.SiteAssociationMember.Link | Where-Object{ $_.rel -eq 'edit' } | ? type -eq "application/vnd.vmware.admin.siteAssociation+xml"
    $response = Invoke-vCloud -URI $editURI.href -ContentType 'application/vnd.vmware.admin.siteAssociation+xml' -Method 'Put' -ApiVersion $apiVersion  -Body $localAssociationData.InnerXml -WaitForTask $true -allowInsecure $allowInsecure
    return $response
}

Function Get-vCloudSiteAssoc{
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
.PARAMETER allowInsecure
If specified this parameter allows interaction with vCloud API endpoints
using an invalid SSL certificate (not recommended in production). If not
specified the vCloud API must use a trusted SSL certificate.
.OUTPUTS
Any configured site associations for the specified vCloud instance.
.EXAMPLE
Get-vCloudSiteAssociations -siteDomain 'sitea.mycloud.com'
.NOTES
You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
    [CmdletBinding()]Param(
        [Parameter(Mandatory=$true)][string]$siteDomain,
        [switch]$allowInsecure,
        [Int]$Timeout = 30
    )
    [xml]$localAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations/localAssociationData" -Method 'Get' -ApiVersion $apiVersion  -allowInsecure $allowInsecure
    $sitename = $localAssociationData.SiteAssociationMember.SiteName
    $siteid   = $localAssociationData.SiteAssociationMember.SiteId
    Write-Host -ForegroundColor Green ("Site associations for site Id: $($siteid) with site Name: $($sitename)")
    [xml]$siteAssociationData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations" -Method 'Get' -ApiVersion $apiVersion  -allowInsecure $allowInsecure
    $members = $siteAssociationData.SiteAssociations.SiteAssociationMember
    if ($members.HasChildNodes) {
        Write-Host -ForegroundColor Green "Associated sites:"
        foreach ($site in $members) {
            $siteId = ($site.SiteId).substring($site.SiteId.LastIndexOf(':')+1)
            Write-Host ("Site: $($site.SiteName) with Site Id: $($siteId) at $(([uri]$site.RestEndpoint).Host)")
        }
     } else {
        Write-Host "No site associations found"
     }
     return $members
}
Function Remove-vCloudSiteAssoc{
<#
.SYNOPSIS
Removes an existing vCloud site association from the specified endpoint
matching the specified remote site Id.
.DESCRIPTION
Allows an existing site association to be removed from a single vCloud
API endpoint. Note that for existing site pairs this will need to be 
done twice (once for each site each time specifying the appropriate
remote site Id) to completely remove the pairing.
.PARAMETER siteDomain
The URI of the site from which the pairing is to be removed. You must be
connected to the site already (Connect-CIServer) with an account that has
System level access to the vCloud Director instance.
.PARAMETER removeId
The site Id of the remote site to be removed from the associations on the
vCloud environment specified by siteDomain. Site Ids can be found using
the Get-vCloudSiteAssoc cmdlet.
.PARAMETER allowInsecure
If specified this parameter allows interaction with vCloud API endpoints
using an invalid SSL certificate (not recommended in production). If not
specified the vCloud API must use a trusted SSL certificate.
.OUTPUTS
None, console messages indicate the success or failure of the removal
attempt.
.EXAMPLE
Remove-vCloudSiteAssoc -siteDomain 'sitea.mycloud.com' -removeId '438061ba-85c6-4b12-bd2c-fdfb820b2a4f'
.NOTES
You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session for calls to suceed. Will
only function against vCloud Director versions 9 and later as this API call is
not implemented in earlier versions.
#>
    [CmdletBinding()]Param(
        [Parameter(Mandatory=$true)][string]$siteDomain,
        [Parameter(Mandatory=$true)][string]$removeId,
        [switch]$allowInsecure,
        [Int]$Timeout = 30
    )

    # Get all current Site Association data into $SAData:
    [xml]$SAData = Invoke-vCloud -URI "https://$siteDomain/api/site/associations" -Method 'Get' -ApiVersion $apiVersion  -allowInsecure $allowInsecure

    # Add Namespace Manager to Site Association Data XML:
    $nsm = New-Object System.Xml.XmlNamespaceManager($SAData.NameTable)
    $nsm.AddNamespace("ns","http://www.vmware.com/vcloud/v1.5")

    # Attempt to locate a node in the XML tree where SiteId matches our removal value:
    $removeNode = $SAData.SelectSingleNode("//ns:SiteId[.='urn:vcloud:site:$($removeId)']", $nsm).ParentNode

    if ($removeNode) {  # We successfully matched this Site Id in the XML
        Write-Host ("Matched site association with site Id $($removeId), removing site association")
        
        # Remove the matching XML node from $SAData:
        $removeNode.ParentNode.RemoveChild($removeNode) | Out-Null

        # And submit the modified XML back to the API:
        Invoke-vCloud -Uri "https://$siteDomain/api/site/associations" `
            -ContentType 'application/vnd.vmware.admin.siteAssociations+xml' `
            -Method 'Put' -apiVersion $apiVersion  -Body $SAData.InnerXml `
            -waitForTask $true -allowInsecure $allowInsecure
        return
    } else {
        Write-Host ("Could not match site association with site Id $($removeId), exiting.")
        return
    }
}

Function Invoke-vCDPairSites{
<#
.SYNOPSIS
Creates a vCloud Director pairing between 2 vCD instances.
.DESCRIPTION
Creates system-level pairing between two vCloud Director sites.
.PARAMETER siteADomain
The domain name of the api endpoint for the first site to be paired.
.PARAMETER siteBDomain
The domain name of the api endpoint for the second site to be paired.
.PARAMETER WhatIf
A flag that determines whether to actually perform the site pairing or just
return information on what would be done.
.PARAMETER allowInsecure
If specified this parameter allows interaction with vCloud API endpoints
using an invalid SSL certificate (not recommended in production). If not
specified the vCloud APIs must use a trusted SSL certificates.
.OUTPUTS
The results of the pairing attempt from Site A -> Site B and from Site B ->
Site A.
.EXAMPLE
Invoke-vCDPairSites -siteADomain 'sitea.mycloud.com' -siteBDomain 'siteb.mycloud.com' -WhatIf $false
.NOTES
You must have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) to both sites in your current PowerShell session for this to
suceed. Will only function against vCloud Director versions 9 and later as the
API calls are not implemented in earlier versions.
#>
    [CmdletBinding()]Param(
        [Parameter(Mandatory=$true)][string]$siteADomain,
        [Parameter(Mandatory=$true)][string]$siteBDomain,
        [Boolean]$WhatIf = $true,
        [switch]$allowInsecure,
        [Int]$Timeout = 30
    )
    
    if ($WhatIf) { 
        Write-Host -ForegroundColor Green 'Running in information mode only - no API changes will be made unless you run with -WhatIf $false'
    } else {
        Write-Host -ForegroundColor Green 'Running in implementation mode, API changes will be committed'
    }

    [xml]$sALAD = Invoke-vCloud -URI "https://$siteADomain/api/site/associations/localAssociationData" -ApiVersion $apiVersion  -allowInsecure $allowInsecure
    $sAName = $sALAD.SiteAssociationMember.SiteName
    Write-Host -ForegroundColor Green "Site A returned site ID as: $($sALAD.SiteAssociationMember.SiteId)"
    Write-Host -ForegroundColor Green "Site A returned site name as: $sAName"

    [xml]$sBLAD = Invoke-vCloud -URI "https://$siteBDomain/api/site/associations/localAssociationData" -ApiVersion $apiVersion  -allowInsecure $allowInsecure
    $sBName = $sBLAD.SiteAssociationMember.SiteName
    Write-Host -ForegroundColor Green "Site B returned site ID as: $($sBLAD.SiteAssociationMember.SiteId)"
    Write-Host -ForegroundColor Green "Site B returned site name as: $sBName"

    If (!$sAName -or !$sBName) {
        Write-Host -ForegroundColor Red "Site name is missing for one or more sites, configure with Set-vCloudSiteName before using vCD-PairSites, exiting"
        return
    }

    If ($sALAD.SiteAssociationMember.SiteId -eq $sBLAD.SiteAssociationMember.SiteID) {
        Write-Host -ForegroundColor Red "Site Id's for site A and site B are identical, Invoke-vCDPairSites must be used between different vCD Cells, exiting"
        return
    }

    if (!$WhatIf) {
        Write-Host -ForegroundColor Green "Associating $sAName (Site A) with $sBName (Site B)"
        $result = Invoke-vCloud -URI "https://$siteBDomain/api/site/associations" -Method POST -Body $sALAD.InnerXml -ContentType 'application/vnd.vmware.admin.siteAssociation+xml' -ApiVersion $apiVersion  -WaitForTask $true -allowInsecure $allowInsecure
        Write-Host "Returned Result = $result"
        Write-Host -ForegroundColor Green "Associating $sBName (Site B) with $sAName (Site A)"
        $result = Invoke-vCloud -URI "https://$siteADomain/api/site/associations" -Method POST -Body $sBLAD.InnerXml -ContentType 'application/vnd.vmware.admin.siteAssociation+xml' -ApiVersion $apiVersion  -WaitForTask $true -allowInsecure $allowInsecure
        Write-Host "Returned Result = $result"
    } else {
        Write-Host -ForegroundColor Yellow "Not performing site association as running in information mode"
    }
}

Export-ModuleMember -Function Get-vCloudSiteName
Export-ModuleMember -Function Set-vCloudSiteName
Export-ModuleMember -Function Get-vCloudSiteAssoc
Export-ModuleMember -Function Remove-vCloudSiteAssoc
Export-ModuleMember -Function Invoke-vCDPairSites
