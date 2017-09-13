# vCDSitePair #
Code to assist with enabling vCloud Director 9.0 multi-site configurations

Note that the functions in this module requires the vCloud Director 9.0 API (v29.0 or later) and will not function in earlier releases (e.g. vCD 8.20.0.1 or earlier)

## Get-vCloudSiteName ##
This function retrieves the currently configured 'Site Name' for a vCloud Director site. Note that in prior (v8.20.0.1 and earlier) releases of vCloud Director this may not be set at all but to successfully 'pair' sites to use the new multi-site functionality in vCloud Director v9 (and later) you must configure a site name. This can be done using the 'Set-vCloudSiteName' parameter (see below). You must be connected to the vCloud Director site as a user with 'System' level access using Connect-CIServer prior to using this function or an error will be returned.

Parameters:

Parameter  | Default | Required | Description
---------  | ------- | -------- | -----------
siteDomain | None    | Yes      | The FQDN of the vCloud Site (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.

Output:

The configured Site Name for this vCloud Site (if any)

Example:

C:\PS> Get-vCloudSiteName -siteDomain 'siteA.my.cloud.com'

siteA

C:\PS> Get-vCloudSiteName -siteDomain 'siteB.my.cloud.com'

siteB

## Set-vCloudSiteName ##
This function sets (and updates if already set) the configured 'Site Name' for a vCloud Director site. Both the 'siteDomain' and 'siteName' parameters are mandatory. Returns $true if the site name was updated successfully or $false if not. You must be connected to the vCloud Director site as a user with 'System' level access using Connect-CIServer prior to using this function or an error will be returned.

Parameters:

Parameter  | Default | Required | Description
---------  | ------- | -------- | -----------
siteDomain | None    | Yes      | The FQDN of the vCloud Site (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.
siteName   | None    | Yes      | The site name to be configured for this site.

Output:

$true if the site name was set/updated successfully, $false if not.

Example:

C:\PS> Set-vCloudSiteName -siteDomain 'siteA.my.cloud.com' -siteName 'SiteAlpha'

Task submitted successfully, waiting for result
q=queued, P=pre-running, .=Task Running:
q.
Task completed successfully
True

## Get-vCloudSiteAssociations ##
This function retrieves any previously associated sites for a specific vCloud Director site and can be used to check if vCD sites have already been 'paired'. You must be connected to the vCloud Director site being checked as a user with 'System' level access using Connect-CIServer prior to using this function or an error will be returned.

Parameters:

Parameter  | Default | Required | Description
---------  | ------- | -------- | -----------
siteDomain | None    | Yes      | The FQDN of the vCloud Site to check for existing site associations (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.

Output:

Any configured 'paired' sites for the specified siteDomain

Example:

C:\PS> Get-vCloudSiteAssociations -siteDomain 'siteA.my.cloud.com'

Displaying site associations for site Id: urn:vcloud:site:1234567-abcd-efab-cdef-0123456789ab with site Name: SiteA
Associated sites:
https://siteb.my.cloud.com/api

## Function Invoke-vCDPairSites ##
Pairs two vCloud Director sites (System level)

## Function Invoke-vCDPairOrgs ##
Pairs two vCloud Director Organizations (Org level)
