function Get-ADIdentifierType
{
    <#
    .SYNOPSIS
        Returns the type of the identifier string offered.
    
    .DESCRIPTION
        Returns the type of the identifier string offered.
        Can differentiate between distinguished names, objectGuid or SID.
        Will not perform any network calls to validate results.
    
    .PARAMETER Name
        The name to resolve
    
    .EXAMPLE
        PS C:\> Get-ADIdentifierType -Name '92469e61-8005-4c6d-b17c-478118f66c20'

        Validates that the specified string is a GUID.
    #>
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)
	
	if ($Name -match '^(\{{0,1}([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}\}{0,1})$') { return 'Guid' }
	if ($Name -like "*=*") { return 'DN' }
	if ($Name -match '^S-1-5-21-\d{7}-\d{9}-\d{9}-\d+$') { return 'SID' }
	return "Unknown"
}