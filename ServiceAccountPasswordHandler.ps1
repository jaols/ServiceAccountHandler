<#
.Synopsis
    Handle service accounts password according to json file
.DESCRIPTION
    Keep service accounts password up to date 
.PARAMETER AccountDataFile
   	Input JSON file with account data to process
.PARAMETER NotAdmin
   	Bypass check for eleveted execution

.Notes
    Author: Jack Olsson
    Changes:
#>
[CmdletBinding(SupportsShouldProcess = $False)]
param (
    [string]$AccountDataFile,
    [switch]$NotAdmin
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

function  ChangePasswordForAccount {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [string]$AccountName,
        [int]$PasswordLength,
        [PSCustomObject]$serviceData,
        [hashtable]$sessionHash,
        [Object[]]$supportedTypes   
    )
    $newPassword = New-RandomPassword -PasswordLength $PasswordLength
    Set-ADAccountPassword -Identity $AccountName -NewPassword (ConvertTo-SecureString -string "$newPassword" -AsPlainText -Force)
    
    #Server list or local only
    if ($serviceData.Servers) {
        $processServers=$serviceData.Servers | Get-Member -MemberType NoteProperty
    } else {
        $processServers=[PSCustomObject]@{
            Name="local"
        }
    }

    #ChangePasswordForAccount -serviceData $serviceData
    foreach ($server in $processServers) {
    
        $CommandArguments = @{
            password="$newPassword"
            AccountName=$AccountName
            ComputerName=$server.Name
            Verbose=$False
        }
    
        if ($SessionHash.ContainsKey($server.Name)) {
            $CommandArguments.Add("session",$SessionHash[$server.Name])        
        }
        
        $passwordTypes = $serviceData.Servers.($server.Name)
        if ([string]::IsNullOrEmpty($passwordTypes)) {
            $passwordTypes=$supportedTypes
        }
    
        foreach($PassWordType in $passwordTypes) {
            Msg ("Process $PassWordType on " + $server.Name)
                    
            $Command = "Set-" + $PassWordType + "Password @CommandArguments"
    
            $foundInstances=$null        
            $foundInstances = Invoke-Expression $Command
    
            Msg ("Found instances [$PassWordType];" + ($foundInstances -join ' | '))
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

if (!$NotAdmin) {
    #Check elevated execution
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Msg "Pleas re-run command as Administrator" -Type Error
        Exit        
    }
}

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

#Get All Available password types
$supportedTypes=Get-Command -Name Set-*Password -Module PSJumpStart | Select-Object -ExpandProperty Name | ForEach-Object {$_ -replace "Set-","" -replace "Password",""}

$exit=$false
foreach($server in $SessionHash.Keys) {
    $session = $SessionHash[$server]    
    if ($session.GetType().Name -ne "PSSession") {        
        Msg ($server + ":" + $session ) -Type Error
        $exit=$True
    }
}

#Exit if any session is missing
if ($exit) {Exit}

#Finally we get to do some real work!
foreach ($serviceAccount in ($AccountList | Get-Member -MemberType NoteProperty)) {
    Msg "Check $($serviceAccount.Name)"

    $serviceData = $AccountList.($serviceAccount.Name)

    if ([string]::IsNullOrEmpty($serviceData.LastChanged)) {
        #Set new password!
        ChangePasswordForAccount -AccountName $serviceAccount.Name -PasswordLength $settings.AccountPolicy.PasswordLength -serviceData $serviceData -sessionHash $SessionHash -supportedTypes $supportedTypes

        #Save lastChange
        $settings.ServiceAccounts.($serviceAccount.Name) | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value (Get-Date -Format "yyyy-MM-dd") -Force
    }
    else {
        #Check if pasword should be changed
        $lastChanged = [DateTime]$serviceData.LastChanged
        $spanDays = Get-Random -Maximum $settings.AccountPolicy.ChangePeriod
        
        Write-Verbose ("Due change " + $lastChanged.AddDays($settings.AccountPolicy.PasswordAge) + " - Random [$spanDays] due date: " + (Get-Date).AddDays($spanDays))
        
        if ($lastChanged.AddDays($settings.AccountPolicy.PasswordAge) -le (Get-Date)) {
            
            #Long overdue. Change now!
            ChangePasswordForAccount -AccountName $serviceAccount.Name -PasswordLength $settings.AccountPolicy.PasswordLength -serviceData $serviceData -sessionHash $SessionHash -supportedTypes $supportedTypes

            $settings.ServiceAccounts.($serviceAccount.Name) | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value (Get-Date -Format "yyyy-MM-dd") -Force
        }
        elseif ($lastChanged.AddDays($settings.AccountPolicy.PasswordAge) -le (Get-Date).AddDays($spanDays)) {
            
            #Change within interval at ramdom selection            
            ChangePasswordForAccount -AccountName $serviceAccount.Name -PasswordLength $settings.AccountPolicy.PasswordLength -serviceData $serviceData -sessionHash $SessionHash -supportedTypes $supportedTypes

            $settings.ServiceAccounts.($serviceAccount.Name) | Add-Member -MemberType NoteProperty -Name "LastChanged" -Value (Get-Date -Format "yyyy-MM-dd") -Force
        }                         
    }
}

#Save lastchanged dates (along with everything else)
$settings | ConvertTo-Json -Depth 10 | ForEach-Object { $_ -replace "    ", "  " } | Set-Content ($AccountDataFile) -Force 

Msg "End Execution"
