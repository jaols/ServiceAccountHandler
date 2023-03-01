function Set-CachedPSCredentialPassword {
    <#
    .Synopsis
        Set new password in PowerShell credential files
    .DESCRIPTION
        This is part of the ServiceAccountHandler solution. The tricky part with PSCredentials files is that they are encrypted by current user+current computer context. 
    .PARAMETER AccountName
        Account name 
    .PARAMETER Password
        New password to use
    .PARAMETER ComputerName
        Target remote computer
    .PARAMETER SearchPaths
        Folders to enumerate for files
    .PARAMETER FileNameFilter
        Files to search for (populated by $PSDefaultParameters from json file)
    .PARAMETER Session
        Existing PSsession object to remote computer
    
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [Parameter(mandatory=$true)]
        [string]$AccountName,
        [string]$Password,
        [string]$ComputerName,
        [string[]]$SearchPaths,
        [string]$FileNameFilter,
        [System.Management.Automation.Runspaces.PSSession]$session
    )
    
    if ([string]::IsNullOrEmpty($ComputerName) -or $ComputerName -ieq "local" -or $ComputerName -eq ".") {        
        $instances=@()
        try {
            #NOT IMPLEMENTED YET!!!
        } catch {            
            $instances+=$PSItem
        }        
        
    } else {
        #Call myself
        $scriptCode = "function Set-CachedPSCredentialPassword { " + (Get-Command Set-CachedPSCredentialPassword).Definition + "}`r`n" 
        $scriptCode += "Set-CachedPSCredentialPassword -AccountName $AccountName -Password $Password"
        $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($scriptCode)

        $instances=Invoke-Command -Session $session -ScriptBlock $scriptBlock
    }

    $instances    
}