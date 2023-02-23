function Set-ApplicationPoolPassword {
    <#
    .Synopsis
        Set new password for an account running an application pool
    .DESCRIPTION
        This is part of the ServiceAccountHandler solution. Thus having a fixed number of arguments.
    .PARAMETER AccountName
        Account name 
    .PARAMETER Password
        New password to use
    .PARAMETER ComputerName
        Target remote computer
    
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

        Import-Module WebAdministration
        $applicationPools = Get-ChildItem IIS:AppPools | Where-Object { $_.processModel.userName -like "*$AccountName"}

        foreach ($pool in $applicationPools) {
            Write-Verbose ($pool.Name + ":" + $pool.State)
            $instances+=$pool.Name + " - " + $pool.processModel.userName
            $pool.processModel.password = $Password
            $pool | Set-Item
            $pool.Recycle()
            Write-Verbose ("Recycled: " + $pool.Name + ":" + $pool.State)
        }
    } else {
        #Call myself
        $scriptCode = "function Set-ApplicationPoolPassword { " + (Get-Command Set-ApplicationPoolPassword).Definition + "}`r`n" 
        $scriptCode += "Set-ApplicationPoolPassword -AccountName $AccountName -Password '" + $Password + "'"
        $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($scriptCode)

        $instances=Invoke-Command -Session $session -ScriptBlock $scriptBlock
    }

    $instances
    
}