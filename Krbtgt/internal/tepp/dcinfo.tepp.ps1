Register-PSFTeppScriptblock -Name "Krbtgt.PDC" -ScriptBlock {
	Get-PSFTaskEngineCache -Module krbtgt -Name PDCs
}

Register-PSFTeppScriptblock -Name "Krbtgt.DC" -ScriptBlock {
	$dcs = Get-PSFTaskEngineCache -Module krbtgt -Name DCs
	if ($fakeBoundParameters.PDCEmulator)
	{
		$dcs[(Get-ADDomain -Server $fakeBoundParameters.PDCEmulator).DNSRoot]
	}
	elseif ($fakeBoundParameters.Server)
	{
		$dcs[(Get-ADDomain -Server $fakeBoundParameters.Server).DNSRoot]
	}
	else
	{
		$dcs[(Get-ADDomain).DNSRoot]
	}
}

Register-PSFTeppScriptblock -Name "Krbtgt.RODC" -ScriptBlock {
	$rodcs = Get-PSFTaskEngineCache -Module krbtgt -Name RODCs
	if ($fakeBoundParameters.PDCEmulator)
	{
		$rodcs[(Get-ADDomain -Server $fakeBoundParameters.PDCEmulator).DNSRoot]
	}
	elseif ($fakeBoundParameters.Server)
	{
		$rodcs[(Get-ADDomain -Server $fakeBoundParameters.Server).DNSRoot]
	}
	else
	{
		$rodcs[(Get-ADDomain).DNSRoot]
	}
}