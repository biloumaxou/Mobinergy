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
Set-StrictMode -Version latest

## Variables: Script Name and Script Paths
[string]$scriptPath = $MyInvocation.MyCommand.Definition
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent

## Variables: App Deploy Script Dependency Files
[string]$wsoneConfigFile = Join-Path -Path $scriptRoot -ChildPath 'WorkspaceOneUemApiConfig.xml'
If (-not (Test-Path -LiteralPath $wsoneConfigFile -PathType 'Leaf'))
{
    Throw 'Workspace ONE XML configuration file not found.'
}

## Import variables from XML configuration file
[Xml.XmlDocument]$xmlConfigFile = Get-Content -LiteralPath $wsoneConfigFile
[Xml.XmlElement]$xmlConfig = $xmlConfigFile.WorkspaceOneUemApi_Config

#  Get Toolkit Options
[Xml.XmlElement]$xmlWsoneOptions = $xmlConfig.Wsone_Options
[string]$configWsoneLogDir = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneOptions.Wsone_LogPath)
[string]$configWsoneLogName = $ExecutionContext.InvokeCommand.ExpandString($xmlWsoneOptions.Wsone_LogName)
[boolean]$configWsoneLogWriteToHost = [boolean]::Parse($xmlWsoneOptions.Wsone_LogWriteToHost)
[boolean]$configWsoneDisableLogging = [boolean]::Parse($xmlWsoneOptions.Wsone_DisableLogging)
[double]$configWsoneLogMaxSize = $xmlWsoneOptions.Wsone_LogMaxSize


#region Function Get-APICall
function Get-APICall {
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
#endregion

#region Function Write-Log
Function Write-Log {
    <#
    .SYNOPSIS
        Write messages to a log file in CMTrace.exe compatible format or Legacy text file format.
    .DESCRIPTION
        Write messages to a log file in CMTrace.exe compatible format or Legacy text file format and optionally display in the console.
    .PARAMETER Message
        The message to write to the log file or output to the console.
    .PARAMETER Severity
        Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
        Options: 1 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
    .PARAMETER Source
        The source of the message being logged.
    .PARAMETER ScriptSection
        The heading for the portion of the script that is being executed. Default is: $script:installPhase.
    .PARAMETER LogFileDirectory
        Set the directory where the log file will be saved.
    .PARAMETER LogFileName
        Set the name of the log file.
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
        [string]$LogFileDirectory = $configWsoneLogDir,
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
    
    Begin
    {
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
        Try
        {
            If ($script:MyInvocation.ScriptName)
            {
                [string]$ScriptSource = Split-Path -Path $script:MyInvocation.ScriptName -Leaf -ErrorAction 'Stop'
            }
            Else
            {
                [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
            }
        }
        Catch
        {
            $ScriptSource = ''
        }
        
        ## Create script block for writing log entry to the console
        [scriptblock]$WriteLogLineToHost = {
            Param (
                [string]$lTextLogLine,
                [int16]$lSeverity
            )
            If ($WriteHost)
            {
                #  Only output using color options if running in a host which supports colors.
                If ($Host.UI.RawUI.ForegroundColor)
                {
                    Switch ($lSeverity)
                    {
                        3 { Write-Host -Object $lTextLogLine -ForegroundColor 'Red' -BackgroundColor 'Black' }
                        2 { Write-Host -Object $lTextLogLine -ForegroundColor 'Yellow' -BackgroundColor 'Black' }
                        1 { Write-Host -Object $lTextLogLine }
                    }
                }
                Else
                {
                    Write-Output -InputObject $lTextLogLine
                }
            }
        }

        ## Exit function if logging to file is disabled and logging to console host is disabled
        If (($configWsoneDisableLogging) -and (-not $WriteHost))
        {
            [boolean]$ExitLoggingFunction = $true
            Return
        }
		## Exit Begin block if logging is disabled
        If ($configWsoneDisableLogging)
        {
            Return
        }
        
        ## Create the directory where the log file will be saved
        If (-not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container'))
        {
            Try
            {
				$null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop'
			}
            Catch
            {
				[boolean]$ExitLoggingFunction = $true
				#  If error creating directory, write message to console
                if($ScriptSectionDefined)
                {
                    Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the log directory [$LogFileDirectory]." -ForegroundColor 'Red'
                }
                else
                {
                    Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] :: Failed to create the log directory [$LogFileDirectory]." -ForegroundColor 'Red'
                }
                Return
			}
		}

		## Assemble the fully qualified path to the log file
		[string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName
    }
    Process
    {
        ## Exit function if logging is disabled
        If ($ExitLoggingFunction)
        {
            Return
        }
        
        ## If the message is not $null or empty, create the log entry for the different logging methods
        [string]$ConsoleLogLine = ''
        [string]$LegacyTextLogLine = ''
        
        #  Create a Console and Legacy "text" log entry
        [string]$LegacyMsg = "[$LogDate $LogTime]"
        If ($ScriptSectionDefined)
        {
            [string]$LegacyMsg += " [$ScriptSection]"
        }
        If ($Source)
        {
            [string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Message"
            Switch ($Severity)
            {
                3 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Error] :: $Message" }
                2 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Warning] :: $Message" }
                1 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Info] :: $Message" }
            }
        }
        Else
        {
            [string]$ConsoleLogLine = "$LegacyMsg :: $Message"
            Switch ($Severity)
            {
                3 { [string]$LegacyTextLogLine = "$LegacyMsg [Error] :: $Message" }
                2 { [string]$LegacyTextLogLine = "$LegacyMsg [Warning] :: $Message" }
                1 { [string]$LegacyTextLogLine = "$LegacyMsg [Info] :: $Message" }
            }
        }
        
        [string]$LogLine = $LegacyTextLogLine
        
        ## Write the log entry to the log file if logging is not currently disabled
        If (-not $configWsoneDisableLogging)
        {
            Try
            {
                $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
            }
            Catch
            {
                If ($ScriptSectionDefined)
                {
                    Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Message] to the log file [$LogFilePath]." -ForegroundColor 'Red'
                }
                else {
                    Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] :: Failed to write message [$Message] to the log file [$LogFilePath]." -ForegroundColor 'Red'
                }
            }
        }
        
        ## Execute script block to write the log entry to the console if $WriteHost is $true
        & $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
    }
    End
    {
        ## Archive log file if size is greater than $configWsoneLogMaxSize and $configWsoneLogMaxSize > 0
        Try
        {
            If ((-not $ExitLoggingFunction) -and (-not $configWsoneDisableLogging))
            {
                [IO.FileInfo]$LogFile = Get-ChildItem -LiteralPath $LogFilePath -ErrorAction 'Stop'
                [decimal]$LogFileSizeMB = $LogFile.Length/1MB
                If (($LogFileSizeMB -gt $MaxLogFileSizeMB) -and ($MaxLogFileSizeMB -gt 0))
                {
                    ## Change the file extension to "lo_"
                    [string]$ArchivedOutLogFile = [IO.Path]::ChangeExtension($LogFilePath, 'lo_')
                    If ($ScriptSectionDefined)
                    {
                        [hashtable]$ArchiveLogParams = @{ ScriptSection = $ScriptSection; Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; MaxLogFileSizeMB = 0; WriteHost = $WriteHost }
                    }
                    else
                    {
                        [hashtable]$ArchiveLogParams = @{ Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; MaxLogFileSizeMB = 0; WriteHost = $WriteHost }

                    }
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
        }
        Catch
        {
            ## If renaming of file fails, script will continue writing to log file even if size goes over the max file size
        }
    }
}
#endregion