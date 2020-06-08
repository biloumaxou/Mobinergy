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

## Variables: Workspace ONE UEM API Script Dependency Files
[string]$wsoneConfigFile = Join-Path -Path $scriptRoot -ChildPath 'WorkspaceOneUemApiConfig.xml'
If (-not (Test-Path -LiteralPath $wsoneConfigFile -PathType 'Leaf'))
{
    Throw 'Workspace ONE XML configuration file not found.'
}

## Import variables from XML configuration file
[Xml.XmlDocument]$xmlConfigFile = Get-Content -LiteralPath $wsoneConfigFile
Test-ConfigXmlFile
[Xml.XmlElement]$xmlConfig = $xmlConfigFile.WorkspaceOneUemApi_Config

#  Get Workspace ONE UEM API script Options
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

#region Function Test-ConfigXmlFile
Function Test-ConfigXmlFile {
    <#
    .SYNOPSIS
        Test WorkspaceOneUemApiConfig variable format.
    .DESCRIPTION
        Test WorkspaceOneUemApiConfig variable in order to check different elements like empty variable or wrong format.
    .EXAMPLE
        Test-ConfigXmlFile
    .LINK
        https://www.mobinergy.com/en/contact
    #>
    ## Test if Configuration File has not been alterated
    try{$xmlConfigFile.WorkspaceOneUemApi_Config}catch{throw "Your Workspace ONE XML configuration file has been alterated. <WorkspaceOneUemApi_Config> node does not exist"}
    try{$xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options}catch{throw "Your Workspace ONE XML configuration file has been alterated. <Wsone_Options> node does not exist"}
    try{$xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath}catch{throw "Your Workspace ONE XML configuration file has been alterated. <Wsone_LogPath> node does not exist"}
    try{$xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogName}catch{throw "Your Workspace ONE XML configuration file has been alterated. <Wsone_LogName> node does not exist"}
    try{$xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogMaxSize}catch{throw "Your Workspace ONE XML configuration file has been alterated. <Wsone_LogMaxSize> node does not exist"}
    try{$xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogWriteToHost}catch{throw "Your Workspace ONE XML configuration file has been alterated. <Wsone_LogWriteToHost> node does not exist"}
    try{$xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_DisableLogging}catch{throw "Your Workspace ONE XML configuration file has been alterated. <Wsone_DisableLogging> node does not exist"}

    ## Test if <Wsone_Options> child node has empty element
    if([string]::IsNullOrEmpty($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath)){throw "<Wsone_LogPath> variable is empty in Workspace ONE XML configuration file."}
    if([string]::IsNullOrEmpty($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogName)){throw "<Wsone_LogName> variable is empty in Workspace ONE XML configuration file."}
    if([string]::IsNullOrEmpty($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogMaxSize)){throw "<Wsone_LogMaxSize> variable is empty in Workspace ONE XML configuration file."}
    if([string]::IsNullOrEmpty($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogWriteToHost)){throw "<Wsone_LogWriteToHost> variable is empty in Workspace ONE XML configuration file."}
    if([string]::IsNullOrEmpty($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_DisableLogging)){throw "<Wsone_DisableLogging> variable is empty in Workspace ONE XML configuration file."}

    ## Test <Wsone_LogPath>
    # Should have a correct base
    $DN = ([string]($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath)).split("\")
    if( -not (Test-Path $DN[0])){throw "<Wsone_LogPath> seems not having a correct Path name."}
    # Should not finish with \
    if (($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath).Substring(($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath).Length - 1) -eq '\')
    {
        $xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath = ($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath).Substring(0, ($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogPath).Length - 1)
        try{$xmlConfigFile.Save($wsoneConfigFile)}catch{throw "Unable to save Workspace ONE XML configuration file after modifying <Wsone_LogPath> variable.`n$(Resolve-Error)"}
    }

    ## Test <Wsone_LogName> if extension exist and is .log
    if([string]::IsNullOrEmpty([System.IO.Path]::GetExtension($configWsoneLogName)))
    {
        $xmlWsoneOptions.Wsone_LogName = "$($configWsoneLogName).log"
        $xmlConfigFile.Save($wsoneConfigFile)
    }
    elseif ([System.IO.Path]::GetExtension($configWsoneLogName) -ine '.log')
    {
        Throw '<Wsone_LogName> variable in Workspace ONE XML configuration file do not have a correct Extension. Must be .log'
    }

    ## Test <Wsone_LogWriteToHost> and <Wsone_DisableLogging> if set with True or False Value
    if($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogWriteToHost -notcontains @('True','False')){Throw '<Wsone_LogWriteToHost> Value must be True or False'}
    if($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_DisableLogging -notcontains @('True','False')){Throw '<Wsone_DisableLogging> Value must be True or False'}

    ## Test <Wsone_LogWriteToHost> and <Wsone_DisableLogging> if set with True or False Value
    if($xmlConfigFile.WorkspaceOneUemApi_Config.Wsone_Options.Wsone_LogMaxSize -notmatch "^\d+$"){Throw '<Wsone_LogMaxSize> Value must be a positive Number'}
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
        Maximum file size limit for log file in megabytes (MB). Default is 10 MB.
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
            $ScriptSource = 'Unknow'
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

#region Function Resolve-Error
Function Resolve-Error {
    <#
    .SYNOPSIS
        Enumerate error record details.
    .DESCRIPTION
        Enumerate an error record, or a collection of error record, properties. By default, the details for the last error will be enumerated.
    .PARAMETER ErrorRecord
        The error record to resolve. The default error record is the latest one: $global:Error[0]. This parameter will also accept an array of error records.
    .PARAMETER Property
        The list of properties to display from the error record. Use "*" to display all properties.
        Default list of error properties is: Message, FullyQualifiedErrorId, ScriptStackTrace, PositionMessage, InnerException
    .PARAMETER GetErrorRecord
        Get error record details as represented by $_.
    .PARAMETER GetErrorInvocation
        Get error record invocation information as represented by $_.InvocationInfo.
    .PARAMETER GetErrorException
        Get error record exception details as represented by $_.Exception.
    .PARAMETER GetErrorInnerException
        Get error record inner exception details as represented by $_.Exception.InnerException. Will retrieve all inner exceptions if there is more than one.
    .EXAMPLE
        Resolve-Error
    .EXAMPLE
        Resolve-Error -Property *
    .EXAMPLE
        Resolve-Error -Property InnerException
    .EXAMPLE
        Resolve-Error -GetErrorInvocation:$false
    .NOTES
    .LINK
        http://psappdeploytoolkit.com
    #>
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$false,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [AllowEmptyCollection()]
            [array]$ErrorRecord,
            [Parameter(Mandatory=$false,Position=1)]
            [ValidateNotNullorEmpty()]
            [string[]]$Property = ('Message','InnerException','FullyQualifiedErrorId','ScriptStackTrace','PositionMessage'),
            [Parameter(Mandatory=$false,Position=2)]
            [switch]$GetErrorRecord = $true,
            [Parameter(Mandatory=$false,Position=3)]
            [switch]$GetErrorInvocation = $true,
            [Parameter(Mandatory=$false,Position=4)]
            [switch]$GetErrorException = $true,
            [Parameter(Mandatory=$false,Position=5)]
            [switch]$GetErrorInnerException = $true
        )
    
        Begin {
            ## If function was called without specifying an error record, then choose the latest error that occurred
            If (-not $ErrorRecord) {
                If ($global:Error.Count -eq 0) {
                    #Write-Warning -Message "The `$Error collection is empty"
                    Return
                }
                Else {
                    [array]$ErrorRecord = $global:Error[0]
                }
            }
    
            ## Allows selecting and filtering the properties on the error object if they exist
            [scriptblock]$SelectProperty = {
                Param (
                    [Parameter(Mandatory=$true)]
                    [ValidateNotNullorEmpty()]
                    $InputObject,
                    [Parameter(Mandatory=$true)]
                    [ValidateNotNullorEmpty()]
                    [string[]]$Property
                )
    
                [string[]]$ObjectProperty = $InputObject | Get-Member -MemberType '*Property' | Select-Object -ExpandProperty 'Name'
                ForEach ($Prop in $Property) {
                    If ($Prop -eq '*') {
                        [string[]]$PropertySelection = $ObjectProperty
                        Break
                    }
                    ElseIf ($ObjectProperty -contains $Prop) {
                        [string[]]$PropertySelection += $Prop
                    }
                }
                Write-Output -InputObject $PropertySelection
            }
    
            #  Initialize variables to avoid error if 'Set-StrictMode' is set
            $LogErrorRecordMsg = $null
            $LogErrorInvocationMsg = $null
            $LogErrorExceptionMsg = $null
            $LogErrorMessageTmp = $null
            $LogInnerMessage = $null
        }
        Process {
            If (-not $ErrorRecord) { Return }
            ForEach ($ErrRecord in $ErrorRecord) {
                ## Capture Error Record
                If ($GetErrorRecord) {
                    [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord -Property $Property
                    $LogErrorRecordMsg = $ErrRecord | Select-Object -Property $SelectedProperties
                }
    
                ## Error Invocation Information
                If ($GetErrorInvocation) {
                    If ($ErrRecord.InvocationInfo) {
                        [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.InvocationInfo -Property $Property
                        $LogErrorInvocationMsg = $ErrRecord.InvocationInfo | Select-Object -Property $SelectedProperties
                    }
                }
    
                ## Capture Error Exception
                If ($GetErrorException) {
                    If ($ErrRecord.Exception) {
                        [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.Exception -Property $Property
                        $LogErrorExceptionMsg = $ErrRecord.Exception | Select-Object -Property $SelectedProperties
                    }
                }
    
                ## Display properties in the correct order
                If ($Property -eq '*') {
                    #  If all properties were chosen for display, then arrange them in the order the error object displays them by default.
                    If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
                    If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
                    If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
                }
                Else {
                    #  Display selected properties in our custom order
                    If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
                    If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
                    If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
                }
    
                If ($LogErrorMessageTmp) {
                    $LogErrorMessage = 'Error Record:'
                    $LogErrorMessage += "`n-------------"
                    $LogErrorMsg = $LogErrorMessageTmp | Format-List | Out-String
                    $LogErrorMessage += $LogErrorMsg
                }
    
                ## Capture Error Inner Exception(s)
                If ($GetErrorInnerException) {
                    If ($ErrRecord.Exception -and $ErrRecord.Exception.InnerException) {
                        $LogInnerMessage = 'Error Inner Exception(s):'
                        $LogInnerMessage += "`n-------------------------"
    
                        $ErrorInnerException = $ErrRecord.Exception.InnerException
                        $Count = 0
    
                        While ($ErrorInnerException) {
                            [string]$InnerExceptionSeperator = '~' * 40
    
                            [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrorInnerException -Property $Property
                            $LogErrorInnerExceptionMsg = $ErrorInnerException | Select-Object -Property $SelectedProperties | Format-List | Out-String
    
                            If ($Count -gt 0) { $LogInnerMessage += $InnerExceptionSeperator }
                            $LogInnerMessage += $LogErrorInnerExceptionMsg
    
                            $Count++
                            $ErrorInnerException = $ErrorInnerException.InnerException
                        }
                    }
                }
    
                If ($LogErrorMessage) { $Output = $LogErrorMessage }
                If ($LogInnerMessage) { $Output += $LogInnerMessage }
    
                Write-Output -InputObject $Output
    
                If (Test-Path -LiteralPath 'variable:Output') { Clear-Variable -Name 'Output' }
                If (Test-Path -LiteralPath 'variable:LogErrorMessage') { Clear-Variable -Name 'LogErrorMessage' }
                If (Test-Path -LiteralPath 'variable:LogInnerMessage') { Clear-Variable -Name 'LogInnerMessage' }
                If (Test-Path -LiteralPath 'variable:LogErrorMessageTmp') { Clear-Variable -Name 'LogErrorMessageTmp' }
            }
        }
        End {
        }
    }
    #endregion