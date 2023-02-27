function Get-ServerSessions {    
    [CmdletBinding(SupportsShouldProcess = $False)]
    param(
        [string[]]$ServerList,
        [string[]]$ExcludeList,
        [pscredential]$Credential
    )

    $SessionHash = @{}

    #https://www.vincecarbone.com/2021/06/11/powershell-remoting-results-in-errorcode-0x80090322/
    #USE port-spn: setspn -s HTTP/servername:5985 servername

    $option = New-PSSessionOption -IncludePortInSPN

    foreach ($server in $ServerList) {
        if (!$SessionHash.ContainsKey($server) -and !($ExcludeList -contains $server)) {
            Write-Verbose "Get session for $Server"
            
            $session = $null
            $session = Get-PSSession -Name $server -ErrorAction SilentlyContinue
            if (!$session) {            
                try {
                    $adServer = Get-ADComputer -Identity $server -Properties ServicePrincipalName
                } catch {
                    $SessionHash.Add($server, $PSItem)
                    continue
                }

                $sessionArgs = @{
                    "ErrorAction" = "Stop"
                    "Name"        = $Server
                    "Computer"    = $adServer.Name
                }

                #Establish by credential if present
                if ($Credential) {
                    $sessionArgs.Add("Credential", $Credential)
                }
                
                #We use HTTP std port at this point.
                if ($adServer.ServicePrincipalName -like "*5985") {
                    Write-Verbose "New Port-session"  
                    $sessionArgs.Add("SessionOption", $option)
                } else {
                    Write-Verbose "New Standard-session"
                }
                
                try {
                    $session = New-PSSession @sessionArgs
                } catch {
                    $SessionHash.Add($server, $PSItem)
                    continue
                }

            }
            $SessionHash.Add($server, $session)
        }
    }

    return $SessionHash
}