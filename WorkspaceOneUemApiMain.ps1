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
[string]$appDeployConfigFile = Join-Path -Path $scriptRoot -ChildPath 'AppDeployToolkitConfig.xml'
If (-not (Test-Path -LiteralPath $appDeployConfigFile -PathType 'Leaf'))
{
    Throw 'App Deploy XML configuration file not found.'
}

## Import variables from XML configuration file
[Xml.XmlDocument]$xmlConfigFile = Get-Content -LiteralPath $AppDeployConfigFile
[Xml.XmlElement]$xmlConfig = $xmlConfigFile.AppDeployWsone_Config

#  Get Toolkit Options
[Xml.XmlElement]$xmlToolkitOptions = $xmlConfig.Wsone_Options
[string]$configToolkitLogDir = $ExecutionContext.InvokeCommand.ExpandString($xmlToolkitOptions.Wsone_LogPath)
[string]$configToolkitLogDir = $ExecutionContext.InvokeCommand.ExpandString($xmlToolkitOptions.Wsone_LogName)
[boolean]$configToolkitLogWriteToHost = [boolean]::Parse($xmlToolkitOptions.Wsone_LogWriteToHost)


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
        Write-Log -Message 'Error on calling API' -Severity 3 -Source 'Get-APICall'
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
        [string]$Source = '',
        [Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
        [string]$LogFileDirectory = $configToolkitLogDir,
        [Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$LogFileName = $configToolKitLogName,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [boolean]$WriteHost = $configToolkitLogWriteToHost
    )
    
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        
        ## Logging Variables
        #  Log file date/time
        [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
        [string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
        If (-not (Test-Path -LiteralPath 'variable:LogTimeZoneBias'))
        { 
            [int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
        }
        [string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias
        #  Initialize variables
        [boolean]$ExitLoggingFunction = $false
        #  Check if the script section is defined
		[boolean]$ScriptSectionDefined = [boolean](-not [string]::IsNullOrEmpty($ScriptSection))
        #  Get the file name of the source script
        Try
        {
            If ($script:MyInvocation.Value.ScriptName)
            {
                [string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
            }
            Else
            {
                [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
            }
        }
        Catch {
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
        
        ## Create the directory where the log file will be saved
        [string]$LogFileDirectory = 'C:\Windows\Temp'
        [string]$LogFileName = 'PWDWSONEUEMAPI.log'
        If (-not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container'))
        {
            Try
            {
                $null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop'
            }
            Catch
            {
                [boolean]$ExitLoggingFunction = $true
                Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] :: Failed to create the log directory [$LogFileDirectory]." -ForegroundColor 'Red'
                Return
            }
        }
        
        ## Assemble the fully qualified path to the log file
        [string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName
    }
    Process {
        ## Exit function if logging is disabled
        If ($ExitLoggingFunction)
        {
            Return
        }
        
        ForEach ($Msg in $Message) {
            ## If the message is not $null or empty, create the log entry for the different logging methods
            [string]$CMTraceMsg = ''
            [string]$ConsoleLogLine = ''
            [string]$LegacyTextLogLine = ''
            If ($Msg) {
                #  Create the CMTrace log message
                If ($ScriptSectionDefined)
                {
                    [string]$CMTraceMsg = "[$ScriptSection] :: $Msg"
                }
                
                #  Create a Console and Legacy "text" log entry
                [string]$LegacyMsg = "[$LogDate $LogTime]"
                If ($ScriptSectionDefined)
                {
                    [string]$LegacyMsg += " [$ScriptSection]"
                }
                If ($Source)
                {
                    [string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Msg"
                    Switch ($Severity)
                    {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Info] :: $Msg" }
                    }
                }
                Else
                {
                    [string]$ConsoleLogLine = "$LegacyMsg :: $Msg"
                    Switch ($Severity) {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [Info] :: $Msg" }
                    }
                }
            }
            
            ## Execute script block to create the CMTrace.exe compatible log entry
            [string]$CMTraceLogLine = & $CMTraceLogString -lMessage $CMTraceMsg -lSource $Source -lSeverity $Severity
            
            ## Choose which log type to write to file
            If ($LogType -ieq 'CMTrace')
            {
                [string]$LogLine = $CMTraceLogLine
            }
            Else
            {
                [string]$LogLine = $LegacyTextLogLine
            }
            
            ## Write the log entry to the log file
            Try {
                $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
            }
            Catch {
                If (-not $ContinueOnError)
                {
                    Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Msg] to the log file [$LogFilePath]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                }
            }
            
            ## Execute script block to write the log entry to the console if $WriteHost is $true
            & $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
        }
    }
    End {
        ## Archive log file if size is greater than $MaxLogFileSizeMB and $MaxLogFileSizeMB > 0
        Try {
            If (-not $ExitLoggingFunction)
            {
                [IO.FileInfo]$LogFile = Get-ChildItem -LiteralPath $LogFilePath -ErrorAction 'Stop'
                [decimal]$LogFileSizeMB = $LogFile.Length/1MB
                If (($LogFileSizeMB -gt $MaxLogFileSizeMB) -and ($MaxLogFileSizeMB -gt 0))
                {
                    ## Change the file extension to "lo_"
                    [string]$ArchivedOutLogFile = [IO.Path]::ChangeExtension($LogFilePath, 'lo_')
                    [hashtable]$ArchiveLogParams = @{ ScriptSection = $ScriptSection; Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; LogType = $LogType; MaxLogFileSizeMB = 0; WriteHost = $WriteHost; ContinueOnError = $ContinueOnError; PassThru = $false }
                    
                    ## Log message about archiving the log file
                    $ArchiveLogMessage = "Maximum log file size [$MaxLogFileSizeMB MB] reached. Rename log file to [$ArchivedOutLogFile]."
                    Write-Log -Message $ArchiveLogMessage @ArchiveLogParams
                    
                    ## Archive existing log file from <filename>.log to <filename>.lo_. Overwrites any existing <filename>.lo_ file. This is the same method SCCM uses for log files.
                    Move-Item -LiteralPath $LogFilePath -Destination $ArchivedOutLogFile -Force -ErrorAction 'Stop'
                    
                    ## Start new log file and Log message about archiving the old log file
                    $NewLogMessage = "Previous log file was renamed to [$ArchivedOutLogFile] because maximum log file size of [$MaxLogFileSizeMB MB] was reached."
                    Write-Log -Message $NewLogMessage @ArchiveLogParams
                }
            }
        }
        Catch {
            ## If renaming of file fails, script will continue writing to log file even if size goes over the max file size
        }
        Finally {
            If ($PassThru) { Write-Output -InputObject $Message }
        }
    }
}
#endregion