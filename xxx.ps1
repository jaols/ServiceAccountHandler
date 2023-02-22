function  Set-ApplicationPoolPassword {
    <#
    .Synopsis
        Set new password for an account
    .DESCRIPTION
        A cached credential will be used if a credential XML-file is found. If no file is found the user need to provide info interactivally.
        The saved credential file can only be decrypted by current user on current machine.
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
        [string]$ComputerName
    )
    
    if ([string]::IsNullOrEmpty($ComputerName) -or $ComputerName -ieq "local" -or $ComputerName -eq ".") {
        
        $instances=@()

        Import-Module WebAdministration
        $applicationPools = Get-ChildItem IIS:AppPools | Where-Object { $_.processModel.userName -like "*$AccountName"}

        foreach ($pool in $applicationPools) {
            Write-Verbose ($pool.Name + ":" + $pool.State)
            $instances+=$pool.Name + ";" + $pool.processModel.userName            
            $pool.processModel.password = $Password
            $pool | Set-Item
            $pool.Recycle()
            Write-Verbose ($pool.Name + ":" + $pool.State)
        }
    } else {
        
    }

    $instances
    
}
Set-ApplicationPoolPassword -AccountName "DPBCarina" -Password "12qwaszx!"
