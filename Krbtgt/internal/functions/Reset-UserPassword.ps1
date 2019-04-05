function Reset-UserPassword
{
<#
	.SYNOPSIS
		Resets a user's password.
	
	.DESCRIPTION
		Resets a user's password.
	
	.PARAMETER Identity
		The user to reset.
	
	.PARAMETER Server
		The server to execute this against.
	
	.PARAMETER Password
		The password to apply.
		Defaults to a random password.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Reset-UserPassword -Identity 'krbtgt'
	
		Resets the password on the krbtgt account.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Identity,

		[string]
		$Server,

		[SecureString]
		$Password = (New-Password -AsSecureString),
		
		[switch]
		$EnableException
	)
	
	begin
	{
		$parameters = @{
			Identity = $Identity
			NewPassword = $Password
			ErrorAction = 'Stop'
		}
		if ($Server) { $parameters["Server"] = $Server }
	}
	process
	{
		try
		{
			Write-PSFMessage -String 'Reset-UserPassword.PerformingReset' -StringValues $Identity
			Set-ADAccountPassword @parameters
			Write-PSFMessage -String 'Reset-UserPassword.PerformingReset.Success' -StringValues $Identity
		}
		catch
		{
			Stop-PSFFunction -String 'Reset-UserPassword.FailedToReset' -StringValues $Identity -ErrorRecord $_ -Cmdlet $PSCmdlet
			return
		}
	}
}
