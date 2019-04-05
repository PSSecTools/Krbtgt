function Get-RODomainController
{
<#
	.SYNOPSIS
		Returns a list of Read Only Domain Controllers.
	
	.DESCRIPTION
		Returns a list of Read Only Domain Controllers.
		Includes replication and krbtgt account information.
	
	.PARAMETER Name
		A name filter to limit the selection range.
	
	.PARAMETER Server
		The server to retrieve the information from.
	
	.EXAMPLE
		PS C:\> Get-RODomainController
	
		Returns information on all RODCs in the current domain.
#>
	[CmdletBinding()]
	param (
		[string]
		$Name = "*",
		
		[string]
		$Server
	)
	
	begin
	{
		$parameter = @{
			LdapFilter = "(&(primaryGroupID=521)(name=$Name))"
			Properties = 'msDS-KrbTgtLink'
		}
		if ($Server) { $parameter["Server"] = $Server }
	}
	process
	{
		$rodcs = Get-ADComputer @parameter
		foreach ($rodc in $rodcs)
		{
			$domainDN = ($rodc.DistinguishedName -split "," | Where-Object { $_ -like "DC=*" }) -join ','
			$siteServerObjects = Get-ADObject -LDAPFilter "(&(objectClass=server)(dnsHostName=$($rodc.DNSHostName)))" -SearchBase "CN=Sites,CN=Configuration,$($domainDN)"
			$replicationPartner = @()
			foreach ($siteServerObject in $siteServerObjects)
			{
				$fromServer = (Get-ADObject -SearchBase $siteServerObject.DistinguishedName -LDAPFilter '(objectClass=nTDSConnection)' -Properties FromServer).FromServer
				$replicationPartner += (Get-ADObject $fromServer.Split(",", 2)[1] -Properties dNSHostName).dNSHostName
			}
			
			[PSCustomObject]@{
				DistinguishedName = $rodc.DistinguishedName
				DNSHostName	      = $rodc.DNSHostName
				Name			  = $rodc.Name
				Enabled		      = $rodc.Enabled
				ReplicationPartner = $replicationPartner
				KerberosAccount   = $rodc.'msDS-KrbTgtLink'
			}
		}
	}
}
