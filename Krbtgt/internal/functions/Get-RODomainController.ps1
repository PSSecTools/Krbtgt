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
	
	.PARAMETER Credential
		The credentials to use for this operation.
	
	.EXAMPLE
		PS C:\> Get-RODomainController
	
		Returns information on all RODCs in the current domain.
#>
	[CmdletBinding()]
	param (
		[string]
		$Name = "*",
		
		[string]
		$Server,
		
		[PSCredential]
		$Credential
	)
	
	begin
	{
		$adParameter = ($PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential)
		$parameter = @{
			LdapFilter = "(&(primaryGroupID=521)(name=$Name))"
			Properties = 'msDS-KrbTgtLink'
		} + $adParameter
	}
	process
	{
		$rodcs = Get-ADComputer @parameter
		foreach ($rodc in $rodcs)
		{
			$domainDN = ($rodc.DistinguishedName -split "," | Where-Object { $_ -like "DC=*" }) -join ','
			$siteServerObjects = Get-ADObject @adParameter -LDAPFilter "(&(objectClass=server)(dnsHostName=$($rodc.DNSHostName)))" -SearchBase "CN=Sites,CN=Configuration,$($domainDN)"
			$replicationPartner = @()
			foreach ($siteServerObject in $siteServerObjects)
			{
				$fromServer = (Get-ADObject @adParameter -SearchBase $siteServerObject.DistinguishedName -LDAPFilter '(objectClass=nTDSConnection)' -Properties FromServer).FromServer
				$replicationPartner += (Get-ADObject @adParameter $fromServer.Split(",", 2)[1] -Properties dNSHostName).dNSHostName
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
