<#
.Synopsis
    Set a temporary password for a specific service account
.DESCRIPTION
    This may be used for setting a known password (maybe to be able to edit a scheduled task). The password will be valid until next run of ServiceAccountPasswordHandler.ps1
    
.PARAMETER AccountDataFile
   	Input JSON file with account data to process
.Parameter AccountName
    The user name to process (must be included in the JSON file)
.Parameter TempPassword
    The password to set. Remember to use domain policy password syntax
.Notes
    Author: Jack Olsson
    Changes:

.Example
    New-HandlerPSsessions -AccountDataFile ServiceAccountPasswordHandler.json -AccountName svc-Test -TempPassword "UsingTheP@assword4Now!"

    Change the password and set new password for all service types in ServiceAccountPasswordHandler.json
#>
[CmdletBinding(SupportsShouldProcess = $False)]
param (
    [Parameter(mandatory = $true)]
    [string]$AccountDataFile,
    [Parameter(mandatory = $true)]
    [string]$AccountName,
    [Parameter(mandatory = $true)]
    [string]$TempPassword
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

#Check elevated execution
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Msg "Pleas re-run command as Administrator" -Type Error
    Exit        
}

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
$serviceData = $AccountList.($AccountName)

#Use specific serverlist for account
if ($serviceData.Servers) {
    $ServerList = $serviceData.Servers | 
                    Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | 
                    Where-Object {$_ -ine "local" -and $_ -ine "_info" -and $_ -ine "localhost"}
}
$SessionHash = Get-ServerSessions $ServerList -ExcludeList $settings.NoPSSessionServers

Set-ADAccountPassword -Identity $AccountName -NewPassword (ConvertTo-SecureString -string "$TempPassword" -AsPlainText -Force)

#Server list or local only
if ($serviceData.Servers) {
    $processServers=$serviceData.Servers | Get-Member -MemberType NoteProperty
} else {
    $processServers=[PSCustomObject]@{
        Name="local"
    }
}

foreach ($server in $processServers) {

    $CommandArguments = @{
        password     = "$TempPassword"
        AccountName  = $AccountName
        ComputerName = $server.Name
        Verbose      = $False
    }

    if ($SessionHash.ContainsKey($server.Name)) {
        $CommandArguments.Add("session", $SessionHash[$server.Name])
    }
    
    $passwordTypes = $serviceData.Servers.($server.Name)
    if ([string]::IsNullOrEmpty($passwordTypes)) {
        $passwordTypes = $supportedTypes
    }

    foreach ($PassWordType in $passwordTypes) {
        Msg ("Process $PassWordType on " + $server.Name)
                
        $Command = "Set-" + $PassWordType + "Password @CommandArguments"

        $foundInstances = $null        
        $foundInstances = Invoke-Expression $Command

        Msg ("Found instances [$PassWordType];" + ($foundInstances -join ' | '))
    }
}

$backDate = (Get-Date).AddDays(-$settings.AccountPolicy.PasswordAge) 
Msg "Set last changed to [$backDate] to force change at next ordinary password change execution"
$settings.ServiceAccounts.$AccountName | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value ($backDate.ToString("yyyy-MM-dd")) -Force

#Save lastchanged dates (along with everything else)
$settings | ConvertTo-Json -Depth 10 | ForEach-Object { $_ -replace "    ", "  " } | Set-Content ($AccountDataFile) -Force


Msg "End Execution"
