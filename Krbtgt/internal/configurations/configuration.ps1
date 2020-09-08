<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'Krbtgt' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'Krbtgt' -Name 'Import.DoDotSource' -Value $true -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'Krbtgt' -Name 'Import.IndividualFiles' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

Set-PSFConfig -Module 'Krbtgt' -Name 'Reset.DCSuccessPercent' -Value 100 -Initialize -Validation 'integer' -Description 'The default minimum percentage of DCs that must successfully replicate a password reset request in order for the reset to be considered successful.'
Set-PSFConfig -Module 'Krbtgt' -Name 'Reset.MaxDurationSeconds' -Value 180 -Initialize -Validation 'integer' -Description 'The default maximum replication duration (in seconds) in order for the reset to be considered successful.'
Set-PSFConfig -Module 'Krbtgt' -Name 'Sync.Protocol' -Value 'LDAP' -Initialize -Validation 'Krbtgt.SyncProtocol' -Description 'The protocol to use when performing single-item replication, syncing the password.'