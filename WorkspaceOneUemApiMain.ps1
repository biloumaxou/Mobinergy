<#
.SYNOPSIS
	This script contains the functions and logic engine for the Run-WorkspaceOneUemApi.ps1 script.
	# LICENSE #
	Workspace ONE UEM API - Provides a set of functions to perform common API call to Workspace ONE UEM.
	Copyright (C) 2020 - Maxime CROUZET.
.DESCRIPTION
	The script is called by the Run-WorkspaceOneUemApi.ps1 script.
.INPUTS
    None.
.OUTPUTS
    Log file stored in C:\Windows\Temp\PWDWSONEUEMAPI.log
.NOTES
    Version:        1.0
    Author:         Maxime CROUZET
    Creation Date:  June 2020
    Purpose/Change: Initial script development
.LINK
    https://www.mobinergy.com/en/contact
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

Set-StrictMode -Version latest

## Variables: Script Name
[string]$xmlConfigFileName = 'WorkspaceOneUemApiConfig'
[string]$xmlCredFileName = 'WorkspaceOneUemApiCred'
[string]$appName = 'WorkspaceOneUemApi'

## Variables: Environment Variables
[psobject]$envHost = $Host
[string]$envComputerNameFQDN = ([Net.Dns]::GetHostEntry('localhost')).HostName

## Variables: Operating System
[psobject]$envOS = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction 'SilentlyContinue'
[string]$envOSName = $envOS.Caption.Trim()
[string]$envOSServicePack = $envOS.CSDVersion
[version]$envOSVersion = $envOS.Version
[string]$envOSVersionMajor = $envOSVersion.Major
If ($envOSVersionMajor -eq 10) { [string]$envOSVersionRevision = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR' -ErrorAction SilentlyContinue).UBR }
Else { [string]$envOSVersionRevision = ,((Get-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'BuildLabEx' -ErrorAction 'SilentlyContinue').BuildLabEx -split '\.') | ForEach-Object { $_[1] } }
If ($envOSVersionRevision -notmatch '^[\d\.]+$') { $envOSVersionRevision = '' }
If ($envOSVersionRevision) { [string]$envOSVersion = "$($envOSVersion.ToString()).$envOSVersionRevision" } Else { [string]$envOSVersion = "$($envOSVersion.ToString())" }
#  Get the operating system type
[int32]$envOSProductType = $envOS.ProductType
Switch ($envOSProductType) {
	3 { [string]$envOSProductTypeName = 'Server' }
	2 { [string]$envOSProductTypeName = 'Domain Controller' }
	1 { [string]$envOSProductTypeName = 'Workstation' }
	Default { [string]$envOSProductTypeName = 'Unknown' }
}
#  Get the OS Architecture
[boolean]$Is64Bit = [boolean]((Get-CimInstance -ClassName 'Win32_Processor' -ErrorAction 'SilentlyContinue' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }

## Variables: Current Process Architecture
[boolean]$Is64BitProcess = [boolean]([IntPtr]::Size -eq 8)
If ($Is64BitProcess) { [string]$psArchitecture = 'x64' } Else { [string]$psArchitecture = 'x86' }

## Variables: Culture
[Globalization.CultureInfo]$culture = Get-Culture
[string]$currentLanguage = $culture.TwoLetterISOLanguageName.ToUpper()
[Globalization.CultureInfo]$uiculture = Get-UICulture
[string]$currentUILanguage = $uiculture.TwoLetterISOLanguageName.ToUpper()

## Variables: PowerShell
[hashtable]$envPSVersionTable = $PSVersionTable
[version]$envPSVersion = $envPSVersionTable.PSVersion
[string]$envPSEdition = $envPSVersionTable.PSEdition

## Variables: Permissions/Accounts
[Security.Principal.WindowsIdentity]$CurrentProcessToken = [Security.Principal.WindowsIdentity]::GetCurrent()
[string]$ProcessNTAccount = $CurrentProcessToken.Name

## Variables: Script Name and Script Paths
[string]$scriptPath = $MyInvocation.MyCommand.Definition
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent

## Variables: Workspace ONE UEM API Script Dependency Files
[string]$wsoneConfigFile = Join-Path -Path $scriptRoot -ChildPath "$xmlConfigFileName.xml"
[string]$wsoneCredFile = Join-Path -Path $scriptRoot -ChildPath "$xmlCredFileName.xml"
If (-not (Test-Path -LiteralPath $wsoneConfigFile -PathType 'Leaf')) { Throw "$xmlConfigFileName.xml : File not found." }
If (-not (Test-Path -LiteralPath $wsoneCredFile -PathType 'Leaf')) { Throw "$xmlCredFileName.xml : File file not found." }

## Import variables from XML Config file
try { [Xml.XmlDocument]$xmlConfigFile = Get-Content -LiteralPath $wsoneConfigFile -ErrorAction Stop }
catch { throw "Impossible to import [$wsoneConfigFile] File.`n$_.Exception.Message" }

#  Get Workspace ONE UEM API Config script Options
[Xml.XmlElement]$xmlWsoneOptions = $xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options
[string]$configWsoneLogPath = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneOptions.Wsone_LogPath)
[string]$configWsoneLogName = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneOptions.Wsone_LogName)
[double]$configWsoneLogMaxSize = $xmlWsoneOptions.Wsone_LogMaxSize
[boolean]$configWsoneLogWriteToHost = [boolean]::Parse($xmlWsoneOptions.Wsone_LogWriteToHost)
[boolean]$configWsoneDisableLogging = [boolean]::Parse($xmlWsoneOptions.Wsone_DisableLogging)

