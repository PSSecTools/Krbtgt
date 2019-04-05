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
	
	.PARAMETER Identity
		The user identity to replicate.
		Defaults to krbtgt.
	
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
		
		[string]
		$Identity = 'krbtgt',
		
		[switch]
		$EnableException
	)
	
	begin
	{
		try { $krbtgtDN = (Get-ADUser -Identity $Identity -Server $TargetDC -ErrorAction Stop).DistinguishedName }
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
		$pwdLastSet = [System.DateTime]::FromFileTimeUtc((Get-ADObject -Identity $krbtgtDN -Server $TargetDC -Properties PwdLastSet).PwdLastSet)
		Write-PSFMessage -String 'Sync-KrbAccount.Connecting' -StringValues ($SourceDC -join ', '), $krbtgtDN -Target $SourceDC
		Invoke-PSFCommand -ComputerName $SourceDC -ScriptBlock {
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
			Write-PSFMessage -Level Warning -Message 'Sync-KrbAccount.ConnectError' -StringValues $errorObject.TargetObject -ErrorRecord $errorObject
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
}