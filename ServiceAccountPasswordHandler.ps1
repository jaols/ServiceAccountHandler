<#
.Synopsis
    Handle service accounts password according to json file
.DESCRIPTION
    Keep service accounts password up to date 
.PARAMETER AccountDataFile
   	Input JSON file with account data to process

.Notes
    Author: Jack Olsson
    Changes:
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param (
    [string]$AccountDataFile
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

function  ChangePasswordForAccount {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        $serviceData
    )
    
    $serviceData


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

if ([string]::IsNullOrEmpty($AccountDataFile)) {
    $AccountDataFile = $MyInvocation.MyCommand.Definition -replace ".ps1$", ".json"
}

if (!(Test-Path $AccountDataFile)) {
    throw [System.IO.FileNotFoundException] "Missing input file [$AccountDataFile]" 
}

Try {
    $settings = Get-Content $AccountDataFile -raw | ConvertFrom-Json
} catch {
    throw "Error reading [$AccountDataFile]: " + $PSItem
}

$AccountList = $settings.ServiceAccounts
$ServerList = Get-ServerNameList $settings.ServiceAccounts
$SessionHash = Get-ServerSessions $ServerList -ExcludeList $settings.NoPSSessionServers

$serviceData = $AccountList.localAccount
#ChangePasswordForAccount -serviceData $serviceData

$passWord = "FAULTY-12qwaszx!"
$Account = "DPBCarina"
$PassWordType = "ApplicationPool"
$Command = "Set-" + $PassWordType + "Password -AccountName " + $Account + " -Password " + $passWord + " -Verbose"

$x = Invoke-Expression $Command

$x

foreach ($server in $serviceData.Servers) {
    $server

}
"SS"



Exit


foreach ($serviceAccount in ($AccountList | Get-Member -MemberType NoteProperty)) {
    Msg "Process $($serviceAccount.Name)"

    $serviceData = $AccountList.($serviceAccount.Name)

    if ([string]::IsNullOrEmpty($serviceData.LastChanged)) {
        #Set new password!

        #Save lastChange
        $settings.ServiceAccounts.($serviceAccount.Name) | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value (Get-Date -Format "yyyy-MM-dd") -Force
    }
    else {
        #Check if pasword should be changed
        $lastChanged = [DateTime]$serviceData.LastChanged
        $spanDays = Get-Random -Maximum $settings.AccountPolicy.ChangePeriod
        
        Write-Verbose ("Due change " + $lastChanged.AddDays($settings.AccountPolicy.PasswordAge) + " - Random [$spanDays] due date: " + (Get-Date).AddDays($spanDays))
        
        if ($lastChanged.AddDays($settings.AccountPolicy.PasswordAge) -le (Get-Date)) {
            "Its long overdue!!"

            $settings.ServiceAccounts.($serviceAccount.Name) | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value (Get-Date -Format "yyyy-MM-dd") -Force
        }
        elseif ($lastChanged.AddDays($settings.AccountPolicy.PasswordAge) -le (Get-Date).AddDays($spanDays)) {
            "Random change!"
            $settings.ServiceAccounts.($serviceAccount.Name) | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value (Get-Date -Format "yyyy-MM-dd") -Force
        }                         
    }
}

#Save lastchanged dates
$settings | ConvertTo-Json -Depth 10 | ForEach-Object { $_ -replace "    ", "  " } | Set-Content ($jsonFile + ".txt") -Force 

Msg "End Execution"
