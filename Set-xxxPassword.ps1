
function Set-xxxPassword {
    <#
    .Synopsis
        Set new password for an account running schedule task(s)
    .DESCRIPTION
        This is part of the ServiceAccountHandler solution. Thus having a fixed number of arguments.
    .PARAMETER AccountName
        Account name 
    .PARAMETER Password
        New password to use
    .PARAMETER ComputerName
        Target remote computer
    .PARAMETER Session
        Existing PSsession object to remote computer
    
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    param (
        [Parameter(mandatory=$true)]
        [string]$AccountName,
        [string]$Password,
        [string]$ComputerName,
        [System.Management.Automation.Runspaces.PSSession]$session
    )
    
    if ([string]::IsNullOrEmpty($ComputerName) -or $ComputerName -ieq "local" -or $ComputerName -eq ".") {        
        $instances=@()
        try {
            Write-Verbose "Local execution. Verbose visible."
        } catch {            
            $instances+=$PSItem
        }        
        
    } else {
        #Call myself
        $scriptCode = "function Set-xxxPassword { " + (Get-Command Set-xxxPassword).Definition + "}`r`n" 
        $scriptCode += "Set-xxxPassword -AccountName $AccountName -Password $Password"
        $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($scriptCode)
        
        Write-Verbose "Remote execution. No more verbose messages."
        $instances=Invoke-Command -Session $session -ScriptBlock $scriptBlock
    }

    $instances
}