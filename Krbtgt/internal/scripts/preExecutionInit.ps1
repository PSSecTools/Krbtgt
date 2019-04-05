# Enable Feature Flag: Inherit Enable Exception
Set-PSFFeature -Name PSFramework.InheritEnableException -Value $true -ModuleName 'Krbtgt'

# Prepare Onetime cache for PDC Emulators
Register-PSFTaskEngineTask -Name 'krbtgt.pdccache' -ScriptBlock {
	Set-PSFTaskEngineCache -Module krbtgt -Name PDCs -Value ((Get-ADForest).Domains | Get-ADDomain).PDCEmulator
} -Once

# Prepare Onetime cache for DCs of any kind
Register-PSFTaskEngineTask -Name 'krbtgt.dccache' -ScriptBlock {
	$dcHash = @{ }
	$rodcHash = @{ }
	
	foreach ($domain in ((Get-ADForest).Domains | Get-ADDomain))
	{
		try
		{
			$dcHash[$domain.DNSRoot] = (Get-ADComputer -Server $domain.PDCEmulator -LDAPFilter '(primaryGroupID=516)').DNSHostName
			$rodcHash[$domain.DNSRoot] = (Get-ADComputer -Server $domain.PDCEmulator -LDAPFilter '(primaryGroupID=521)').DNSHostName
		}
		catch { }
	}
	
	Set-PSFTaskEngineCache -Module krbtgt -Name DCs -Value $dcHash
	Set-PSFTaskEngineCache -Module krbtgt -Name RODCs -Value $rodcHash
} -Once

# Enable PSFComputer to understand ADDomainController objects
Register-PSFParameterClassMapping -ParameterClass Computer -TypeName 'Microsoft.ActiveDirectory.Management.ADDomainController' -Properties HostName