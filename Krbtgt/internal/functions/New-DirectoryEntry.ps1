function New-DirectoryEntry
{
    <#
        .SYNOPSIS
            Generates a new directoryy entry object.
        
        .DESCRIPTION
            Generates a new directoryy entry object.
        
        .PARAMETER Path
            The LDAP path to bind to.
        
        .PARAMETER Server
            The server to connect to.
        
        .PARAMETER Credential
            The credentials to use for the connection.
        
        .EXAMPLE
            PS C:\> New-DirectoryEntry

            Creates a directory entry in the default context.

        .EXAMPLE
            PS C:\> New-DirectoryEntry -Server dc1.contoso.com -Credential $cred

            Creates a directory entry in the default context of the target server.
            The connection is established to just that server using the specified credentials.
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[string]
		$Path,
		
		[AllowEmptyString()]
		[string]
		$Server,
		
		[PSCredential]
		[AllowNull()]
		$Credential
	)
	
	if (-not $Path) { $resolvedPath = '' }
	elseif ($Path -like "LDAP://*") { $resolvedPath = $Path }
	elseif ($Path -notlike "*=*") { $resolvedPath = "LDAP://DC={0}" -f ($Path -split "\." -join ",DC=") }
	else { $resolvedPath = "LDAP://$($Path)" }
	
	if ($Server -and ($resolvedPath -notlike "LDAP://$($Server)/*"))
	{
		$resolvedPath = ("LDAP://{0}/{1}" -f $Server, $resolvedPath.Replace("LDAP://", "")).Trim("/")
	}
	
	if (($null -eq $Credential) -or ($Credential -eq [PSCredential]::Empty))
	{
		if ($resolvedPath) { New-Object System.DirectoryServices.DirectoryEntry($resolvedPath) }
		else
		{
			$entry = New-Object System.DirectoryServices.DirectoryEntry
			New-Object System.DirectoryServices.DirectoryEntry(('LDAP://{0}' -f $entry.distinguishedName[0]))
		}
	}
	else
	{
		if ($resolvedPath) { New-Object System.DirectoryServices.DirectoryEntry($resolvedPath, $Credential.UserName, $Credential.GetNetworkCredential().Password) }
		else { New-Object System.DirectoryServices.DirectoryEntry(("LDAP://DC={0}" -f ($env:USERDNSDOMAIN -split "\." -join ",DC=")), $Credential.UserName, $Credential.GetNetworkCredential().Password) }
	}
}