## Import variables from XML Cred file
try { [Xml.XmlDocument]$xmlCredFile = Get-Content -LiteralPath $wsoneCredFile -ErrorAction Stop }
catch { throw "Impossible to import [$wsoneCredFile] File.`n$_.Exception.Message" }
#  Get Workspace ONE UEM API Cred script Options
[Xml.XmlElement]$xmlWsoneCred = $xmlCredFile.WorkspaceOneUemApi_Cred.Wsone_Credentials
[string]$credWsoneUrl = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneCred.Wsone_Url)
[string]$credWsoneToken = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneCred.Wsone_Token)
[string]$credWsoneUserName = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneCred.Wsone_Username)
[string]$credWsonePassword = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneCred.Wsone_Password)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Test-XmlFile
Function Test-XmlFile {
    <#
    .SYNOPSIS
        Test XML Files.
    .DESCRIPTION
        Test WorkspaceOneUemApiConfig and WorkspaceOneUemApiCred Files in order to check different elements like empty variable or wrong format.
    .PARAMETER File
        The XML File to TEST.
    .EXAMPLE
        Test-ConfigXmlFile -File 'WorkspaceOneUemApiCred'
    .LINK
        https://www.mobinergy.com/en/contact
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$File
    )
    ## Get the name of this function
    [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

    ## Set Variable
    [bool]$xmlFileModified = $false

    if ( $File -eq $xmlCredFileName ) {
        ## Test if <Wsone_Options> child node are empty.
        if( [string]::IsNullOrEmpty($credWsoneUrl) ) { write-log -Message "$xmlCredFileName.xml : <Wsone_Url> - Field is empty." -Severity 3 -Source ${CmdletName}; Exit-Script 1 }
        write-log -Message "$xmlCredFileName.xml : <Wsone_Url> - Field is not Empty." -Source ${CmdletName}
        if( [string]::IsNullOrEmpty($credWsoneToken) ) { write-log -Message "$xmlCredFileName.xml : <Wsone_Token> - Field is empty." -Severity 3 -Source ${CmdletName}; Exit-Script 1 }
        write-log -Message "$xmlCredFileName.xml : <Wsone_Token> - Field is not Empty." -Source ${CmdletName}
        if( [string]::IsNullOrEmpty($credWsoneUserName) ) { write-log -Message  "$xmlCredFileName.xml : <Wsone_Username> - Field is empty." -Severity 3 -Source ${CmdletName}; Exit-Script 1 }
        write-log -Message "$xmlCredFileName.xml : <Wsone_Username> - Field is not Empty." -Source ${CmdletName}
        if( [string]::IsNullOrEmpty($credWsonePassword) ) {
            write-log -Message "$xmlCredFileName.xml : <Wsone_password> - Password is not defined" -Severity 2 -Source ${CmdletName}
            write-log -Message "$xmlCredFileName.xml : Prompt to get Password." -Source ${CmdletName}
            try { [string]$script:credWsonePassword = (Get-Credential -Message 'Please enter your API username password' -username $credWsoneUserName -ErrorAction Stop).Password | ConvertFrom-SecureString }
            catch { write-log -Message "$xmlCredFileName.xml : <Wsone_password> - Mandatory Field. Credential Prompt has been cancelled by user." -Severity 3 -Source ${CmdletName}; Exit-Script 1 }
            $xmlCredFile.WorkspaceOneUemApi_Cred.Wsone_Credentials.Wsone_Password = $credWsonePassword
            $xmlFileModified = $true
        } write-log -Message "$xmlCredFileName.xml : No empty Fields." -Source ${CmdletName}

        ## Test <Wsone_Url>
        # Should have a correct base
        if( $credWsoneUrl -notmatch '(?:(?=^http(s)?:\/\/)(http(s)?:\/\/)(as|cn)([0-9]{3,4})\.(airwatchportals|awmdm)|^(as|cn)([0-9]{3,4})\.(airwatchportals|awmdm))(?:(?=\.com$)\.com|(\.com(\/api))$)' ) {
            #Not a VMware Workspace ONE UEM SaaS Platform
            if( $credWsoneUrl -notmatch '(?:(?=^http(s)?:\/\/)(http(s)?:\/\/)([-a-z0-9%_\+]*\.){1,4}|(^[-a-z0-9%_\+]*\.)([-a-z0-9%_\+]*\.){0,3})([a-z]{1,5}$|[a-z]{1,5}\/api)' ) {
                #Not an URL valid format
                Write-Log -Message "$xmlCredFileName.xml : <Wsone_Url> - Invalid Format." -Severity 3 -Source ${CmdletName}
                Exit-Script 1
            }
        } else { write-log -Message "$xmlCredFileName.xml : <Wsone_Url> - matches a VMware Workspace ONE SaaS Platform" -Source ${CmdletName} }
        Write-Log -Message "$xmlCredFileName.xml : <Wsone_Url> - Valid Format." -Source ${CmdletName}
        Write-Log -Message "$xmlCredFileName.xml : <Wsone_Url> - Verify if [HTTP(S)] and/or [/API] are added" -Source ${CmdletName}
        $script:credWsoneUrl = $credWsoneUrl -Replace '^http(s)?:\/\/|/API$', ''
        if( $credWsoneUrl -ne $xmlCredFile.WorkspaceOneUemApi_Cred.Wsone_Credentials.Wsone_Url ) {
            Write-Log -Message "$xmlCredFileName.xml : <Wsone_Url> - [HTTP(S)] and/or [/API] are added." -Severity 2 -Source ${CmdletName}
            Write-Log -Message "$xmlCredFileName.xml : <Wsone_Url> - Delete [HTTP(S)] and/or [/API]" -Source ${CmdletName}
            $xmlCredFile.WorkspaceOneUemApi_Cred.Wsone_Credentials.Wsone_Url = $credWsoneUrl
            $xmlFileModified = $true
        } write-log -Message "$xmlCredFileName.xml : <Wsone_Url> Field has a valid format." -Source ${CmdletName}
        if( $xmlFileModified ) {
            try { $xmlCredFile.Save($wsoneCredFile); write-log -Message "$xmlCredFileName.xml :  File is saved successfully after Field have been updated.`n$_.Exception.Message" -Source ${CmdletName} }
            catch { write-log -Message "$xmlCredFileName.xml : Unable to save $xmlCredFileName.xml File after Fields have been updated.`n$_.Exception.Message" -Severity 3 -Source ${CmdletName}; Exit-Script 1 }
        }
    }
    if( $File -eq $xmlConfigFileName ) {
        ## Test if <Wsone_Options> child node has empty element
        if( [string]::IsNullOrEmpty($configWsoneLogPath) ) { throw "$xmlConfigFileName.xml : <Wsone_LogPath> - Field is empty." }
        if( [string]::IsNullOrEmpty($configWsoneLogName) ) { throw "$xmlConfigFileName.xml : <Wsone_LogName> Field is empty." }
        if( [string]::IsNullOrEmpty($configWsoneLogMaxSize) ) { throw "$xmlConfigFileName.xml : <Wsone_LogMaxSize> - Field is empty." }
        if( [string]::IsNullOrEmpty($configWsoneLogWriteToHost) ) { throw "$xmlConfigFileName.xml : <Wsone_LogWriteToHost> - Field is empty." }
        if( [string]::IsNullOrEmpty($configWsoneDisableLogging) ) { throw "$xmlConfigFileName.xml : <Wsone_DisableLogging> - Field is empty." }

        ## Test <Wsone_LogPath>
        # Should have a correct base
        $basePath = ([string]($configWsoneLogPath)).split('\')
        if( -not (Test-Path $basePath[0]) ) { throw "$xmlConfigFileName.xml : <Wsone_LogPath> - Invalid Path name." }
        # Should not finish with \
        if ( $configWsoneLogPath.Substring($configWsoneLogPath.Length - 1) -eq '\' ) {
            do { $script:configWsoneLogPath = $configWsoneLogPath.Substring(0, $configWsoneLogPath.Length - 1) } while ( $configWsoneLogPath.Substring($configWsoneLogPath.Length - 1) -eq '\' )
            $xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath = $configWsoneLogPath
            $xmlFileModified = $true
        }

        ## Test <Wsone_LogWriteToHost> and <Wsone_DisableLogging> if set True or False
        if ( 'true','False' -notcontains $configWsoneLogWriteToHost ) { Throw "$xmlConfigFileName.xml : <Wsone_LogWriteToHost> - Must be set True or False" }
        if ( 'true','False' -notcontains $configWsoneDisableLogging ) { Throw "$xmlConfigFileName.xml : <Wsone_DisableLogging> - Must be set True or False" }

        ## Test <Wsone_LogMaxSize> if set between 5 and 20
        if ( ($configWsoneLogMaxSize -notmatch "^\d+$|^-\d+$") ) { Throw "$xmlConfigFileName.xml : <Wsone_LogMaxSize> - must be set between 5 and 20" }
        if ($configWsoneLogMaxSize -notmatch "^(20|1[0-9]|[5-9])$") {
            if ( $configWsoneLogMaxSize -lt 5 ) { $script:configWsoneLogMaxSize = "5" }
            elseif ( $configWsoneLogMaxSize -gt 20 ) { $script:configWsoneLogMaxSize = "20" }
            else { Throw "$xmlConfigFileName.xml : <Wsone_LogMaxSize> - Unknow error when trying to set the Field." }
            $xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogMaxSize = $configWsoneLogMaxSize
            $xmlFileModified = $true
        }

        ## Test <Wsone_LogName> if extension exist and is .log
        if ( [string]::IsNullOrEmpty([System.IO.Path]::GetExtension($configWsoneLogName)) ) {
            $script:configWsoneLogName = "$configWsoneLogName.log"
            $xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogName = $configWsoneLogName
            $xmlFileModified = $true
        } elseif ([System.IO.Path]::GetExtension($configWsoneLogName) -ine '.log') { Throw "$xmlConfigFileName.xml : <Wsone_LogName> - Extension must be .log" }
        if ( $xmlFileModified ) {
            try { $xmlConfigFile.Save($wsoneConfigFile) }
            catch { write-log -Message "$xmlConfigFileName.xml : Unable to save $xmlConfigFileName.xml File after Fields have been updated.`n$_.Exception.Message" -Severity 3 -Source ${CmdletName}; Exit-Script 1 }
        }
    }
}
#endregion

#region Function Exit-Script
Function Exit-Script {
    <#
    .SYNOPSIS
        Exit the script properly.
    .DESCRIPTION
        Always use when exiting the script.
    .PARAMETER ExitCode
        The exit code to be passed.
    .EXAMPLE
        Exit-Script -ExitCode 0
    .EXAMPLE
        Exit-Script -ExitCode 1
    .NOTES
    .LINK
        https://www.mobinergy.com/en/contact
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [int32]$ExitCode = 0
    )

    ## Get the name of this function
    [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    Write-Log -Message "completed with exit code [$exitcode]." -Source ${CmdletName}

    [string]$LogDash = '-' * 79
    Write-Log -Message $LogDash -Source ${CmdletName}

    ## Exit the script
    Exit $exitCode
}
#endregion

#region Function Get-APICall
function Get-APICall {
    <#
    .SYNOPSIS
        Write messages to a log file in text file format.
    .DESCRIPTION
        Write messages to a log file in text file format and optionally display in the console.
    .PARAMETER Message
        The message to write to the log file and/or output to the console.
    .PARAMETER Severity
        Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
        Options: 1 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
    .PARAMETER Source
        The source of the message being logged. Default is: Unknow.
    .PARAMETER ScriptSection
        The heading for the portion of the script that is being executed. Default is: $script:installPhase.
    .PARAMETER LogFileDirectory
        Set the directory where the log file will be saved.
    .PARAMETER LogFileName
        Set the name of the log file.
    .PARAMETER MaxLogFileSizeMB
        Maximum file size limit for log file in megabytes (MB). Default is 10 MB. Must be between 5 and 20 MB
    .PARAMETER WriteHost
        Write the log message to the console.
    .EXAMPLE
        Write-Log -Message 'Error on calling API' -Severity 3 -Source 'Get-APICall' -ScriptSection 'Initialization'
    .EXAMPLE
        Write-Log -Message 'Error on calling API' -Severity 3 -Source 'Get-APICall' -LogFileDirectory 'C:\Logs' -LogFileName 'APICall.log'
    .EXAMPLE
        Write-Log -Message 'Error on calling API' -Severity 3 -write-host $False
    .LINK
        https://www.mobinergy.com/en/contact
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        [string] $method,
        [Parameter(Mandatory=$true)]
        [string] $version,
        [Parameter(Mandatory=$false)]
        [HashTable] $body)
    $URI = "https://$credWsoneUrl/API/$URL"
    if ($method -eq "GET") {
        if($version -eq "V1") {
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
#endregion

#region Function Write-Log
Function Write-Log {
    <#
    .SYNOPSIS
        Write messages to a log file in text file format.
    .DESCRIPTION
        Write messages to a log file in text file format and optionally display in the console.
    .PARAMETER Message
        The message to write to the log file and/or output to the console.
    .PARAMETER Severity
        Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
        Options: 1 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
    .PARAMETER Source
        The source of the message being logged. Default is: Unknow.
    .PARAMETER ScriptSection
        The heading for the portion of the script that is being executed. Default is: $script:installPhase.
    .PARAMETER LogFileDirectory
        Set the directory where the log file will be saved.
    .PARAMETER LogFileName
        Set the name of the log file.
    .PARAMETER MaxLogFileSizeMB
        Maximum file size limit for log file in megabytes (MB). Default is 10 MB. Must be between 5 and 20 MB
    .PARAMETER WriteHost
        Write the log message to the console.
    .EXAMPLE
        Write-Log -Message 'Error on calling API' -Severity 3 -Source 'Get-APICall' -ScriptSection 'Initialization'
    .EXAMPLE
        Write-Log -Message 'Error on calling API' -Severity 3 -Source 'Get-APICall' -LogFileDirectory 'C:\Logs' -LogFileName 'APICall.log'
    .EXAMPLE
        Write-Log -Message 'Error on calling API' -Severity 3 -write-host $False
    .LINK
        https://www.mobinergy.com/en/contact
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,3)]
        [int16]$Severity = 1,
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string]$Source = 'Unknown',
        [Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$ScriptSection = $script:installPhase,
        [Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
        [string]$LogFileDirectory = $configWsoneLogPath,
        [Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$LogFileName = $configWsoneLogName,
        [Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[decimal]$MaxLogFileSizeMB = $configWsoneLogMaxSize,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [boolean]$WriteHost = $configWsoneLogWriteToHost
    )

    Begin {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        ## Logging Variables
        #  Log file date/time
        [string]$LogTime = (Get-Date -Format 'HH\:mm\:ss.fff').ToString()
        [string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
        #  Initialize variables
        [boolean]$ExitLoggingFunction = $false
        #  Check if the script section is defined
		[boolean]$ScriptSectionDefined = [boolean](-not [string]::IsNullOrEmpty($ScriptSection))
        #  Get the file name of the source script
        Try {
            If ( $script:MyInvocation.ScriptName ) { [string]$ScriptSource = Split-Path -Path $script:MyInvocation.ScriptName -Leaf -ErrorAction 'Stop' }
            Else { [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop' }
        } Catch { $ScriptSource = 'Unknow' }

        ## Create script block for writing log entry to the console
        [scriptblock]$WriteLogLineToHost = {
            Param (
                [string]$lTextLogLine,
                [int16]$lSeverity
            )
            If  ( $WriteHost ) {
                #  Only output using color options if running in a host which supports colors.
                If ( $Host.UI.RawUI.ForegroundColor ) {
                    Switch ($lSeverity) {
                        3 { Write-Host -Object $lTextLogLine -ForegroundColor 'Red' -BackgroundColor 'Black' }
                        2 { Write-Host -Object $lTextLogLine -ForegroundColor 'Yellow' -BackgroundColor 'Black' }
                        1 { Write-Host -Object $lTextLogLine }
                    }
                } Else { Write-Output -InputObject $lTextLogLine }
            }
        }

        ## Exit function if logging to file is disabled and logging to console host is disabled
        If (($configWsoneDisableLogging) -and (-not $WriteHost)) { [boolean]$ExitLoggingFunction = $true; Return }
		## Exit Begin block if logging is disabled
        If ($configWsoneDisableLogging) { Return }

        ## Create the directory where the log file will be saved
        If ( -not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container' )) {
            Try { $null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop' }
            Catch {
				[boolean]$ExitLoggingFunction = $true
				#  If error creating directory, write message to console
                if ( $ScriptSectionDefined ) { Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the log directory [$LogFileDirectory]." -ForegroundColor 'Red' }
                else { Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] :: Failed to create the log directory [$LogFileDirectory]." -ForegroundColor 'Red' }
                Return
			}
		}

		## Assemble the fully qualified path to the log file
		[string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName
    } Process {
        ## Exit function if logging is disabled
        If ( $ExitLoggingFunction ) { Return }

        ## If the message is not $null or empty, create the log entry for the different logging methods
        [string]$ConsoleLogLine = ''
        [string]$LegacyTextLogLine = ''

        #  Create a Console and Legacy "text" log entry
        [string]$LegacyMsg = "[$LogDate $LogTime]"
        Switch ( $Severity ) {
            3 { [string]$LegacyMsg += " [Error]   -" }
            2 { [string]$LegacyMsg += " [Warning] -" }
            1 { [string]$LegacyMsg += " [Info]    -" }
        }
        If ( $ScriptSectionDefined ) { [string]$LegacyMsg += " [$ScriptSection]" }
        If ( $Source ) { [string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Message"; [string]$LegacyTextLogLine = "$LegacyMsg [$Source] :: $Message" }
        Else { [string]$ConsoleLogLine = "$LegacyMsg :: $Message"; [string]$LegacyTextLogLine = "$LegacyMsg :: $Message" }

        ## Write the log entry to the log file if logging is not currently disabled
        If ( -not $configWsoneDisableLogging ) {
            Try { $LegacyTextLogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop' }
            Catch {
                If ( $ScriptSectionDefined ) { Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Message] to the log file [$LogFilePath]." -ForegroundColor 'Red' }
                else { Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] :: Failed to write message [$Message] to the log file [$LogFilePath]." -ForegroundColor 'Red' }
            }
        }

        ## Execute script block to write the log entry to the console if $WriteHost is $true
        & $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
    } End {
        ## Archive log file if size is greater than $configWsoneLogMaxSize and $configWsoneLogMaxSize > 0
        Try {
            If ( (-not $ExitLoggingFunction) -and (-not $configWsoneDisableLogging) ) {
                [IO.FileInfo]$LogFile = Get-ChildItem -LiteralPath $LogFilePath -ErrorAction 'Stop'
                [decimal]$LogFileSizeMB = $LogFile.Length/1MB
                If ( ($LogFileSizeMB -gt $MaxLogFileSizeMB) -and ($MaxLogFileSizeMB -gt 0) ) {
                    ## Change the file extension to "lo_"
                    [string]$ArchivedOutLogFile = [IO.Path]::ChangeExtension($LogFilePath, 'lo_')
                    If ( $ScriptSectionDefined ) { [hashtable]$ArchiveLogParams = @{ ScriptSection = $ScriptSection; Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; MaxLogFileSizeMB = 0; WriteHost = $WriteHost } }
                    else { [hashtable]$ArchiveLogParams = @{ Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; MaxLogFileSizeMB = 0; WriteHost = $WriteHost } }
                    ## Log message about archiving the log file
                    $ArchiveLogMessage = "Maximum log file size [$configWsoneLogMaxSize MB] reached. Rename log file to [$ArchivedOutLogFile]."
                    Write-Log -Message $ArchiveLogMessage @ArchiveLogParams

                    ## Archive existing log file from <filename>.log to <filename>.lo_. Overwrites any existing <filename>.lo_ file.
                    Move-Item -LiteralPath $LogFilePath -Destination $ArchivedOutLogFile -Force -ErrorAction 'Stop'

                    ## Start new log file and Log message about archiving the old log file
                    $NewLogMessage = "Previous log file was renamed to [$ArchivedOutLogFile] because maximum log file size of [$configWsoneLogMaxSize MB] was reached."
                    Write-Log -Message $NewLogMessage @ArchiveLogParams
                }
            }
        } Catch { <#If renaming of file fails, script will continue writing to log file even if size goes over the max file size#> }
    }
}
#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Initialize Logging
$null = Test-XmlFile -File $xmlConfigFileName
$installPhase = 'Initialization'
$scriptSeparator = '*' * 79
Write-Log -Message $scriptSeparator -Source $appName
Write-Log -Message $scriptSeparator -Source $appName
Write-Log -Message '[Workspace ONE UEM API] setup started.' -Source $appName

## Log system/script information
Write-Log -Message "Computer Name is [$envComputerNameFQDN]" -Source $appName
Write-Log -Message "Current User is [$ProcessNTAccount]" -Source $appName
If ($envOSServicePack) { Write-Log -Message "OS Version is [$envOSName $envOSServicePack $envOSArchitecture $envOSVersion]" -Source $appName }
Else { Write-Log -Message "OS Version is [$envOSName $envOSArchitecture $envOSVersion]" -Source $appName }
Write-Log -Message "OS Type is [$envOSProductTypeName]" -Source $appName
Write-Log -Message "Current Culture is [$($culture.Name)], language is [$currentLanguage] and UI language is [$currentUILanguage]" -Source $appName
Write-Log -Message "PowerShell Host is [$($envHost.Name)] with version [$($envHost.Version)]" -Source $appName
Write-Log -Message "PowerShell Version is [$envPSVersion $psArchitecture - $envPSEdition Edition]" -Source $appName
Write-Log -Message $scriptSeparator -Source $appName

## Test XML Files
$null = Test-XmlFile -File $xmlCredFileName

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================