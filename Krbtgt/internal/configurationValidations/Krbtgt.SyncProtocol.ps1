Register-PSFConfigValidation -Name "Krbtgt.SyncProtocol" -ScriptBlock {
	param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	if ($Value -notin 'LDAP', 'WinRM')
	{
		$Result.Message = "Not a supported protocol: $Value. Pick either LDAP or WinRM!"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $Value -as [string]
	
	return $Result
}