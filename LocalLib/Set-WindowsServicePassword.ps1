function Set-ScheduleTaskPassword {
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
    [CmdletBinding(SupportsShouldProcess = $True)]
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
            Get-ScheduledTask | Where-Object { $_.Principal.UserId -like "*$AccountName" } | ForEach-Object {
                Write-Verbose ("Process " + $_.TaskName)            
                $t=Set-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -User $_.Principal.UserId -Password $Password -ErrorAction Stop

                $instances+= ($t.TaskName + ";" + $t.Principal.UserId)
            }
        } catch {            
            $instances+=$PSItem
        }        
        
    } else {
        #Call myself
        $scriptCode = "function Set-ScheduleTaskPassword { " + (Get-Command Set-ScheduleTaskPassword).Definition + "}`r`n" 
        $scriptCode += "Set-ScheduleTaskPassword -AccountName $AccountName -Password $Password"
        $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($scriptCode)

        $instances=Invoke-Command -Session $session -ScriptBlock $scriptBlock
    }

    $instances
    
}