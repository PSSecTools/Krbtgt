function Get-LdapObject
{
    <#
        .SYNOPSIS
            Use LDAP to search in Active Directory

        .DESCRIPTION
            Utilizes LDAP to perform swift and efficient LDAP Queries.

        .PARAMETER LdapFilter
            The search filter to use when searching for objects.
            Must be a valid LDAP filter.

        .PARAMETER Properties
            The properties to retrieve.
            Keep bandwidth in mind and only request what is needed.

        .PARAMETER SearchRoot
            The root path to search in.
            This generally expects either the distinguished name of the Organizational unit or the DNS name of the domain.
            Alternatively, any legal LDAP protocol address can be specified.

        .PARAMETER Configuration
            Rather than searching in a specified path, switch to the configuration naming context.

        .PARAMETER Raw
            Return the raw AD object without processing it for PowerShell convenience.

        .PARAMETER PageSize
            Rather than searching in a specified path, switch to the schema naming context.

        .PARAMETER MaxSize
            The maximum number of items to return.

        .PARAMETER SearchScope
            Whether to search all OUs beneath the target root, only directly beneath it or only the root itself.

        .PARAMETER Server
            The server to contact for this query.

        .PARAMETER Credential
            The credentials to use for authenticating this query.

        .EXAMPLE
            PS C:\> Get-LdapObject -LdapFilter '(PrimaryGroupID=516)'
            
            Searches for all objects with primary group ID 516 (hint: Domain Controllers).
    #>
	[Alias('ldap')]
	[CmdletBinding(DefaultParameterSetName = 'SearchRoot')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$LdapFilter,
		
		[string[]]
		$Properties = "*",
		
		[Parameter(ParameterSetName = 'SearchRoot')]
		[string]
		$SearchRoot,
		
		[Parameter(ParameterSetName = 'Configuration')]
		[switch]
		$Configuration,
		
		[switch]
		$Raw,
		
		[ValidateRange(1, 1000)]
		[int]
		$PageSize = 1000,
		
		[int]
		$MaxSize,
		
		[System.DirectoryServices.SearchScope]
		$SearchScope = 'Subtree',
		
		[string]
		$Server,
		
		[PSCredential]
		$Credential
	)
	
	begin
	{
		$searcher = New-Object system.directoryservices.directorysearcher
		$searcher.PageSize = $PageSize
		$searcher.SearchScope = $SearchScope
		
		if ($MaxSize -gt 0)
		{
			$Searcher.SizeLimit = $MaxSize
		}
		
		if ($SearchRoot)
		{
			$searcher.SearchRoot = New-DirectoryEntry -Path $SearchRoot -Server $Server -Credential $Credential
		}
		else
		{
			$searcher.SearchRoot = New-DirectoryEntry -Server $Server -Credential $Credential
		}
		if ($Configuration)
		{
			$searcher.SearchRoot = New-DirectoryEntry -Path ("LDAP://CN=Configuration,{0}" -f $searcher.SearchRoot.distinguishedName[0]) -Server $Server -Credential $Credential
		}
		
		Write-PSFMessage -String Get-LdapObject.SearchRoot -StringValues $SearchScope, $searcher.SearchRoot.Path -Level Debug
		
		if (Test-PSFParameterBinding -ParameterName Credential)
		{
			$searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($searcher.SearchRoot.Path, $Credential.UserName, $Credential.GetNetworkCredential().Password)
		}
		
		$searcher.Filter = $LdapFilter
		
		foreach ($property in $Properties)
		{
			$null = $searcher.PropertiesToLoad.Add($property)
		}
		
		Write-PSFMessage -String Get-LdapObject.Searchfilter -StringValues $LdapFilter -Level Debug
	}
	process
	{
		try
		{
			foreach ($ldapobject in $searcher.FindAll())
			{
				if ($Raw)
				{
					$ldapobject
					continue
				}
				$resultHash = @{ }
				foreach ($key in $ldapobject.Properties.Keys)
				{
					# Write-Output verwandelt Arrays mit nur einem Wert in nicht-Array Objekt
					$resultHash[$key] = $ldapobject.Properties[$key] | Write-Output
				}
				if ($resultHash.ContainsKey("ObjectClass")) { $resultHash["PSTypeName"] = $resultHash["ObjectClass"] }
				[pscustomobject]$resultHash
			}
		}
		catch
		{
			Stop-PSFFunction -String 'Get-LdapObject.SearchError' -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $true
		}
	}
}