#########
# My Script v1
# Autor : Maxime Crouzet
##########
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -ErrorAction SilentlyContinue

##################
# FUNCTION
##################
function Connect {
    param ([Parameter(Mandatory=$true)][string] $URL, [Parameter(Mandatory=$true)][string] $Method, [Parameter(Mandatory=$true)][string] $APIVersion, [Parameter(Mandatory=$false)][HashTable] $mess)
    $URI = $Variables.APIurl + $URL
    if ($Method -eq "GET") {
        if($APIVersion -eq "V1") {
            try {
                Invoke-RestMethod -Credential $Credentials -Uri $URI -ContentType $ContentTypeV1 -Headers $headers -ErrorAction Continue
            } catch {
                return "error"
            }
        } elseif($APIVersion -eq "V2"){
            try {
                Invoke-RestMethod -Credential $Credentials -Uri $URI -ContentType $ContentTypeV2 -Headers $headers -ErrorAction Continue
            } catch {
                return "error"
            }
        }
    } elseif ($Method -eq "POST") {
        #Convert to JSON Depth at 10 ensure correct convertion for long text
        $MessageInJSON = $Mess | ConvertTo-Json -Depth 10

        #Convert Message to UTF-8 encoding
        $Body =  [System.Text.Encoding]::UTf8.GetBytes($MessageInJSON)
        if($APIVersion -eq "V1") {
            try {
                Invoke-RestMethod -Method POST -Credential $Credentials -Uri $URI -Body $Body -ContentType $ContentTypeV1 -Headers $headers -ErrorAction Continue
            } catch {
                return "error"
            }
        } elseif($APIVersion -eq "V2"){
            try{
                Invoke-RestMethod -Method POST -Credential $Credentials -Uri $URI -Body $Body -ContentType $ContentTypeV2 -Headers $headers -ErrorAction Continue
            } catch {
                return "error"
            }
        }
    } elseif ($Method -eq "PUT") {
        if($APIVersion -eq "V1") {
            try {
                Invoke-RestMethod -Method PUT -Credential $Credentials -Uri $URI -ContentType $ContentTypeV1 -Headers $headers -ErrorAction Continue
            } catch {
                return "error"
            }
        } elseif($APIVersion -eq "V2"){
            try{
                Invoke-RestMethod -Method PUT -Credential $Credentials -Uri $URI -ContentType $ContentTypeV2 -Headers $headers -ErrorAction Continue
            } catch {
                return "error"
            }
        }
    }
}

##################
# PRE PROCESS
##################
#Import Environment Variable From JSON File
$Variables = Get-Content -Raw -Path $PSScriptRoot\variables.json | ConvertFrom-Json

#Store and encode credentials
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential ($Variables.Login, $secpwd)
$Base64Auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Credentials.GetNetworkCredential().username + ":" + $Credentials.GetNetworkCredential().password ))
$BasicCredentials = "Basic " + $Base64Auth

#HTTP Headers building
$ContentTypeV1 = 'application/json; charset=utf-8'
$ContentTypeV2 = 'application/json; version=2; charset=utf-8'
$headers = @{"aw-tenant-code" = $Variables.TenantAPIkey; "Authorization"= $BasicCredentials}

