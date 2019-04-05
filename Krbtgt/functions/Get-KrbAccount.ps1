function Get-KrbAccount
{
<#
	.SYNOPSIS
		Returns information on the Krbtgt Account.
	
	.DESCRIPTION
		Returns information on the Krbtgt Account.
		Includes information on the Kerberos ticket configuration.
		Tries to use the GroupPolicy module to figure out the Kerberos policy settings.
	
	.PARAMETER Server
		The domain controller to ask for the information.
	
	.PARAMETER Identity
		The account to target.
		Defaults to the krbtgt account, but can be used to apply to other accounts (eg: The krbtgt account for a RODC)
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Get-KrbAccount
	
		Returns the krbtgt account information.
#>
	[CmdletBinding()]
	param (
		[string]
		$Server,
		
		[string]
		$Identity = 'krbtgt',
		
		[switch]
		$EnableException
	)
	
	begin
	{
		#region Prepare Preliminaries
		$parameter = @{
			Identity   = $Identity
			Properties = 'PasswordLastSet'
		}
		if ($Server) { $parameter['Server'] = $Server }
		
		try
		{
			if ($Server) { $domainName = (Get-ADDomain -Server $Server -ErrorAction Stop).DNSRoot }
			else { $domainName = (Get-ADDomain -ErrorAction Stop).DNSRoot }
		}
		catch
		{
			Stop-PSFFunction -String 'Get-KrbAccount.FailedDomainAccess' -ErrorRecord $_ -Cmdlet $PSCmdlet
			return
		}
		#endregion Prepare Preliminaries
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		#region Get basic account properties
		Write-PSFMessage -String 'Get-KrbAccount.Start' -StringValues $Identity
		$krbtgt = Get-ADUser @parameter -ErrorAction Stop
		Write-PSFMessage -String 'Get-KrbAccount.UserFound' -StringValues $krbtgt.DistinguishedName -Level Debug
		
		$result = [PSCustomObject]@{
			PSTypeName			   = 'Krbtgt.Account'
			EarliestResetTimestamp = $null
			Name				   = $krbtgt.Name
			SamAccountName		   = $krbtgt.SamAccountName
			DistinguishedName	   = $krbtgt.DistinguishedName
			PasswordLastSet	       = $krbtgt.PasswordLastSet
			MaxTgtLifetimeHours    = 10
			MaxClockSkewMinutes    = 5
		}
		#endregion Get basic account properties
		
		#region Retrieve Kerberos Policies
		try
		{
			Write-PSFMessage -String 'Get-KrbAccount.ScanningKerberosPolicy' -StringValues $domainName
			[xml]$gpo = Get-GPOReport -Guid '{31B2F340-016D-11D2-945F-00C04FB984F9}' -ReportType Xml -ErrorAction Stop -Domain $domainName
			$result.MaxTgtLifetimeHours = (($gpo.gpo.Computer.ExtensionData | Where-Object { $_.name -eq 'Security' }).Extension.ChildNodes | Where-Object { $_.Name -eq 'MaxTicketAge' }).SettingNumber
			$result.MaxClockSkewMinutes = (($gpo.gpo.Computer.ExtensionData | Where-Object { $_.name -eq 'Security' }).Extension.ChildNodes | Where-Object { $_.Name -eq 'MaxClockSkew' }).SettingNumber
		}
		catch
		{
			Write-PSFMessage -Level Warning -String 'Get-KrbAccount.FailedKerberosPolicyLookup' -StringValues $domainName -ErrorRecord $_
		}
		#endregion Retrieve Kerberos Policies
		
		# This calculates the latest validity time time of existing krbtgt tickets from before the last reset might have.
		# Resetting the krbtgt password again before this expiry time risks preventing DCs from synchronizing the password on the second reset!
		$result.EarliestResetTimestamp = (($Krbtgt.PasswordLastSet.AddHours($result.MaxTgtLifetimeHours)).AddMinutes($result.MaxClockSkewMinutes)).AddMinutes($result.MaxClockSkewMinutes)
		
		Write-PSFMessage -String 'Get-KrbAccount.Success' -StringValues $result.SamAccountName, $result.EarliestResetTimestamp
		$result
	}
}
