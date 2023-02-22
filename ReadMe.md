# ServiceAccountPasswordHandler

  * [Introduction](#introduction) 
  * [Why?](#why-)
  * [Requirements](#requirements)
  * [Installation](#installation)
  * [Practical usage of setting files](#practical-usage-of-setting-files)
    + [A `json` file sample](#a--json--file-sample)
  * [Extending with custom systems](#how-to-debug)
    + [Global debugging](#global-debugging)
    + [Specific script debugging](#specific-script-debugging)
    + [Function debugging](#function-debugging)

## Introduction

The ServiceAccountPasswordHandler solution is a set of PowerShell scripts and `json` files that will make it possible to finally be able to change passwords for service accounts in a controlled way. The solution is primarally targeted for Windows.  

## Why?

Because we want to get control of service account usage. A service account used without adding it to this solution will cease to work at next password change.

Because no one should know a password to a service account. I's a service account! Having said that it is of course possible to set a temporary known password.

Because we want to secure 

## Requirements

This solution is based on the PSJumpStart module found in [PowerShell Gallery](https://www.powershellgallery.com/packages/PSJumpStart)

## Installation

Run a PowerShell session as Administrator to get a global installation of the PSJumpstart module with the command `Install-Module -Name PSJumpStart`. It is also possible to download a `zip` file from [GitHub](https://github.com/jaols/PSJumpStart) and copy the content to the local modules folder. The typical target folder would be `C:\Program Files\WindowsPowerShell\Modules\PSJumpStart\nnn` where `nnn` is the current version of the module.

This module may also be installed from PowerShell Gallery or GitHub

## Usage

Please remember to run `ServiceAccountPasswordHandler.ps1` with elevated rights or you may miss out on objects that should be processed. 

It is possible to have a central execution of password change for all service accounts with one input `json` or a distributed solution with several input files. The key issue is never having the same account name in two files.

The `ServiceAccountPasswordHandler.ps1` may be setup to run as a scheduled task using `runServiceAccountPasswordHandler.cmd`. The `cmd` file will catch exceptions otherwize lost in Task Scheduler.

## Practical usage of setting files

The 

### A `json` file sample

These files may be used to set default values for script input arguments as well as function call arguments. The syntax for setting default values for standard functions follow the `$PSDefaultParameterValues`

`Function-Name:Argument-Name=value/code`

To use a `json` file as a repository for standard input argument values to a `.ps1` you remove the function name part of the line above

`Argument-Name=value/code`

So if you are using a site name argument in several scripts  ,`[string]$SiteName` , you may create a logon domain named `dfp`file with content `SiteName="www.whatever.com"`

Call the function `Get-GlobalDefaultsFromDfpFiles` to get content for `$PSDefaultParameterValues` and the local function `GetLocalDefaultsFromDfpFiles` to set local script variables. Or simply use the template file `PSJumpStartStdTemplateWithArgumentsDfp.ps1` as a starting point.


### The art of logging

The `json` files may also be used to setup the logging environment by setting default variables for the `Msg`function. It may write output to log files, event log or output to console only. Please remember to run any PowerShell as Adminstrator the first time to create any custom log name in the event log. The use of the settings files will enable you to set different event log names, but use this carefully as any script registered for a log name cannot write to another event log name without removing the source using `Remove-Eventlog`.

## Locally customized functions

PSJumpStart will load any `ps1` function files from the local `LocalLib` folder. The Powershell files in this solution will call any `Set-[$Type]Password` in this folder to set passwords. Please use the set standard for input (arguments) and output (return object) for best result.



