function Reset-KrbRODCPassword
{
<#
	.SYNOPSIS
		Reset the password on RODC krbtgt accounts.
	
	.DESCRIPTION
		Reset the password on RODC krbtgt accounts.
	
	.PARAMETER Name
		Name filter for what RODC to affect.
	
	.PARAMETER Server
		The directory server to initially work against.
	
	.PARAMETER Force
		By default, this command will refuse to reset the krbtgt account when there can still be a valid Kerberos ticket from before the last reset.
		Essentially, this means there is a cooldown after each krbtgt password reset.
		Using this parameter disables this barrier.
		DANGER: Using this parameter may lead to service interruption!
		Only use this in a case of utter desperation.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Reset-KrbRODCPassword
	
		Resets the password of all RODC krbtgt accounts.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[string]
		$Name = "*",
		
		[PSFComputer]
		$Server,
		
		[switch]
		$Force,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		#region Resolve names & DCs to process
		if ($Server) { $pdcEmulatorInternal = $Server }
		else
		{
			try
			{
				Write-PSFMessage -String 'Reset-KrbRODCPassword.ResolvePDC'
				$pdcEmulatorInternal = (Get-ADDomain).PDCEmulator
			}
			catch
			{
				Stop-PSFFunction -String 'Reset-KrbRODCPassword.ResolvePDC.Failed' -ErrorRecord $_ -Cmdlet $PSCmdlet
				return
			}
		}
		Write-PSFMessage -String 'Reset-KrbRODCPassword.ResolvePDC.Success' -StringValues $pdcEmulatorInternal
		#endregion Resolve names & DCs to process
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		foreach ($rodc in (Get-RODomainController -Name $Name -Server $Server))
		{
			$report = [PSCustomObject]@{
				PSTypeName = 'Krbtgt.RODCResetResult'
				Server  = $rodc.DnsHostName
				Account = $null
				Reset   = $null
				Sync    = $null
				Success = $false
				Error   = @()
				Start   = $null
				End	    = $null
				Duration = $null
			}
			
			#region Access Information on the krbtgt account
			try
			{
				Write-PSFMessage -String 'Reset-KrbRODCPassword.ReadKrbtgt' -StringValues $rodc.DnsHostName
				$report.Account = Get-KrbAccount -Server $pdcEmulatorInternal -Identity $rodc.KerberosAccount -EnableException
				Write-PSFMessage -String 'Reset-KrbRODCPassword.ReadKrbtgt.Success' -StringValues $report.Account
			}
			catch
			{
				$report.Error += $_
				$report
				Stop-PSFFunction -String 'Reset-KrbRODCPassword.ReadKrbtgt.Failed' -StringValues $rodc.DnsHostName -ErrorRecord $_ -Cmdlet $PSCmdlet -Continue
			}
			# Terminate if it is too soon to reset the password again
			if (-not $Force -and ($report.Account.EarliestResetTimestamp -gt (Get-Date)))
			{
				$report.Error += Write-Error "Cannot reset krbtgt password for $($rodc.DnsHostName) yet. Wait until $($report.Account.EarliestResetTimestamp) before trying again" -ErrorAction Continue 2>&1
				$report
				Stop-PSFFunction -String 'Reset-KrbRODCPassword.ReadKrbtgt.TooSoon' -StringValues $rodc.DnsHostName, $report.Account.EarliestResetTimestamp -Cmdlet $PSCmdlet -ErrorRecord $report.Error -Continue -OverrideExceptionMessage
			}
			#endregion Access Information on the krbtgt account
			
			$report.Start = Get-Date
			
			#region Reset Krbtgt Password on PDC
			try
			{
				Write-PSFMessage -String 'Reset-KrbRODCPassword.ActualReset' -StringValues $rodc.DnsHostName
				Reset-UserPassword -Server $rodc.ReplicationPartner[0] -Identity $rodc.KerberosAccount -EnableException
				Write-PSFMessage -String 'Reset-KrbRODCPassword.ActualReset.Success' -StringValues $rodc.DnsHostName
				$report.Reset = $true
			}
			catch
			{
				$report.Reset = $false
				$report.Error += $_
				$report
				Stop-PSFFunction -String 'Reset-KrbRODCPassword.ActualReset.Failed' -StringValues $rodc.DnsHostName -ErrorRecord $_ -Cmdlet $PSCmdlet -Continue
			}
			#endregion Reset Krbtgt Password on PDC
			
			#region Resync Domain Controllers
			Write-PSFMessage -String 'Reset-KrbRODCPassword.SyncAccount' -StringValues $rodc.DnsHostName, $rodc.ReplicationPartner[0]
			$report.Sync = Sync-KrbAccount -SourceDC $rodc.DnsHostName -TargetDC $rodc.ReplicationPartner[0]
			$report.End = Get-Date
			$report.Duration = $report.End - $report.Start
			Write-PSFMessage -String 'Reset-KrbRODCPassword.ResetDuration' -StringValues $rodc.DnsHostName, $report.Duration
			if ($report.Sync | Where-Object Success -EQ $false)
			{
				$report
				Stop-PSFFunction -String 'Reset-KrbRODCPassword.SyncAccount.Failed' -StringValues $rodc.KerberosAccount, $rodc.DnsHostName, (($report.Sync | Where-Object Success -EQ $false).ComputerName -join ", ") -Cmdlet $PSCmdlet -Continue
			}
			#endregion Resync Domain Controllers
			
			Write-PSFMessage -String 'Reset-KrbRODCPassword.Success' -StringValues $rodc.DnsHostName
			$report.Success = $true
			$report
		}
	}
}