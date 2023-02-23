# ServiceAccountHandler

  * [Introduction](#introduction) 
  * [Why?](#why-)
  * [Requirements](#requirements)
  * [Installation](#installation)
  * [Usage overview](#usage-overview)
  * [The account data file](#the-account-data-file)
    + [Account data `json` file samples](#account--json--file-samples)
  * [The art of logging](#the-art-of-logging)
  * [Down the rabbit hole](#down-the-rabbit-hole)
    + [Locally customized password handlers](#locally-customized-password-handlers)
    + [PSsessions](#pssessions)
    + [Temporary password](#temporary-password)

## Introduction

The ServiceAccountHandler solution is a set of PowerShell scripts and `json` files that will make it possible to finally be able to change passwords for service accounts in a controlled way. The solution is highly customizable by using "plug-in" functions.

The solution is primarally targeted for Windows.  

## Why?

Because we want to get control of service account usage. A service account used without adding it to this solution will cease to work at next password change.

Because no one should know a password to a service account. I's a service account! Having said that it is of course possible to set a temporary known password.

Because we want to secure our environment.

## Requirements

This solution is based on the PSJumpStart module found in [PowerShell Gallery](https://www.powershellgallery.com/packages/PSJumpStart)

## Installation

Run a PowerShell session as Administrator to get a global installation of the PSJumpstart module with the command `Install-Module -Name PSJumpStart`. It is also possible to download a `zip` file from [GitHub](https://github.com/jaols/PSJumpStart) and copy the content to the local modules folder. The typical target folder would be `C:\Program Files\WindowsPowerShell\Modules\PSJumpStart\n.n.n` where `n.n.n` is the current version of the module.

This module may also be installed from [PowerShell Gallery](https://www.powershellgallery.com/packages/ServiceAccountHandler) or downloaded from [GitHub](https://github.com/jaols/ServiceAccountHandler)

## Usage overview

Please remember to run `ServiceAccountPasswordHandler.ps1` with elevated rights or you may miss out on objects that should be processed. In fact you'll get an error if you don't.

It is possible to have a central execution of password change for all service accounts with one input `json` file or a distributed solution (on selected servers) with several input files. The key issue is never having the same account name in two files wherever they may be. The default setting file for `ServiceAccountPasswordHandler.ps1` is `ServiceAccountPasswordHandler.json`. This may be used for account data as well as environment settings, or you may create seperate environment setting files. 

The provided `DomainName.json` is an environment settings file to be renamed for local usage. The environment setting files are read in the following order (and priority):

1. User logon ID file name in script folder
2. Logon provider file name (domain or local machine) in script folder
3. Script name file in script folder
4. Logon provider file name (domain or local machine) in PSJumpStart module folder
5. Any other loaded module name in the PSJumpStart module folder (for instance an `ActiveDirectory.json` file)
6. The `PSJumpStart.json`file in the module folder for PSJumpStart.

The `ServiceAccountPasswordHandler.ps1` may be setup to run as a scheduled task using `runServiceAccountPasswordHandler.cmd`. The `cmd` file will catch exceptions otherwize lost in Task Scheduler.

## The account data file 

The account data `json` file has two main sectionns:

- `AccountPolicy` has the settings for account settings, such as password length and age.
- `ServiceAccounts` is a list of service accounts to process. Each entry in the list has a set of sub-settings.

There is also a setting for `NoSessionServer` list to indicate any servers not possible to reach by a PSsession object.

### Account data `json` file samples

```json
{
  "AccountPolicy": {
    "PasswordLength": 20,
    "PasswordAge": 90,
    "ChangePeriod": 15
  },
  "NoPSSessionServers": [
    "non-window",
    "notexistserver"
  ],
  "ServiceAccounts": {
    "svc-Foo": {
      "Servers": {
        "vmServer1": [
          "ApplicationPool",
          "ScheduleTask"
        ],
        "vmServer2": [
          "WindowService",
          "ScheduleTask"
        ],
        "vmServer3": [
          "ApplicationPool"
        ],
        "notexistserver": [],
        "non-window": []
      }      
    },
    "svc-Bar": {
      "Servers": {
        "local": [],
        "vmServer2": []
      }      
    }
  }
}
```
The sample above will generate a random 20 character password at a 90 days interval with a change period of 15 days. The account names to process are *svc-Foo* and *svc-Bar*. The *svc-Foo* account is used on 3 servers with preset password types. 
The *svc-Bar* account is used on 2 servers without preset service types. The process will use ALL found `Set-[$Type]Password` for enumeration and settiung of passwords. 

The `local` (or `localhost`) name points to the local host, no less.

```json
{
  "AccountPolicy":  {
              "PasswordLength":  20,
              "PasswordAge":  90,
              "ChangePeriod":  15
            },
  "ServiceAccounts":  {
              "svc-ServiceOne":  "",
              "svc-ServiceTwo":  ""
            }
}
```

The sample above is a bare minimum sample with local only processing and no preset password types.

## The art of logging

The `json` environment settings files may be used to setup the logging environment by setting default arguments for the `Msg`function. It may write output to log files, event log or output to console only. Please remember to run any PowerShell as Adminstrator the first time to create any custom log name in the event log. The use of the settings files will enable you to set different event log names, but use this carefully as any script registered for a log name cannot write to another event log name without removing the source using `Remove-Eventlog`.

## Down the rabbit hole

### Locally customized password handlers

PSJumpStart will load any `ps1` function files from the local `LocalLib` folder. The Powershell files in this solution will call any `Set-[$Type]Password` in this folder to set passwords. Please use the set standard for input (arguments) and output (return object) for best result. Use the included `Set-xxxPassword.ps1` file as a template.

When a customized password type is in place the type name may be used in the account data `json` file.

### PSsessions

The handler will (re-)use created PSsessions when executing `Invoke-Command` on remote computers. It is possible to prep those PSsessions with credentials using `New-HandlerPSsessions.ps1`. 

Support for port option SPN is in place for PSsessions due to a problem described here - https://www.vincecarbone.com/2021/06/11/owershell-remoting-results-in-errorcode-0x80090322/

To use port option on a server you need to register SPN with port number 5585:
```
setspn -s HTTP/servername:5985 servername
```
The session handling may be improved at some point.

### Temporary password

The `Set-ServiceAccountPassword.ps1` file is included for practical reasons. Some times you really need to know the password for a service account. The command will take a new password as an argument and mark the used account data file to change password at next runtime. 