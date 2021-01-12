function Reset-KrbPassword
{
<#
	.SYNOPSIS
		Resets the krbtgt account's password.
	
	.DESCRIPTION
		Resets the krbtgt account's password.
		Performs test runs to ensure functionality.
	
	.PARAMETER DomainController
		An explicit list of domain controllers to manually replicate.
		Optional, defaults to all domain controllers.
	
	.PARAMETER PDCEmulator
		The PDCEmulator to work against.
		Will default against the local domain's PDC Emulator.
		The actual password reset is executed against this computer, all manual replication commands will replicate with this.
	
	.PARAMETER Credential
		The credentials to use for this operation.
	
	.PARAMETER MaxDurationSeconds
		The maximum execution duration for the reset.
		Exceeding this duration will NOT interrupt the switch, but:
		- If exceeded during the test phase, the test will fail and the reset will be cancelled
		- If exceeded during execution, the overall result will be considered failed, even if technically a success.
	
	.PARAMETER DCSuccessPercent
		The percent of DCs that must successfully replicate the change in order to be considered a success.
		Defaults to 80% success rate.
		DC Replication commands are given by WinRM.
	
	.PARAMETER SkipTest
		Disables testing before execution.
	
	.PARAMETER Force
		By default, this command will refuse to reset the krbtgt account when there can still be a valid Kerberos ticket from before the last reset.
		Essentially, this means there is a cooldown after each krbtgt password reset.
		Using this parameter disables this barrier.
		DANGER: Using this parameter may lead to massive service interruption!!!
		Only use this in a case of utter desperation.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Reset-KrbPassword
	
		Resets the current domain's krbtgt account.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding()]
	param (
		[PSFComputer[]]
		$DomainController,
		
		[PSFComputer]
		$PDCEmulator,
		
		[PSCredential]
		$Credential,
		
		[int]
		$MaxDurationSeconds = (Get-PSFConfigValue -FullName 'Krbtgt.Reset.MaxDurationSeconds' -Fallback 100),
		
		[int]
		$DCSuccessPercent = (Get-PSFConfigValue -FullName 'Krbtgt.Reset.DCSuccessPercent' -Fallback 100),
		
		[switch]
		$SkipTest,
		
		[switch]
		$Force,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		#region Resolve names & DCs to process
		Write-PSFMessage -String 'Reset-KrbPassword.DomainResolve'
		$credParam = @{ }
		if ($Credential) { $credParam = @{ Credential = $Credential } }
		$parameters = $credParam.Clone()
		try
		{
			if ($PDCEmulator) { $pdcEmulatorInternal = $PDCEmulator }
			else { $pdcEmulatorInternal = (Get-ADDomain @credParam -ErrorAction Stop).PDCEmulator }
			$parameters.Server = $pdcEmulatorInternal
			
			$rwDomainControllers = Get-ADDomainController @parameters -Filter { IsReadOnly -eq $false } -ErrorAction Stop | Where-Object {
				($_.Name -ne $pdcEmulatorInternal.ComputerName) -and ("$($_.Name).$($_.Forest)" -ne $pdcEmulatorInternal.ComputerName)
			}
			if ($DomainController)
			{
				$rwDomainControllers = $rwDomainControllers | Where-Object ComputerName -in $DomainController
			}
			Write-PSFMessage -String 'Reset-KrbPassword.DomainResolve.Success' -StringValues $pdcEmulatorInternal
		}
		catch
		{
			Stop-PSFFunction -String 'Reset-KrbPassword.DomainResolve.Failed' -ErrorRecord $_
			return
		}
		#endregion Resolve names & DCs to process
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		$report = [PSCustomObject]@{
			PSTypeName  = 'Krbtgt.ResetResult'
			PDCEmulator = $pdcEmulatorInternal
			Account	    = $null
			Test	    = $null
			Reset	    = $null
			Sync	    = $null
			Success	    = $false
			Error	    = @()
			Start	    = $null
			End		    = $null
			Duration    = $null
		}
		
		#region Access Information on the krbtgt account
		try
		{
			Write-PSFMessage -String 'Reset-KrbPassword.ReadKrbtgt'
			$report.Account = Get-KrbAccount @parameters -EnableException
			Write-PSFMessage -String 'Reset-KrbPassword.ReadKrbtgt.Success' -StringValues $report.Account
		}
		catch
		{
			$report.Error += $_
			Stop-PSFFunction -String 'Reset-KrbPassword.ReadKrbtgt.Failed' -ErrorRecord $_ -Cmdlet $PSCmdlet
			return $report
		}
		# Terminate if it is too soon to reset the password again
		if (-not $Force -and ($report.Account.EarliestResetTimestamp -gt (Get-Date)))
		{
			$report.Error += Write-Error "Cannot reset krbtgt password yet. Wait until $($report.Account.EarliestResetTimestamp) before trying again" -ErrorAction Continue 2>&1
			Stop-PSFFunction -String 'Reset-KrbPassword.ReadKrbtgt.TooSoon' -StringValues $report.Account.EarliestResetTimestamp -Cmdlet $PSCmdlet -ErrorRecord $report.Error -OverrideExceptionMessage
			return $report
		}
		#endregion Access Information on the krbtgt account
		
		#region Perform tests if not disabled
		if (-not $SkipTest)
		{
			Write-PSFMessage -String 'Reset-KrbPassword.TestReset'
			$report.Test = Test-KrbPasswordReset @credParam -MaxDurationSeconds $MaxDurationSeconds -PDCEmulator $pdcEmulatorInternal -DomainController $rwDomainControllers -DCSuccessPercent $DCSuccessPercent
			if ($report.Test.Errors)
			{
				Write-PSFMessage -Level Warning -String 'Reset-KrbPassword.TestReset.ErrorCount' -StringValues ($report.Test.Errors | Measure-Object).Count
				foreach ($errorItem in $report.Test.Errors)
				{
					Write-PSFMessage -Level Warning -String 'Reset-KrbPassword.TestReset.ErrorItem' -StringValues $errorItem.Exception.Message
					$report.Error += $errorItem
				}
			}
			if (-not $report.Test.Success)
			{
				$report.Test.Status = $report.Test.Status.Trim(", ")
				$report.Error = Write-Error "Test Reset Failed: $($report.Test.Status)" 2>&1
				Stop-PSFFunction -String 'Reset-KrbPassword.TestReset.Failed' -StringValues $report.Test.Status -ErrorRecord $report.Error -Cmdlet $PSCmdlet -OverrideExceptionMessage
				return $report
			}
		}
		#endregion Perform tests if not disabled
		
		$report.Start = Get-Date
		
		#region Reset Krbtgt Password on PDC
		try
		{
			Write-PSFMessage -String 'Reset-KrbPassword.ActualReset'
			Reset-UserPassword @parameters -Identity 'krbtgt' -EnableException
			Write-PSFMessage -String 'Reset-KrbPassword.ActualReset.Success'
			$report.Reset = $true
		}
		catch
		{
			$report.Reset = $false
			$report.Error += $_
			Stop-PSFFunction -String 'Reset-KrbPassword.ActualReset.Failed' -ErrorRecord $_ -Cmdlet $PSCmdlet
			return $report
		}
		#endregion Reset Krbtgt Password on PDC
		
		#region Resync Domain Controllers
		Write-PSFMessage -String 'Reset-KrbPassword.SyncAccount'
		$report.Sync = Sync-KrbAccount @credParam -SourceDC $rwDomainControllers -TargetDC $pdcEmulatorInternal
		$report.End = Get-Date
		$report.Duration = $report.End - $report.Start
		Write-PSFMessage -String 'Reset-KrbPassword.ResetDuration' -StringValues $report.Duration
		$countSuccess = ($report.Sync | Where-Object Success | Measure-Object).Count
		$successPercent = $countSuccess / ($report.Sync | Measure-Object).Count * 100
		if ($successPercent -lt $DCSuccessPercent)
		{
			Stop-PSFFunction -String 'Reset-KrbPassword.SyncAccount.FailedCount' -StringValues $successPercent, $DCSuccessPercent, (($report.Sync | Where-Object Success -eq $false).ComputerName -join ', ')
			return $report
		}
		if ($MaxDurationSeconds -lt $report.Duration.TotalSeconds)
		{
			Stop-PSFFunction -String 'Reset-KrbPassword.SyncAccount.FailedDuration' -StringValues $report.Duration, $MaxDurationSeconds -Cmdlet $PSCmdlet
			return $report
		}
		#endregion Resync Domain Controllers
		
		Write-PSFMessage -String 'Reset-KrbPassword.Success'
		$report.Success = $true
		return $report
	}
}
