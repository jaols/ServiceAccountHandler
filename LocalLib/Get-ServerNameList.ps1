function Get-ServerNameList {
    [CmdletBinding(SupportsShouldProcess = $False)]
    param(
        $AccountList
    )
    $ServerList = @()
    
    foreach ($serviceAccount in ($AccountList | Get-Member -MemberType NoteProperty)) {
        if ($serviceAccount.Name -ine "_info") {
            Write-Verbose "-- Get servers for $($serviceAccount.Name) --"
            $serviceData = $AccountList.($serviceAccount.Name)
            foreach ($Server in $serviceData.Servers | Get-Member -MemberType NoteProperty) {
                #Only gather approriate names.
                if ($Server.Name -ine "_info" -and $Server.Name -ine "local" -and $Server.Name -ine "localhost") {
                    Write-Verbose ("Add " + $Server.Name)
                    $ServerList += $Server.Name
                }
            }
        }        
    }

    return $ServerList
}