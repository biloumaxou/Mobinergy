#Requires -Version 5
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    This script demonstrate how to use Powershell to work this Workspace ONE UEM API.
    # LICENSE #
    Workspace ONE UEM API - Provides a set of functions to perform common API call to Workspace ONE UEM.
    Copyright (C) 2020 - Maxime CROUZET.
.DESCRIPTION
    The script can call GET, POST and PUT methods either for V1 and V2 Workspace ONE UEM API
.INPUTS
    None.
.OUTPUTS
    Log file stored by default in C:\Windows\Temp\PoshWsoneUemApi.log
    EXIT CODE 0 : Script executed successfully
    EXIT CODE 404 : cannot find specific file
.NOTES
    Version:        1.0
    Author:         Maxime CROUZET
    Creation Date:  June 2020
    Purpose/Change: Initial script development
.LINK
    https://www.mobinergy.com/en/contact
#>

##* Do not modify section below
#region DoNotModify
Set-StrictMode -Version latest
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

## Variables: Exit Code
[int32]$mainExitCode = 0

## Variables: Environment
If( Test-Path -LiteralPath 'variable:HostInvocation' ) { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

## Dot source the required Workspace ONE UEM API Functions
Try {
    [string]$moduleWorkspaceOneUemApiMain = "$scriptDirectory\WorkspaceOneUemApiMain.ps1"
    If ( -not (Test-Path -LiteralPath $moduleWorkspaceOneUemApiMain -PathType 'Leaf') ) { Throw "Module does not exist at the specified location [$moduleWorkspaceOneUemApiMain]." }
    . $moduleWorkspaceOneUemApiMain
}
Catch {
    If ( $mainExitCode -eq 0 ) { [int32]$mainExitCode = 1 }
    Write-Error -Message "Module [$moduleWorkspaceOneUemApiMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
    ## Exit the script, returning the exit code
    If ( Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
}

#Store and encode credentials
$secpwd = $credWsonePassword | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential ($credWsoneUserName, $secpwd)
$Base64Auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Credentials.GetNetworkCredential().username + ":" + $Credentials.GetNetworkCredential().password ))
$BasicCredentials = "Basic " + $Base64Auth

#HTTP Headers building
$ContentTypeV1 = 'application/json; charset=utf-8'
$ContentTypeV2 = 'application/json; version=2; charset=utf-8'
$headers = @{"aw-tenant-code" = $credWsoneToken; "Authorization"= $BasicCredentials; "Accept"= "application/json"}
#endregion
##* Do not modify section above

Get-APICall -url "system/info" -method "GET" -version "V1"

<#
##################
# PRE PROCESS
##################
[string]$installPhase = 'Installation'
#region Import Environment Variable From JSON File
$Variables = Get-Content -Raw -Path $PSScriptRoot\variables.json | ConvertFrom-Json
#endregion

#Store and encode credentials
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential ($Variables.Login, $secpwd)
$Base64Auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Credentials.GetNetworkCredential().username + ":" + $Credentials.GetNetworkCredential().password ))
$BasicCredentials = "Basic " + $Base64Auth

#HTTP Headers building
$ContentTypeV1 = 'application/json; charset=utf-8'
$ContentTypeV2 = 'application/json; version=2; charset=utf-8'
$headers = @{"aw-tenant-code" = $Variables.TenantAPIkey; "Authorization"= $BasicCredentials}

#>