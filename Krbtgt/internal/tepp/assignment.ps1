Register-PSFTeppArgumentCompleter -Command Get-KrbAccount -Parameter Server -Name Krbtgt.PDC

Register-PSFTeppArgumentCompleter -Command Reset-KrbPassword -Parameter PDCEmulator -Name Krbtgt.PDC
Register-PSFTeppArgumentCompleter -Command Reset-KrbPassword -Parameter DomainController -Name Krbtgt.DC

Register-PSFTeppArgumentCompleter -Command Reset-KrbRODCPassword -Parameter Server -Name Krbtgt.PDC
Register-PSFTeppArgumentCompleter -Command Reset-KrbRODCPassword -Parameter Name -Name Krbtgt.RODC

Register-PSFTeppArgumentCompleter -Command Sync-KrbAccount -Parameter SourceDC, TargetDC -Name Krbtgt.DC

Register-PSFTeppArgumentCompleter -Command Test-KrbPasswordReset -Parameter PDCEmulator -Name Krbtgt.PDC
Register-PSFTeppArgumentCompleter -Command Test-KrbPasswordReset -Parameter DomainController -Name Krbtgt.DC