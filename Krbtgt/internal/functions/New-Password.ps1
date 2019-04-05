function New-Password
{
<#
	.SYNOPSIS
		Generates a random password
	
	.DESCRIPTION
		Generates a random password.
		Is guaranteed to be complex.
	
	.PARAMETER Length
		The number of characters the password should have.
		Defaults to 26

	.PARAMETER AsSecureString
		Returns the password as a secure string.
	
	.EXAMPLE
		PS C:\> New-Password
	
		Generates a 26 characters password.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[int]
		$Length = 26,

		[switch]
		$AsSecureString
	)
	
	$lower = 97 .. 122
	$upper = 65 .. 90
	$special = '^', '~', '!', '@', '#', '$', '%', '^', '&', '*', '_', '+', '=', '`', '|', '\', '(', ')', '{', '}', '[', ']', ':', ';', '"', "'", '<', '>', ',', '.', '?', '/'
	
	$password = foreach ($number in (1 .. $Length))
	{
		switch ($number % 3)
		{
			0 { [char]($lower | Get-Random) }
			1 { [char]($upper | Get-Random) }
			2 { [char]($special | Get-Random) }
		}
	}
	
	if ($AsSecureString) { $password -join "" | ConvertTo-SecureString -AsPlainText -Force }
	else { $password -join "" }
}