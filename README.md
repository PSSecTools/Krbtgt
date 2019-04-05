# Krbtgt

Welcome to the project to deliver on all your Krbtgt account password reset issues.

## How to use

```powershell
Reset-KrbPassword
```

And that's all you need ... unless you need to reset the krbtgt account for Read Only DCs, in which case you'll also want to use this:

```powershell
Reset-KrbRODCPassword
```

## Prerequisites

 - All Domain Controllers need to be manageable by WinRM & PowerShell Remoting
 - Modules required on the executing computer:
   - Active Directory Module 
   - PSFramework Module
   - Group Policy Module (optional)

## The Procedure

For the full krbtgt password reset, `Reset-KrbPassword` will perform the following operations:

 - Retrieve the krbtgt account and check, whether it is safe to reset the password
   - It checks the PwdLastSet property for the last time it was reset
   - It checks group policy for the Kerberos configuration to calculate the next safe reset time (valid ticket duration + 2x Time Skew)
   - This validation can be disabled using the `-Force` parameter (Note: Doing so will have a *HUGE* impact on most production environments)
 - Perform a test password reset with a dummy account
   - Creates a temporary account and ensures, the password reset is properly replciated using the same tools as the main reset will be using.
 - Reset the krbtgt account password on the PDC Emulator
 - Force all DCs in the domain to do a single object replication of the krbtgt account against the PDC

## Logging

The entire procedure is automatically logged using the [PSFramework](https://psframework.org) module.

All actions are logged to memory and can be retrieved using:

```powershell
Get-PSFMessage
```

Furthermore, it will automatically create a debug log that is by default written to AppData of the executing user.
To access the specific path it will write to, execute the following line:

```powershell
Get-PSFConfigValue -FullName PSFramework.Logging.FileSystem.LogPath
```

Logs are (by default) retained for 7 days.
This logging can be extended to log to persisted files are straight to your SIEM solution of choice.
For more details on this system, see [PSFramework Quickstart Guide to Logging](https://psframework.org/documentation/quickstart/psframework/logging.html).

## More Tools

 - Use `Test-KrbPasswordReset` in order to do just the test run without any action.
 - Use `Get-KrbAccount` to retrieve information on the krbtgt account.