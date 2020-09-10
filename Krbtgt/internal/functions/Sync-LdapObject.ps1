function Sync-LdapObject
{
	<#
		.SYNOPSIS
			Performs single object replication of an object between two separate directory servers.
		
		.DESCRIPTION
			Performs single object replication of an object between two separate directory servers.
			
		.PARAMETER Object
			The object to replicate.
			Accepts valid system identifiers:
			- SID
			- ObjectGUID
			- DistinguishedName
		
		.PARAMETER Server
			The server from which to replicate.
		
		.PARAMETER Target
			The destination server to replicate to.
		
		.PARAMETER Credential
			The credentials to use for replication.
		
		.PARAMETER Configuration
			If the target object is stored in the configuration node, specifying this parameter is required.
		
		.PARAMETER Confirm
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
		
		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
		
		.EXAMPLE
			PS C:\> Sync-LdapObject -Object '92469e61-8005-4c6d-b17c-478118f66c20' -Server dc1.contoso.com -Target dc2.contoso.com

			Synchronizes the object identified by the specified guid from dc1 to dc2.
	#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$Object,
		
		[Parameter(Mandatory = $true, Position = 1)]
		[string]
		$Server,
		
		[Parameter(Mandatory = $true, Position = 2)]
		[string]
		$Target,
		
		[PSCredential]
		$Credential,
		
		[switch]
		$Configuration
	)
	
	begin
	{
		#region Defaults
		$stopDefault = @{
			Target = $Object
			EnableException = $true
			Cmdlet = $PSCmdlet
		}
		#endregion Defaults
		
		#region Resolving target object
		$adParameter = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
		switch (Get-ADIdentifierType -Name $Object)
		{
			'SID' { $ldapFilter = "(objectSID=$($Object))" }
			'Guid'
			{
				$bytes = ([guid]$Object).ToByteArray()
				$segments = foreach ($byte in $bytes)
				{
					"\{0}" -f ([convert]::ToString($byte, 16))
				}
				$ldapFilter = "(objectGuid=$($segments -join ''))"
			}
			'DN' { $ldapFilter = "(distinguishedName=$($Object))" }
		}
		Write-PSFMessage -String 'Sync-LdapObject.SyncObjectFilter' -StringValues $ldapFilter -Target $Object
		try { $resolvedObject = Get-LdapObject @adParameter -LdapFilter $ldapFilter -Properties ObjectGUID -Configuration:$Configuration -ErrorAction Stop }
		catch { Stop-PSFFunction @stopDefault -String 'Sync-LdapObject.ObjectAccessError' -StringValues $Object, $_ -ErrorRecord $_ -OverrideExceptionMessage }
		if (-not $resolvedObject)
		{
			Stop-PSFFunction @stopDefault -String 'Sync-LdapObject.ObjectNotFound' -StringValues $Object -OverrideExceptionMessage
		}
		$objectGUID = ([guid][byte[]]$resolvedObject.objectGUID).Guid
		#endregion Resolving target object
	}
	process
	{
		try { $dstRootDSE = New-DirectoryEntry -Path "LDAP://$($Target)/RootDSE" -Credential $Credential -ErrorAction Stop }
		catch { Stop-PSFFunction @stopDefault -String 'Sync-LdapObject.DestinationAccessError' -StringValues $Target, $_ -ErrorRecord $_ -OverrideExceptionMessage }
		try { $srcRootDSE = New-DirectoryEntry -Path "LDAP://$($Server)/RootDSE" -Credential $Credential }
		catch { Stop-PSFFunction @stopDefault -String 'Sync-LdapObject.SourceAccessError' -StringValues $Server, $_ -ErrorRecord $_ -OverrideExceptionMessage }
		
		$replicationCommand = '{0}:<GUID={1}>' -f $srcRootDSE.dsServiceName.ToString(), $objectGUID
		
		Write-PSFMessage -String 'Sync-LdapObject.PerformingReplication' -StringValues $Server, $Target -Target $Object
		if (Test-PSFShouldProcess -ActionString 'LDAP.Sync-LdapObject.PerformingReplication' -ActionStringValues $Server, $Target -Target $Object -PSCmdlet $PSCmdlet)
		{
			$dstRootDSE.Put("replicateSingleObject", $replicationCommand)
			try { $dstRootDSE.SetInfo() }
			catch
			{
				Stop-PSFFunction @stopDefault -String 'Sync-LdapObject.FailedReplication' -StringValues $Object, $Server, $Target, $_ -ErrorRecord $_ -OverrideExceptionMessage
			}
		}
	}
}