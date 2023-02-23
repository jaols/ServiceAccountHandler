function Set-WindowsServicePassword {
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
            Get-WmiObject win32_service -Filter "startname like '%$AccountName%'" | ForEach-Object {
                $result=$_.change($null,$null,$null,$null,$null,$null,$null,$Password)
                
                #Restart of service need to be improved with error checks
                #if ($_.Started -eq "True") {
                #    $null=$_.StopService()
                #    $null=$_.StartService()
                #}

                if ($result.ReturnValue -eq 0) {
                    $instances+=$_.DisplayName +  " - " + $_.StartName
                } else {
                    throw ("Could not set new password. ErrorCode: " + $result.ReturnValue)
                }
            } 
        } catch {            
            $instances+=$PSItem
        }        
        
    } else {
        #Call myself
        $scriptCode = "function Set-WindowsServicePassword { " + (Get-Command Set-WindowsServicePassword).Definition + "}`r`n" 
        $scriptCode += "Set-WindowsServicePassword -AccountName $AccountName -Password $Password"
        $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($scriptCode)

        $instances=Invoke-Command -Session $session -ScriptBlock $scriptBlock
    }

    $instances    
}