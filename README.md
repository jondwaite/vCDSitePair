# vCDSitePair #
Code to assist with enabling vCloud Director 9.0 (or later) multi-site configurations

Note that the functions in this module requires the vCloud Director 9.0 API (v29.0 or later) and will not function in earlier releases (e.g. vCD 8.20.0.1 or earlier)

## Installation ##

**NOTE:** VMware PowerCLI and PowerShell/PowerShell Core v6 (or higher) are both required to use this module.

This module is published to PSGallery and can either be downloaded from the github repository or installed from PSGallery using:

```
C:\PS> Install-Module vCDPairSites -Scope CurrentUser
```

## Get-vCloudSiteName ##
This function retrieves the currently configured 'Site Name' for a vCloud Director site. Note that in prior (v8.20.0.1 and earlier) releases of vCloud Director this may not be set at all but to successfully 'pair' sites to use the new multi-site functionality in vCloud Director v9 (and later) you must configure a site name. This can be done using the 'Set-vCloudSiteName' parameter (see below). You must be connected to the vCloud Director site as a user with 'System' level access using Connect-CIServer prior to using this function or an error will be returned.

Parameters:

Parameter     | Default | Required | Description
---------     | ------- | -------- | -----------
siteDomain    | -       | Yes      | The FQDN of the vCloud Site (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.
allowInsecure | -       | No | If this switch is included, connections to sites with untrusted SSL certificates are permitted.


Output:

The configured Site Name for this vCloud Site (if any)

Example:

```
C:\PS> Get-vCloudSiteName -siteDomain 'siteA.cloud.com'
siteA
C:\PS> Get-vCloudSiteName -siteDomain 'siteB.cloud.com' -allowInsecure
siteB
```

## Set-vCloudSiteName ##
This function sets (and updates if already set) the configured 'Site Name' for a vCloud Director site. Both the 'siteDomain' and 'siteName' parameters are mandatory. Returns $true if the site name was updated successfully or $false if not. You must be connected to the vCloud Director site as a user with 'System' level access using Connect-CIServer prior to using this function or an error will be returned.

Parameters:

Parameter     | Default | Required | Description
---------     | ------- | -------- | -----------
siteDomain    | -       | Yes      | The FQDN of the vCloud Site (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.
siteName      | -       | Yes      | The site name to be configured for this site.
Timeout       | 30      | No       | Time to wait for the API task to complete when setting a site name in seconds.
allowInsecure | -       | No       | If this switch is included, connections to sites with untrusted SSL certificates are permitted.

Output:

$true if the site name was set/updated successfully, $false if not.

Example:

```
C:\PS> Set-vCloudSiteName -siteDomain 'siteA.my.cloud.com' -siteName 'SiteAlpha'
Task submitted successfully, waiting for result
q=queued, P=pre-running, .=Task Running:
q.
Task completed successfully
True
```

## Get-vCloudSiteAssoc ##
This function retrieves any previously associated sites for a specific vCloud Director site and can be used to check if vCD sites have already been 'paired'. You must be connected to the vCloud Director site being checked as a user with 'System' level access using Connect-CIServer prior to using this function or an error will be returned.

Parameters:

Parameter     | Default | Required | Description
---------     | ------- | -------- | -----------
siteDomain    | None    | Yes      | The FQDN of the vCloud Site to check for existing site associations (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.
Timeout       | 30      | No       | Time to wait for the API task to complete when setting a site name in seconds.
allowInsecure | -       | No       | If this switch is included, connections to sites with untrusted SSL certificates are permitted.

Output:

Any configured 'paired' sites for the specified siteDomain

Example:

```
C:\PS> Get-vCloudSiteAssoc -siteDomain 'siteA.cloud.com'
Displaying site associations for site Id: urn:vcloud:site:12345678-abcd-efab-cdef-0123456789ab with site Name: SiteA
Associated sites:
https://siteb.cloud.com/api
```

## Remove-vCloudSiteAssoc ##
This function removes a site association for a remote site from a vCloud Director site. The 'removeId' parameter
can be retrieved using the Get-vCloudSiteAssoc cmdlet. Note that for an existing 'paired' site arrangment you will need to remove the association from both sites individually using Remove-vCloudSiteAssoc to fully dissassociate the sites.
If the specified 'removeId' cannot be found in the existing site associations for the specified siteDomain an error will be shown and no changes made.

Parameters:

Parameter     | Default | Required | Description
---------     | ------- | -------- | -----------
siteDomain    | None    | Yes      | The FQDN of the vCloud Site from which the site association is to be removed (e.g. 'my.cloud.com'). Must match the IP address or DNS name used when connecting via Connect-CIServer.
removeId      | None    | Yes      | The Site Id for the remote site to be removed as an association of the siteDomain. Site Ids can be found from the Get-vCloudSiteAssoc cmdlet. Site Id should be specified as the GUID string (e.g. '12345678-abcd-efab-cdef-0123456789ab') without the 'urn:vcloud:site:' prefix.
Timeout       | 30      | No       | Time to wait for the API task to complete when setting a site name in seconds.
allowInsecure | -       | No       | If this switch is included, connections to sites with untrusted SSL certificates are permitted.

Output:

Console messages will indicate whether or not the association removal has been completed successfully or not.

Example:

```
C:\PS> Remove-vCloudSiteAssoc -siteDomain 'siteA.cloud.com' -removeId '87654321-dcba-bafe-bc9876543210'
```

## Invoke-vCDPairSites ##
This function creates a multisite relationship between two vCloud Director sites. You must be connected to both sites as a user with 'System' level access (Connect-CIServer) prior to using this function or an error will be returned. Note that to actually perform the site pairing operation the 'WhatIf' parameter must be specified as $false.

Parameters:

Parameter | Type    | Default | Required | Description
--------- | ------- | ------- | -------- | -----------
siteADomain  | String  | None    | Yes      | The FQDN of the first vCloud Site to be paired. Must match the IP address or DNS name used when connecting via Connect-CIServer.
siteBDomain  | String  | None    | Yes      | The FQDN of the second vCloud Site to be paired. Must match the IP address or DNS name used when connecting via Connect-CIServer.
WhatIf    | Boolean | $true   | No       | Must be overridden and set to $false to actually attempt to perform the pairing operation.
allowInsecure | Switch | - | No | If this switch is included, connections to sites with untrusted SSL certificates are permitted.
Timeout | Int | 30 | No | Time to wait for the API task to copmlete when configuring the site association in seconds.

Output:

If 'WhatIf' is set to $false and the pairing operation is attempted, returns $true if the operation completes successfully or $false otherwise.

Example:

```
C:\PS> Invoke-vCDPairSites -siteADomain 'siteA.my.cloud.com' -siteBDomain 'siteB.my.cloud.com' -WhatIf $false
Running in implementation mode, API changes will be committed
Site A returned site ID as: urn:vcloud:site:12345678-abcd-efab-cdef-0123456789ab
Site A returned site name as: Site A
Site B returned site ID as: urn:vcloud:site:87654321-dcba-bafe-fedc-bf9876543210
Site B returned site name as: Site B
Associating Site A (Site A) with Site B (Site B)
Task submitted successfully, waiting for result
q=queued, P=pre-running, .=Task Running:
q.
Task completed successfully
Associating Site B (Site B) with Site A (Site A)
Task submitted successfully, waiting for result
q=queued, P=pre-running, .=Task Running:
q..
Task completed successfully
True
```
