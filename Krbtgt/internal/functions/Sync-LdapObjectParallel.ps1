function Sync-LdapObjectParallel
{
<#
	.SYNOPSIS
		Start LDAP-based single-object replication in parallel.
	
	.DESCRIPTION
		Start LDAP-based single-object replication.
		All servers will start sync with the target DC in parallel.
	
		Use this to minimize replication latency for critical changes on a single object, such as the krbtgt account.
	
	.PARAMETER Object
		The distinguished name of the object to replicate.
	
	.PARAMETER Server
		The server(s) from which to trigger the replication.
	
	.PARAMETER Target
		The target DC to replicate with.
	
	.PARAMETER Throttle
		Up to how many replications should be triggered in parallel.
		Defaults to 8 times the CPU count (this action mostly consists on waiting for the network response).
	
	.PARAMETER Credential
		Credentials to use when connecting to the Server(s).
		No connecting credentials for the target server are necessary, as this is handled by the servers operated against.
	
	.PARAMETER Configuration
		Whether the object being replicated is in the configuration partition.
	
	.EXAMPLE
		PS C:\> Sync-LdapObjectParallel -Object 'CN=krbtgt,CN=Users,DC=contoso,DC=com' -Server 'dc2.contoso.com','dc3.contoso.com' -Target 'dc1.contoso.com'
	
		Replicates the krbtgt account from dc1 to dc2 & dc3 in parallel.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$Object,
		
		[Parameter(Mandatory = $true, Position = 1)]
		[string[]]
		$Server,
		
		[Parameter(Mandatory = $true, Position = 2)]
		[string]
		$Target,
		
		[int]
		$Throttle = ($env:NUMBER_OF_PROCESSORS * 8),
		
		[PSCredential]
		$Credential,
		
		[switch]
		$Configuration
	)
	
	begin
	{
		#region Scriptblock
		$scriptblock = {
			param (
				$Settings
			)
			& (Get-Module krbtgt) {
				try
				{
					Sync-LdapObject @Settings
					[PSCustomObject]@{
						ComputerName = $Settings.Server
						Success	     = $true
						Object	     = $Settings.Object
						Message	     = ""
						ExitCode	 = 0
						Error	     = $null
					}
				}
				catch
				{
					[PSCustomObject]@{
						ComputerName = $Settings.Server
						Success	     = $false
						Object	     = $Settings.Object
						Message	     = "$_"
						ExitCode	 = 1
						Error	     = $_
					}
				}
			}
		}
		#endregion Scriptblock
		
		$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Object, Target, Configuration, Credential
		
		$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
		$initialSessionState.ImportPSModule(("{0}\PSFramework.psd1" -f (Get-Module PSFramework).ModuleBase))
		$initialSessionState.ImportPSModule(("{0}\krbtgt.psd1" -f (Get-Module krbtgt).ModuleBase))
		$pool = [RunspaceFactory]::CreateRunspacePool($initialSessionState)
		$null = $pool.SetMinRunspaces(1)
		$null = $pool.SetMaxRunspaces($Throttle)
		$pool.ApartmentState = "MTA"
		$pool.Open()
		$runspaces = @()
	}
	process
	{
		foreach ($serverName in $Server)
		{
			$tempParameters = $parameters.Clone()
			$tempParameters.Server = $serverName
			$runspace = [PowerShell]::Create()
			$null = $runspace.AddScript($scriptBlock)
			$null = $runspace.AddArgument($tempParameters)
			$runspace.RunspacePool = $pool
			$runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
		}
		foreach ($runspace in $runspaces)
		{
			$runspace.Pipe.EndInvoke($runspace.Status)
			$runspace.Pipe.Dispose()
		}
	}
	end
	{
		$pool.Close()
		$pool.Dispose()
	}
}