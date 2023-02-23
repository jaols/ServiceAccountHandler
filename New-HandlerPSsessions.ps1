<#
.Synopsis
    Setup sessions used by other PS-files in this solution
.DESCRIPTION
    Removes any previous sessions and creates new ones. Errors will be logged for diagnistic purposes.
    
.PARAMETER AccountDataFile
   	Input JSON file with account data to process
.Parameter Credential
    A PSCredential to use when establising connections.    
   	
.Notes
    Author: Jack Olsson
    Changes:

.Example
    New-HandlerPSsessions -AccountDataFile ServiceAccountPasswordHandler.json 

    Run command with current credentials to establish sessions (same as hendler code)

.Example    
    New-HandlerPSsessions -AccountDataFile ServiceAccountPasswordHandler.json -Credential (Get-AccessCredential -AccessName "ServiceAccountPasswordHandler")

    Use Get-AccessCredential (PSJumpStart) to retreive credential from XML-file or genereate XML-file from dialog.
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param (
    [Parameter(mandatory = $true)]
    [string]$AccountDataFile,
    [pscredential]$Credential
)

#region local functions 

#Load default arguemts for this script.
#Command prompt arguments will override file settings
function Get-LocalDefaultVariables {
    [CmdletBinding(SupportsShouldProcess = $False)]
    param(
        [parameter(Position = 0, mandatory = $true)]
        $CallerInvocation,
        [switch]$defineNew,
        [switch]$overWriteExisting
    )
    foreach ($settingsFile in (Get-SettingsFiles $CallerInvocation ".json")) {        
        if (Test-Path $settingsFile) {        
            Write-Verbose "Reading file: [$settingsFile]"
            $DefaultParamters = Get-Content -Path $settingsFile -Encoding UTF8 | ConvertFrom-Json
            ForEach ($prop in $DefaultParamters | Get-Member -MemberType NoteProperty) {        
                
                if (($prop.Name).IndexOf(':') -eq -1) {
                    $key = $prop.Name
                    $var = Get-Variable $key -ErrorAction SilentlyContinue
                    $value = $DefaultParamters.($prop.Name)                    
                    if (!$var) {
                        if ($defineNew) {
                            Write-Verbose "New Var: $key" 
                            if ($value.GetType().Name -eq "String" -and $value.SubString(0, 1) -eq '(') {
                                $var = New-Variable -Name  $key -Value (Invoke-Expression $Value) -Scope 1
                            }
                            else {
                                $var = New-Variable -Name  $key -Value $value -Scope 1
                            }
                        }
                    }
                    else {

                        #We only overwrite non-set values if not forced
                        if (!($var.Value) -or $overWriteExisting) {
                            try {                
                                Write-Verbose "Var: $key" 
                                if ($value.GetType().Name -eq "String" -and $value.SubString(0, 1) -eq '(') {
                                    $var.Value = Invoke-Expression $value
                                }
                                else {
                                    $var.Value = $value
                                }
                            }
                            Catch {
                                $ex = $PSItem
                                $ex.ErrorDetails = "Err adding $key from $settingsFile. " + $PSItem.Exception.Message
                                throw $ex
                            }
                        }
                    }
                }
            }
        }
        else {
            Write-Verbose "File not found: [$settingsFile]"
        }

    }
}

#endregion

#region Init
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
#if (-not (Get-Module PSJumpStart)) {
Import-Module PSJumpStart -Force -MinimumVersion 1.2.0 
#}

#Get Local variable default values from external DFP-files
Get-LocalDefaultVariables($MyInvocation)

#Get global deafult settings when calling modules
$PSDefaultParameterValues = Get-GlobalDefaultsFromJsonFiles $MyInvocation -Verbose:$VerbosePreference

#endregion

Msg "Start Execution"

if (!(Test-Path $AccountDataFile)) {
    throw [System.IO.FileNotFoundException] "Missing input file [$AccountDataFile]"
}

Try {
    $settings = Get-Content $AccountDataFile -raw | ConvertFrom-Json
}
catch {
    throw "Error reading [$AccountDataFile]: " + $PSItem
}

$AccountList = $settings.ServiceAccounts
$ServerList = Get-ServerNameList $settings.ServiceAccounts
$ExcludeList = $settings.NoPSSessionServers

$option = New-PSSessionOption -IncludePortInSPN

foreach ($server in $ServerList) {
    if (!($ExcludeList -contains $server)) {
        Msg "Get session for $Server"
        
        #Remove any previous session
        Remove-PSSession -Name $server -ErrorAction SilentlyContinue
        
        try {
            $adServer = Get-ADComputer -Identity $server -Properties ServicePrincipalName
        }
        catch {
            Msg "Cannot find AD object for ($server): $PSItem" -Type Error
            continue
        }

        $sessionArgs = @{
            "ErrorAction" = "Stop"
            "Name"        = $Server
            "Computer"    = $adServer.Name
        }
        if ($Credential) {
            $sessionArgs.Add("Credential", $Credential)
        }

        #We use HTTP std port at this point.
        if ($adServer.ServicePrincipalName -like "*5985") {
            Write-Verbose "New Port-session"  
            $sessionArgs.Add("SessionOption", $option)
        }                

        try {
            $session = New-PSSession @sessionArgs
        }
        catch {
            Msg "Cannot establish session to ($server): $PSItem" -Type Error
            continue
        }
    }
    else {
        Msg "Excluded server $Server"
    }
}


Msg "End Execution"
