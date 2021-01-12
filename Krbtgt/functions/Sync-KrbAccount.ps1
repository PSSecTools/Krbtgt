function Sync-KrbAccount
{
<#
	.SYNOPSIS
		Forces a single item AD Replication.
	
	.DESCRIPTION
		Will command the replication of an AD User object between two DCs.
		Uses PowerShell remoting against the source DC(s).
	
	.PARAMETER SourceDC
		The DC to start the synchronization command from.
	
	.PARAMETER TargetDC
		The DC to replicate with.
	
	.PARAMETER Credential
		Credentials to use for performing AD actions
	
	.PARAMETER Identity
		The user identity to replicate.
		Defaults to krbtgt.
	
	.PARAMETER ReplicationMode
		Whether to trigger replication through WinRM or LDAP.
		Defaults to LDAP
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Sync-KrbAccount -SourceDC 'dc1' -TargetDC 'dc2'
		
		Replicates the krbtgt account between dc1 and dc2.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[PSFComputer[]]
		$SourceDC,
		
		[Parameter(Mandatory = $true)]
		[string]
		$TargetDC,
		
		[System.Management.Automation.PSCredential]
		$Credential,
		
		[string]
		$Identity = 'krbtgt',
		
		[ValidateSet('LDAP', 'WinRM')]
		[string]
		$ReplicationMode = (Get-PSFConfigValue -FullName 'Krbtgt.Sync.Protocol' -Fallback 'LDAP'),
		
		[switch]
		$EnableException
	)
	
	begin
	{
		$credParam = $PSBoundParameters | ConvertTo-PSFHashtable -Include Credential
		try { $krbtgtDN = (Get-ADUser @credParam -Identity $Identity -Server $TargetDC -ErrorAction Stop).DistinguishedName }
		catch
		{
			Stop-PSFFunction -String 'Sync-KrbAccount.UserNotFound' -StringValues $Identity, $TargetDC -ErrorRecord $_
			return
		}
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		$errorVar = @()
		$pwdLastSet = [System.DateTime]::FromFileTimeUtc((Get-ADObject @credParam -Identity $krbtgtDN -Server $TargetDC -Properties PwdLastSet).PwdLastSet)
		switch ($ReplicationMode)
		{
			#region LDAP Based
			'LDAP'
			{
				Sync-LdapObjectParallel @credParam -Object $krbtgtDN -Server $SourceDC -Target $TargetDC
			}
			#endregion LDAP Based
			#region WinRM Based
			'WinRM'
			{
				Write-PSFMessage -String 'Sync-KrbAccount.Connecting' -StringValues ($SourceDC -join ', '), $krbtgtDN -Target $SourceDC
				Invoke-PSFCommand @credParam -ComputerName $SourceDC -ScriptBlock {
					param (
						$TargetDC,
						
						$KrbtgtDN,
						
						$PwdLastSet
					)
					
					$message = repadmin.exe /replsingleobj $env:COMPUTERNAME $TargetDC $KrbtgtDN *>&1
					$result = 0 -eq $LASTEXITCODE
					
					# Verify the password change was properly synced
					$pwdLastSetLocal = [System.DateTime]::FromFileTimeUtc((Get-ADObject -Identity $KrbtgtDN -Server $env:COMPUTERNAME -Properties PwdLastSet).PwdLastSet)
					if ($pwdLastSetLocal -ne $PwdLastSet) { $result = $false }
					
					[PSCustomObject]@{
						ComputerName = $env:COMPUTERNAME
						Success	     = $result
						Message	     = ($message | Where-Object { $_ })
						ExitCode	 = $LASTEXITCODE
						Error	     = $null
					}
				} -ArgumentList $TargetDC, $krbtgtDN, $pwdLastSet -ErrorVariable errorVar -ErrorAction SilentlyContinue | Select-PSFObject -KeepInputObject -TypeName 'Krbtgt.SyncResult'
				
				foreach ($errorObject in $errorVar)
				{
					Write-PSFMessage -Level Warning -String 'Sync-KrbAccount.ConnectError' -StringValues $errorObject.TargetObject -ErrorRecord $errorObject
					[PSCustomObject]@{
						PSTypeName   = 'Krbtgt.SyncResult'
						ComputerName = $errorObject.TargetObject
						Success	     = $false
						Message	     = $errorObject.Exception.Message
						ExitCode	 = 1
						Error	     = $errorObject
					}
				}
			}
			#endregion WinRM Based
		}
	}
}