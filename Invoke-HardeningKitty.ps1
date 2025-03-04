﻿Function Invoke-HardeningKitty {

    <#
    .SYNOPSIS

        Invoke-HardeningKitty - Checks and hardens your Windows configuration


         =^._.^=
        _(      )/  HardeningKitty


        Author:  Michael Schneider
        License: MIT
        Required Dependencies: None
        Optional Dependencies: None


    .DESCRIPTION

        HardeningKitty supports hardening of a Windows system. The configuration of the system is
        retrieved and assessed using a finding list. In addition, the system can be hardened according
        to predefined values. HardeningKitty reads settings from the registry and uses other modules
        to read configurations outside the registry.


    .PARAMETER FileFindingList

        Path to a finding list in CSV format. HardeningKitty has one list each for machine and user settings.


    .PARAMETER Mode

        The mode Config only retrieves the settings, while the mode Audit performs an assessment of the settings.
        The mode HailMary hardens the system according to recommendations of the HardeningKitty list.


    .PARAMETER EmojiSupport

        The use of emoji is activated. The terminal should support this accordingly. Windows Terminal
        offers full support.


    .PARAMETER Log

        The logging function is activated. The script output is additionally logged in a file. The file
        name is assigned by HardeningKitty itself and the file is stored in the same directory as the script.


    .PARAMETER LogFile

        The name and location of the log file can be defined by the user.


    .PARAMETER Report

        The retrieved settings and their assessment result are stored in CSV format in a machine-readable format.
        The file name is assigned by HardeningKitty itself and the file is stored in the same directory as the script.


    .PARAMETER ReportFile

        The name and location of the report file can be defined by the user.

    .PARAMETER Backup

        The retrieved settings and their assessment result are stored in CSV format in a machine-readable format with all value to backup your previous config.

    .PARAMETER SkipMachineInformation

        Information about the system is not queried and displayed. This may be useful while debugging or
        using multiple lists on the same system.

    .EXAMPLE

        Description: HardeningKitty performs an audit, saves the results and creates a log file:
        Invoke-HardeningKitty -Mode Audit -Log -Report

        Description: HardeningKitty performs an audit with a specific list and does not show machine information:
        Invoke-HardeningKitty -FileFindingList .\lists\finding_list_0x6d69636b_user.csv -SkipMachineInformation

        Description: HardeningKitty ready only the setting with the default list, and saves the results in a specific file:
        Invoke-HardeningKitty -Mode Config -Report -Report C:\tmp\my_hardeningkitty_report.csv

    #>

    [CmdletBinding()]
    Param (

        # Definition of the finding list, default is machine setting list
        [ValidateScript({ Test-Path $_ })]
        [String]
        $FileFindingList,

        # Choose mode, read system config, audit system config, harden system config
        [ValidateSet("Audit", "Config", "HailMary")]
        [String]
        $Mode = "Audit",

        # Activate emoji support for Windows Terminal
        [Switch]
        $EmojiSupport,

        # Create a log file
        [Switch]
        $Log,

        # Skip machine information, useful when debugging
        [Switch]
        $SkipMachineInformation,

        # Skip language warning, if you understand the risk
        [Switch]
        $SkipLanguageWarning,

        # Define name and path of the log file
        [String]
        $LogFile,

        # Create a report file in CSV format
        [Switch]
        $Report,

        # Define name and path of the report file
        [String]
        $ReportFile,

        # Create a backup config file in CSV format
        [Switch]
        $Backup,

        # Define name and path of the backup file
        [String]
        $BackupFile
    )

    Function Write-ProtocolEntry {

        <#
        .SYNOPSIS

            Output of an event with timestamp and different formatting
            depending on the level. If the Log parameter is set, the
            output is also stored in a file.
        #>

        [CmdletBinding()]
        Param (

            [String]
            $Text,

            [String]
            $LogLevel
        )

        $Time = Get-Date -Format G

        Switch ($LogLevel) {
            "Info"    { $Message = "[*] $Time - $Text"; Write-Host $Message; Break }
            "Debug"   { $Message = "[-] $Time - $Text"; Write-Host -ForegroundColor Cyan $Message; Break }
            "Warning" { $Message = "[?] $Time - $Text"; Write-Host -ForegroundColor Yellow $Message; Break }
            "Error"   { $Message = "[!] $Time - $Text"; Write-Host -ForegroundColor Red $Message; Break }
            "Success" { $Message = "[$] $Time - $Text"; Write-Host -ForegroundColor Green $Message; Break }
            "Notime"  { $Message = "[*] $Text"; Write-Host -ForegroundColor Gray $Message; Break }
            Default   { $Message = "[*] $Time - $Text"; Write-Host $Message; }
        }

        If ($Log) {
            Add-MessageToFile -Text $Message -File $LogFile
        }
    }

    Function Add-MessageToFile {

        <#
        .SYNOPSIS

            Write message to a file, this function can be used for logs,
            reports, backups and more.
        #>

        [CmdletBinding()]
        Param (

            [String]
            $Text,

            [String]
            $File
        )

        try {
            Add-Content -Path $File -Value $Text -ErrorAction Stop
        } catch {
            Write-ProtocolEntry -Text "Error while writing log entries into $File. Aborting..." -LogLevel "Error"
            Break
        }

    }

    Function Write-ResultEntry {

        <#
        .SYNOPSIS

            Output of the assessment result with different formatting
            depending on the severity level. If emoji support is enabled,
            a suitable symbol is used for the severity rating.
        #>

        [CmdletBinding()]
        Param (

            [String]
            $Text,

            [String]
            $SeverityLevel
        )

        If ($EmojiSupport) {

            Switch ($SeverityLevel) {

                "Passed" { $Emoji = [char]::ConvertFromUtf32(0x1F63A); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Gray $Message; Break }
                "Low"    { $Emoji = [char]::ConvertFromUtf32(0x1F63C); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Cyan $Message; Break }
                "Medium" { $Emoji = [char]::ConvertFromUtf32(0x1F63F); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Yellow $Message; Break }
                "High"   { $Emoji = [char]::ConvertFromUtf32(0x1F640); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Red $Message; Break }
                Default  { $Message = "[*] $Text"; Write-Host $Message; }
            }

        } Else {

            Switch ($SeverityLevel) {

                "Passed" { $Message = "[+] $Text"; Write-Host -ForegroundColor Gray $Message; Break }
                "Low"    { $Message = "[-] $Text"; Write-Host -ForegroundColor Cyan $Message; Break }
                "Medium" { $Message = "[$] $Text"; Write-Host -ForegroundColor Yellow $Message; Break }
                "High"   { $Message = "[!] $Text"; Write-Host -ForegroundColor Red $Message; Break }
                Default  { $Message = "[*] $Text"; Write-Host $Message; }
            }
        }
    }

    Function Get-IniContent ($filePath) {

        <#
        .SYNOPSIS

            Read a .ini file into a tree of hashtables

        .NOTES

            Original source see https://devblogs.microsoft.com/scripting/use-powershell-to-work-with-any-ini-file/
        #>

        $ini = @{}
        switch -regex -file $FilePath {
            "^\[(.+)\]" {
                # Section
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" {
                # Comment
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                $ini[$section][$name] = $value
            }
            "(.+?)\s*=(.*)" {
                # Key
                $name, $value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }

        return $ini
    }

    Function Out-IniFile($InputObject, $FilePath, $Encoding) {

        <#
            .SYNOPSIS

                Write a hashtable out to a .ini file

            .NOTES

                Original source see https://devblogs.microsoft.com/scripting/use-powershell-to-work-with-any-ini-file/
        #>

        $outFile = New-Item -Force -ItemType file -Path $Filepath

        foreach ($i in $InputObject.keys) {
            if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
                #No Sections
                Add-Content -Encoding $Encoding -Path $outFile -Value "$i=$($InputObject[$i])"
            } else {
                #Sections
                Add-Content -Encoding $Encoding -Path $outFile -Value "[$i]"
                Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                    if ($j -match "^Comment[\d]+") {
                        Add-Content -Encoding $Encoding -Path $outFile -Value "$($InputObject[$i][$j])"
                    } else {
                        Add-Content -Encoding $Encoding -Path $outFile -Value "$j=$($InputObject[$i][$j])"
                    }
                }
                Add-Content -Encoding $Encoding -Path $outFile -Value ""
            }
        }
    }

    Function Get-HashtableValueDeep {

        <#
            .SYNOPSIS

                Get a value from a tree of hashtables
        #>

        [CmdletBinding()]
        Param (

            [Hashtable]
            $Table,

            [String]
            $Path
        )

        $Key = $Path.Split('\', 2)

        $Entry = $Table[$Key[0]]

        if ($Entry -is [hashtable] -and $Key.Length -eq 1) {
            throw "Path is incomplete (expected a leaf but still on a branch)"
        }

        if ($Entry -is [hashtable]) {
            return Get-HashtableValueDeep $Entry $Key[1];
        } else {
            if ($Key.Length -eq 1) {
                return $Entry
            } else {
                throw "Path is too long (expected a branch but arrived at a leaf before the end of the path)"
            }
        }
    }

    Function Set-HashtableValueDeep {

        <#
            .SYNOPSIS

                Set a value in a tree of hashtables, using recursion.
        #>

        [CmdletBinding()]
        Param (

            [Hashtable]
            $Table,

            [String]
            $Path,

            [String]
            $Value
        )

        $Key = $Path.Split('\', 2)

        $Entry = $Table[$Key[0]]

        if ($Key.Length -eq 2) {
            if ($null -eq $Entry) {
                $Table[$Key[0]] = @{}
            } elseif ($Entry -isnot [hashtable]) {
                throw "Not hashtable"
            }

            return Set-HashtableValueDeep -Table $Table[$Key[0]] -Path $Key[1] -Value $Value;
        } elseif ($Key.Length -eq 1) {
            $Table[$Key[0]] = $Value;
        }
    }

    Function Get-SidFromAccount {

        <#
            .SYNOPSIS

                Translate the account name (user or group) into the Security Identifier (SID)
        #>

        [CmdletBinding()]
        Param (

            [String]
            $AccountName
        )

        try {

            $AccountObject = New-Object System.Security.Principal.NTAccount($AccountName)
            $AccountSid = $AccountObject.Translate([System.Security.Principal.SecurityIdentifier]).Value

        } catch {

            # If translation fails, return account name
            $AccountSid = $AccountName
        }

        Return $AccountSid
    }

    Function Get-AccountFromSid {

        <#
            .SYNOPSIS

                Translate the Security Identifier (SID) into the account name (user or group)
        #>

        [CmdletBinding()]
        Param (

            [String]
            $AccountSid
        )

        try {

            $AccountObject = New-Object System.Security.Principal.SecurityIdentifier ($AccountSid)
            $AccountName = $AccountObject.Translate([System.Security.Principal.NTAccount]).Value

        } catch {

            # If translation fails, return account SID
            $AccountName = $AccountSid
        }

        Return $AccountName
    }

    Function Translate-SidFromWellkownAccount {

        <#
            .SYNOPSIS

                Translate the well-known account name (user or group) into the Security Identifier (SID)
                No attempt is made to get a Computer SID or Domain SID to identify groups such as Domain Admins,
                as the possibility for false positives is too great. In this case the account name is returned.
        #>

        [CmdletBinding()]
        Param (

            [String]
            $AccountName
        )

        Switch ($AccountName) {

            "BUILTIN\Account Operators" { $AccountSid = "S-1-5-32-548"; Break }
            "BUILTIN\Administrators" { $AccountSid = "S-1-5-32-544"; Break }
            "BUILTIN\Backup Operators" { $AccountSid = "S-1-5-32-551"; Break }
            "BUILTIN\Guests" { $AccountSid = "S-1-5-32-546"; Break }
            "BUILTIN\Power Users" { $AccountSid = "S-1-5-32-547"; Break }
            "BUILTIN\Print Operators" { $AccountSid = "S-1-5-32-550"; Break }
            "BUILTIN\Remote Desktop Users" { $AccountSid = "S-1-5-32-555"; Break }
            "BUILTIN\Server Operators" { $AccountSid = "S-1-5-32-549"; Break }
            "BUILTIN\Users" { $AccountSid = "S-1-5-32-545"; Break }
            "Everyone" { $AccountSid = "S-1-1-0"; Break }
            "NT AUTHORITY\ANONYMOUS LOGON" { $AccountSid = "S-1-5-7"; Break }
            "NT AUTHORITY\Authenticated Users" { $AccountSid = "S-1-5-11"; Break }
            "NT AUTHORITY\ENTERPRISE DOMAIN CONTROLLERS" { $AccountSid = "S-1-5-9"; Break }
            "NT AUTHORITY\IUSR" { $AccountSid = "S-1-5-17"; Break }
            "NT AUTHORITY\Local account and member of Administrators group" { $AccountSid = "S-1-5-114"; Break }
            "NT AUTHORITY\Local account" { $AccountSid = "S-1-5-113"; Break }
            "NT AUTHORITY\LOCAL SERVICE" { $AccountSid = "S-1-5-19"; Break }
            "NT AUTHORITY\NETWORK SERVICE" { $AccountSid = "S-1-5-20"; Break }
            "NT AUTHORITY\SERVICE" { $AccountSid = "S-1-5-6"; Break }
            "NT AUTHORITY\SYSTEM" { $AccountSid = "S-1-5-18"; Break }
            "NT SERVICE\WdiServiceHost" { $AccountSid = "S-1-5-80-3139157870-2983391045-3678747466-658725712-1809340420"; Break }
            "NT VIRTUAL MACHINE\Virtual Machines" { $AccountSid = "S-1-5-83-0"; Break }
            "Window Manager\Window Manager Group" { $AccountSid = "S-1-5-90-0"; Break }
            Default { $AccountSid = $AccountName }
        }

        Return $AccountSid
    }

    function Write-NotAdminError {
        [CmdletBinding()]
        param (
            [String]
            $FindingID,
            [String]
            $FindingName,
            [string]
            $FindingMethod
        )

        $Script:StatsError++
        $Message = "ID " + $FindingID + ", " + $FindingName + ", Method " + $FindingMethod + " requires admin priviliges. Test skipped."
        Write-ProtocolEntry -Text $Message -LogLevel "Error"
    }

    function Write-BinaryError {
        [CmdletBinding()]
        param (
            [String]
            $Binary,
            [String]
            $FindingID,
            [String]
            $FindingName,
            [string]
            $FindingMethod
        )
        $Script:StatsError++
        $Message = "ID " + $FindingID + ", " + $FindingName + ", Method " + $FindingMethod + " requires $Binary and it was not found. Test skipped."
        Write-ProtocolEntry -Text $Message -LogLevel "Error"
    }

    #
    # Binary Locations
    #
    $BinarySecedit  = "C:\Windows\System32\secedit.exe"
    $BinaryAuditpol = "C:\Windows\System32\auditpol.exe"
    $BinaryNet      = "C:\Windows\System32\net.exe"
    $BinaryBcdedit  = "C:\Windows\System32\bcdedit.exe"

    #
    # Start Main
    #
    $HardeningKittyVersion = "0.8.0-1660481591"

    #
    # Log, report and backup file
    #
    $Hostname = $env:COMPUTERNAME.ToLower()
    $FileDate = Get-Date -Format yyyyMMdd-HHmmss
    $WinSystemLocale = Get-WinSystemLocale
    $PowerShellVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

    If ($FileFindingList.Length -eq 0) {
        $ListName = "finding_list_0x6d69636b_machine"
    } Else {
        $ListName = [System.IO.Path]::GetFileNameWithoutExtension($FileFindingList)
    }

    If ($Log -and $LogFile.Length -eq 0) {
        $LogFile = "hardeningkitty_log_" + $Hostname + "_" + $ListName + "-$FileDate.log"
    }
    If ($Report -and $ReportFile.Length -eq 0) {
        $ReportFile = "hardeningkitty_report_" + $Hostname + "_" + $ListName + "-$FileDate.csv"
    }
    If ($Report) {
        $Message = '"ID","Name","Severity","Result","Recommended","TestResult","SeverityFinding"'
        Add-MessageToFile -Text $Message -File $ReportFile
    }
    If ($Backup -and $BackupFile.Length -eq 0) {
        $BackupFile = "hardeningkitty_backup_" + $Hostname + "_" + $ListName + "-$FileDate.csv"
    }
    If ($Backup) {
        $Message = '"ID","Category","Name","Method","MethodArgument","RegistryPath","RegistryItem","ClassName","Namespace","Property","DefaultValue","RecommendedValue","Operator","Severity"'
        Add-MessageToFile -Text $Message -File $BackupFile
    }

    #
    # Statistics
    #
    $StatsPassed = 0
    $StatsLow = 0
    $StatsMedium = 0
    $StatsHigh = 0
    $StatsTotal = 0
    $Script:StatsError = 0

    #
    # Header
    #
    Write-Output "`n"
    Write-Output "      =^._.^="
    Write-Output "     _(      )/  HardeningKitty $HardeningKittyVersion"
    Write-Output "`n"
    Write-ProtocolEntry -Text "Starting HardeningKitty" -LogLevel "Info"

    #
    # Machine information
    #
    If (-not($SkipMachineInformation)) {

        Write-Output "`n"
        Write-ProtocolEntry -Text "Getting machine information" -LogLevel "Info"

        #
        # The Get-ComputerInfo cmdlet gets a consolidated object of system
        # and operating system properties. This cmdlet was introduced in Windows PowerShell 5.1.
        #
        If ($PowerShellVersion -le 5.0) {

            try {

                $OperatingSystem = Get-CimInstance Win32_operatingsystem
                $ComputerSystem = Get-CimInstance Win32_ComputerSystem
                Switch ($ComputerSystem.domainrole) {
                    "0" { $Domainrole = "Standalone Workstation"; Break }
                    "1" { $Domainrole = "Member Workstation"; Break }
                    "2" { $Domainrole = "Standalone Server"; Break }
                    "3" { $Domainrole = "Member Server"; Break }
                    "4" { $Domainrole = "Backup Domain Controller"; Break }
                    "5" { $Domainrole = "Primary Domain Controller"; Break }
                }
                $Uptime = (Get-Date) - $OperatingSystem.LastBootUpTime

                $Message = "Hostname: " + $OperatingSystem.CSName
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Domain: " + $ComputerSystem.Domain
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Domain role: " + $Domainrole
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Install date: " + $OperatingSystem.InstallDate
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Last Boot Time: " + $OperatingSystem.LastBootUpTime
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Uptime: " + $Uptime
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Windows: " + $OperatingSystem.Caption
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Windows version: " + $OperatingSystem.Version
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Windows build: " + $OperatingSystem.BuildNumber
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "System-locale: " + $WinSystemLocale.Name
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
                $Message = "Powershell Version: " + $PowerShellVersion
                Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            } catch {
                Write-ProtocolEntry -Text "Getting machine information failed." -LogLevel "Warning"
            }
        } Else {

            $MachineInformation = Get-ComputerInfo
            $Message = "Hostname: " + $MachineInformation.CsDNSHostName
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Domain: " + $MachineInformation.CsDomain
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Domain role: " + $MachineInformation.CsDomainRole
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Install date: " + $MachineInformation.OsInstallDate
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Last Boot Time: " + $MachineInformation.OsLastBootUpTime
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Uptime: " + $MachineInformation.OsUptime
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Windows: " + $MachineInformation.WindowsProductName
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Windows edition: " + $MachineInformation.WindowsEditionId
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Windows version: " + $MachineInformation.WindowsVersion
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Windows build: " + $MachineInformation.WindowsBuildLabEx
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "System-locale: " + $WinSystemLocale.Name
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
            $Message = "Powershell Version: " + $PowerShellVersion
            Write-ProtocolEntry -Text $Message -LogLevel "Notime"
        }
    }

    #
    # Warning for non-english systems
    #
    If ($WinSystemLocale.Name -ne "en-US" -and -not($SkipLanguageWarning)) {
        Write-Output "`n"
        Write-ProtocolEntry -Text "Language warning" -LogLevel "Info"
        $Message = "HardeningKitty was developed for the system language 'en-US'. This system uses '" + $WinSystemLocale.Name + "' Language-dependent analyses can sometimes produce false results. Please create an issue if this occurs."
        Write-ProtocolEntry -Text $Message -LogLevel "Warning"
    }

    #
    # User information
    #
    Write-Output "`n"
    Write-ProtocolEntry -Text "Getting user information" -LogLevel "Info"

    $Message = "Username: " + [Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-ProtocolEntry -Text $Message -LogLevel "Notime"
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    $Message = "Is Admin: " + $IsAdmin
    Write-ProtocolEntry -Text $Message -LogLevel "Notime"

    #
    # Start Config/Audit mode
    # The processing is done per category of the finding list.
    # The finding list defines which module is used and the arguments and recommended values for the test.
    #
    If ($Mode -eq "Audit" -or $Mode -eq "Config") {

        # A CSV finding list is imported. HardeningKitty has one machine and one user list.
        If ($FileFindingList.Length -eq 0) {

            $CurrentLocation = Get-Location
            $DefaultList = "$CurrentLocation\lists\finding_list_0x6d69636b_machine.csv"

            If (Test-Path -Path $DefaultList) {
                $FileFindingList = $DefaultList
            } Else {
                $Message = "The finding list $DefaultList was not found."
                Write-ProtocolEntry -Text $Message -LogLevel "Error"
                Continue
            }
        }

        $FindingList = Import-Csv -Path $FileFindingList -Delimiter ","
        $LastCategory = ""

        ForEach ($Finding in $FindingList) {

            #
            # Reset
            #
            $Result = ""

            #
            # Category
            #
            If ($LastCategory -ne $Finding.Category) {

                $Message = "Starting Category " + $Finding.Category
                Write-Output "`n"
                Write-ProtocolEntry -Text $Message -LogLevel "Info"
                $LastCategory = $Finding.Category
            }

            #
            # Get Registry Item
            # Registry entries can be read with a native PowerShell function. The retrieved value is evaluated later.
            # If the registry entry is not available, a default value is used. This must be specified in the finding list.
            #
            If ($Finding.Method -eq 'Registry') {

                If (Test-Path -Path $Finding.RegistryPath) {

                    try {
                        $Result = Get-ItemPropertyValue -Path $Finding.RegistryPath -Name $Finding.RegistryItem
                    } catch {
                        $Result = $Finding.DefaultValue
                    }
                } Else {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Get secedit policy
            # Secedit configures and analyzes system security, results are written
            # to a file, which means HardeningKitty must create a temporary file
            # and afterwards delete it. HardeningKitty is very orderly.
            #
            ElseIf ($Finding.Method -eq 'secedit') {

                # Check if Secedit binary is available, skip test if not
                If (-Not (Test-Path $BinarySecedit)) {
                    Write-BinaryError -Binary $BinarySecedit -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $TempFileName = [System.IO.Path]::GetTempFileName()

                $Area = "";

                Switch ($Finding.Category) {
                    "Account Policies" { $Area = "SECURITYPOLICY"; Break }
                    "Security Options" { $Area = "SECURITYPOLICY"; Break }
                }

                &$BinarySecedit /export /cfg $TempFileName /areas $Area | Out-Null

                $Data = Get-IniContent $TempFileName

                $Value = Get-HashtableValueDeep $Data $Finding.MethodArgument

                if ($null -eq $Value) {
                    $Result = $null
                } else {
                    $Result = $Value -as [int]
                }

                Remove-Item $TempFileName
            }

            #
            # Get Registry List and search for item
            # Depending on the registry structure, the value cannot be accessed directly, but must be found within a data structure
            # If the registry entry is not available, a default value is used. This must be specified in the finding list.
            #
            ElseIf ($Finding.Method -eq 'RegistryList') {

                If (Test-Path -Path $Finding.RegistryPath) {

                    try {
                        $ResultList = Get-ItemProperty -Path $Finding.RegistryPath

                        If ($ResultList | Where-Object { $_ -like "*" + $Finding.RegistryItem + "*" }) {
                            $Result = $Finding.RegistryItem
                        } Else {
                            $Result = "Not found"
                        }

                    } catch {
                        $Result = $Finding.DefaultValue
                    }
                } Else {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Get Audit Policy
            # The output of auditpol.exe is parsed and will be evaluated later.
            # The desired value is not output directly, some output lines can be ignored
            # and are therefore skipped. If the output changes, the parsing must be adjusted :(
            #
            ElseIf ($Finding.Method -eq 'auditpol') {

                # Check if Auditpol binary is available, skip test if not
                If (-Not (Test-Path $BinaryAuditpol)) {
                    Write-BinaryError -Binary $BinaryAuditpol -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $SubCategory = $Finding.MethodArgument

                    # auditpol.exe does not write a backup in an existing file, so we have to build a name instead of create one
                    $TempFileName = [System.IO.Path]::GetTempPath() + "HardeningKitty_auditpol-" + $(Get-Date -Format yyyyMMdd-HHmmss) + ".csv"
                    &$BinaryAuditpol /backup /file:$TempFileName > $null

                    $ResultOutputLoad = Get-Content $TempFileName
                    foreach ($line in $ResultOutputLoad) {
                        $table = $line.Split(",")
                        if ($table[3] -eq $SubCategory) {

                            # Translate setting value (works only for English list, so this is workaround)
                            Switch ($table[6]) {
                                "0" { $Result = "No Auditing"; Break }
                                "1" { $Result = "Success"; Break }
                                "2" { $Result = "Failure"; Break }
                                "3" { $Result = "Success and Failure"; Break }
                            }
                        }
                    }

                    # House cleaning
                    Remove-Item $TempFileName
                    Clear-Variable -Name ("ResultOutputLoad", "table")

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Get Account Policy
            # The output of net.exe is parsed and will be evaluated later.
            # It may be necessary to use the /domain parameter when calling net.exe.
            # The values of the user executing the script are read out. These may not match the password policy.
            #
            ElseIf ($Finding.Method -eq 'accountpolicy') {

                # Check if net binary is available, skip test if not
                If (-Not (Test-Path $BinaryNet)) {
                    Write-BinaryError -Binary $BinaryNet -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $ResultOutput = &$BinaryNet accounts

                    # "Parse" account policy
                    Switch ($Finding.Name) {
                        "Force user logoff how long after time expires" { $ResultOutput[0] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Network security: Force logoff when logon hours expires" { $ResultOutput[0] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Minimum password age" { $ResultOutput[1] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Maximum password age" { $ResultOutput[2] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Minimum password length" { $ResultOutput[3] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Length of password history maintained" { $ResultOutput[4] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Account lockout threshold" { $ResultOutput[5] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Account lockout duration" { $ResultOutput[6] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                        "Reset account lockout counter" { $ResultOutput[7] -match '([a-zA-Z:, /-]+)  ([a-z0-9, ]+)' | Out-Null; $Result = $Matches[2]; Break }
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Get Local Account Information
            # The PowerShell function Get-LocalUser is used for this.
            # In order to get the correct user, the query is made via the SID,
            # the base value of the computer must first be retrieved.
            #
            ElseIf ($Finding.Method -eq 'localaccount') {

                try {

                    # Get Computer SID
                    $ComputerSid = ((Get-LocalUser | Select-Object -First 1).SID).AccountDomainSID.ToString()

                    # Get User Status
                    $Sid = $ComputerSid + "-" + $Finding.MethodArgument
                    $ResultOutput = Get-LocalUser -SID $Sid

                    If ($Finding.Name.Contains("account status")) {
                        $Result = $ResultOutput.Enabled
                    } ElseIf ($Finding.Name.Contains("Rename")) {
                        $Result = $ResultOutput.Name
                    } Else {
                        $Result = $Finding.DefaultValue
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # User Rights Assignment
            # This method was first developed with the tool accessck.exe, hence the name.
            # Due to compatibility problems in languages other than English, secedit.exe is
            # now used to read the User Rights Assignments.
            #
            # Secedit configures and analyzes system security, results are written
            # to a file, which means HardeningKitty must create a temporary file
            # and afterwards delete it. HardeningKitty is very orderly.
            #
            ElseIf ($Finding.Method -eq 'accesschk') {

                # Check if Secedit binary is available, skip test if not
                If (-Not (Test-Path $BinarySecedit)) {
                    Write-BinaryError -Binary $BinarySecedit -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $TempFileName = [System.IO.Path]::GetTempFileName()

                try {

                    &$BinarySecedit /export /cfg $TempFileName /areas USER_RIGHTS | Out-Null
                    $ResultOutputRaw = Get-Content -Encoding unicode $TempFileName | Select-String $Finding.MethodArgument

                    If ($null -eq $ResultOutputRaw) {
                        $Result = ""
                    } Else {
                        $ResultOutputList = $ResultOutputRaw.ToString().split("=").Trim()
                        $Result = $ResultOutputList[1] -Replace "\*", ""
                        $Result = $Result -Replace ",", ";"
                    }

                } catch {
                    # If secedit did not work, throw an error instead of using the DefaultValue
                    $Script:StatsError++
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", secedit.exe could not read the configuration. Test skipped."
                    Write-ProtocolEntry -Text $Message -LogLevel "Error"
                    Continue
                }

                Remove-Item $TempFileName
            }

            #
            # Windows Optional Feature
            # Yay, a native PowerShell function! The status of the feature can easily be read out directly.
            #
            ElseIf ($Finding.Method -eq 'WindowsOptionalFeature') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $ResultOutput = Get-WindowsOptionalFeature -Online -FeatureName $Finding.MethodArgument
                    $Result = $ResultOutput.State

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Get CimInstance and search for item
            # Via a CIM instance classes can be read from the CIM server.
            # Afterwards, you have to search for the correct property within the class.
            #
            ElseIf ($Finding.Method -eq 'CimInstance') {

                try {

                    $ResultList = Get-CimInstance -ClassName $Finding.ClassName -Namespace $Finding.Namespace
                    $Property = $Finding.Property

                    If ($ResultList.$Property | Where-Object { $_ -like "*" + $Finding.RecommendedValue + "*" }) {
                        $Result = $Finding.RecommendedValue
                    } Else {
                        $Result = "Not available"
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # BitLocker Drive Encryption
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            #
            ElseIf ($Finding.Method -eq 'BitLockerVolume') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $ResultOutput = Get-BitLockerVolume -MountPoint C:
                    If ($ResultOutput.VolumeType -eq 'OperatingSystem') {
                        $ResultArgument = $Finding.MethodArgument
                        $Result = $ResultOutput.$ResultArgument
                    } Else {
                        $Result = "Manual check required"
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # PowerShell Language Mode
            # This is a single purpose function, the desired configuration is output directly.
            #
            ElseIf ($Finding.Method -eq 'LanguageMode') {

                try {

                    $ResultOutput = $ExecutionContext.SessionState.LanguageMode
                    $Result = $ResultOutput

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Microsoft Defender Preferences
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            #
            ElseIf ($Finding.Method -eq 'MpPreference') {

                try {

                    $ResultOutput = Get-MpPreference
                    $ResultArgument = $Finding.MethodArgument
                    $Result = $ResultOutput.$ResultArgument

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Microsoft Defender Preferences - Attack surface reduction rules (ASR rules)
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            #
            ElseIf ($Finding.Method -eq 'MpPreferenceAsr') {

                try {

                    $ResultOutput = Get-MpPreference
                    $ResultAsrIds = $ResultOutput.AttackSurfaceReductionRules_Ids
                    $ResultAsrActions = $ResultOutput.AttackSurfaceReductionRules_Actions
                    $Result = $Finding.DefaultValue
                    $Counter = 0

                    ForEach ($AsrRule in $ResultAsrIds) {

                        If ($AsrRule -eq $Finding.MethodArgument) {
                            $Result = $ResultAsrActions[$Counter]
                            Continue
                        }
                        $Counter++
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Microsoft Defender Preferences - Exclusion lists
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            #
            ElseIf ($Finding.Method -eq 'MpPreferenceExclusion') {

                # Check if the user has admin rights, skip test if not
                # Normal users are not allowed to get exclusions
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $ResultOutput = Get-MpPreference
                    $ExclusionType = $Finding.MethodArgument
                    $ResultExclusions = $ResultOutput.$ExclusionType

                    ForEach ($Exclusion in $ResultExclusions) {
                        $Result += $Exclusion + ";"
                    }
                    # Remove last character
                    $Result = $Result -replace ".$"

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Exploit protection (System)
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            # Since the object has several dimensions and there is only one dimension
            # in the finding list (lazy) a workaround with split must be done...
            #
            ElseIf ($Finding.Method -eq 'Processmitigation') {

                try {

                    $ResultOutput = Get-ProcessMitigation -System
                    $ResultArgumentArray = $Finding.MethodArgument.Split(".")
                    $ResultArgument0 = $ResultArgumentArray[0]
                    $ResultArgument1 = $ResultArgumentArray[1]
                    $Result = $ResultOutput.$ResultArgument0.$ResultArgument1

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Exploit protection (Application)
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            # Since the object has several dimensions and there is only one dimension
            # in the finding list (lazy) a workaround with split must be done...
            #
            ElseIf ($Finding.Method -eq 'ProcessmitigationApplication') {

                try {

                    $ResultArgumentArray = $Finding.MethodArgument.Split("/")
                    $ResultOutput = Get-ProcessMitigation -Name $ResultArgumentArray[0]
                    $ResultArgument0 = $ResultArgumentArray[1]
                    $ResultArgument1 = $ResultArgumentArray[2]
                    $Result = $ResultOutput.$ResultArgument0.$ResultArgument1

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # bcdedit
            # Again, the output of a tool must be searched and parsed. Ugly...
            #
            ElseIf ($Finding.Method -eq 'bcdedit') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if Bcdedit binary is available, skip test if not
                If (-Not (Test-Path $BinaryBcdedit)) {
                    Write-BinaryError -Binary $BinaryBcdedit -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $ResultOutput = &$BinaryBcdedit
                    $ResultOutput = $ResultOutput | Where-Object { $_ -like "*" + $Finding.RecommendedValue + "*" }

                    If ($ResultOutput -match ' ([a-z,A-Z]+)') {
                        $Result = $Matches[1]
                    } Else {
                        $Result = $Finding.DefaultValue
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # FirewallRule
            # Search for a specific firewall rule with a given name
            #
            ElseIf ($Finding.Method -eq 'FirewallRule') {

                try {

                    $ResultOutput = Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $Finding.Name 2> $null
                    $Result = $ResultOutput.Enabled

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Service
            # Check the status of a service
            #
            ElseIf ($Finding.Method -eq 'service') {

                try {

                    $ResultOutput = Get-Service -Name $Finding.MethodArgument 2> $null
                    $Result = $ResultOutput.StartType

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Compare result value and recommendation
            # The finding list specifies the test, as well as the recommended values.
            # There are two output formats, one for command line output and one for the CSV file.
            #
            If ($Mode -eq "Audit") {

                #
                # User Right Assignment
                # For multilingual support, a SID translation takes place and then the known SID values are compared with each other.
                # The results are already available as SID (from secedit) and therefore the specifications are now also translated and still sorted.
                #
                If ($Finding.Method -eq 'accesschk') {

                    $SaveRecommendedValue = $Finding.RecommendedValue

                    If ($Result -ne '') {

                        $ListRecommended = $Finding.RecommendedValue.Split(";")
                        $ListRecommendedSid = @()

                        # SID Translation
                        ForEach ($AccountName in $ListRecommended) {
                            $AccountSid = Translate-SidFromWellkownAccount -AccountName $AccountName
                            $ListRecommendedSid += $AccountSid
                        }
                        # Sort SID List
                        $ListRecommendedSid = $ListRecommendedSid | Sort-Object

                        # Build String
                        ForEach ($AccountName in $ListRecommendedSid) {
                            [String] $RecommendedValueSid += $AccountName + ";"
                        }

                        $RecommendedValueSid = $RecommendedValueSid -replace ".$"
                        $Finding.RecommendedValue = $RecommendedValueSid
                        Clear-Variable -Name ("RecommendedValueSid")
                    }
                }

                #
                # Exception handling for special registry keys
                # Machine => Network access: Remotely accessible registry paths
                # Hardened UNC Paths => Remove spaces in result and recommendation only if result is not null or empty
                #
                If ($Finding.Method -eq 'Registry' -and $Finding.RegistryItem -eq "Machine") {
                    $Finding.RecommendedValue = $Finding.RecommendedValue.Replace(";", " ")
                } ElseIf ($Finding.Method -eq 'Registry' -and $Finding.RegistryPath -eq "HKLM:\Software\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths") {
                    If (![string]::IsNullOrEmpty($Result)) {
                        $Result = $Result.Replace(" ", "")
                    }
                    $Finding.RecommendedValue = $Finding.RecommendedValue.Replace(" ", "")
                }

                $ResultPassed = $false
                Switch ($Finding.Operator) {

                    "="  { If ([string] $Result -eq $Finding.RecommendedValue) { $ResultPassed = $true }; Break }
                    "<=" { try { If ([int]$Result -le [int]$Finding.RecommendedValue) { $ResultPassed = $true } } catch { $ResultPassed = $false }; Break }
                    "<=!0" { try { If ([int]$Result -le [int]$Finding.RecommendedValue -and [int]$Result -ne 0) { $ResultPassed = $true } } catch { $ResultPassed = $false }; Break }
                    ">=" { try { If ([int]$Result -ge [int]$Finding.RecommendedValue) { $ResultPassed = $true } } catch { $ResultPassed = $false }; Break }
                    "contains" { If ($Result.Contains($Finding.RecommendedValue)) { $ResultPassed = $true }; Break }
                    "!="  { If ([string] $Result -ne $Finding.RecommendedValue) { $ResultPassed = $true }; Break }
                    "=|0" { try { If ([string]$Result -eq $Finding.RecommendedValue -or $Result.Length -eq 0) { $ResultPassed = $true } } catch { $ResultPassed = $false }; Break }
                }

                #
                # Restore Result after SID translation
                # The results are already available as SID, for better readability they are translated into their names
                #
                If ($Finding.Method -eq 'accesschk') {

                    If ($Result -ne "") {

                        $ListResult = $Result.Split(";")
                        ForEach ($AccountSid in $ListResult) {
                            $AccountName = Get-AccountFromSid -AccountSid $AccountSid
                            [String] $ResultName += $AccountName.Trim() + ";"
                        }
                        $ResultName = $ResultName -replace ".$"
                        $Result = $ResultName
                        Clear-Variable -Name ("ResultName")
                    }

                    $Finding.RecommendedValue = $SaveRecommendedValue
                }

                If ($ResultPassed) {

                    # Passed
                    $TestResult = "Passed"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", Result=$Result, Recommended=" + $Finding.RecommendedValue + ", Severity=Passed"
                    Write-ResultEntry -Text $Message -SeverityLevel "Passed"

                    If ($Log) {
                        Add-MessageToFile -Text $Message -File $LogFile
                    }

                    If ($Report) {
                        $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","Passed","' + $Result + '","' + $Finding.RecommendedValue + '","' + $TestResult + '","' + $Finding.Severity + '"'
                        Add-MessageToFile -Text $Message -File $ReportFile
                    }

                    # Increment Counter
                    $StatsPassed++

                } Else {

                    # Failed
                    $TestResult = "Failed"
                    If ($Finding.Operator -eq "!=") {
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", Result=$Result, Recommended=Not " + $Finding.RecommendedValue + ", Severity=" + $Finding.Severity
                    } Else {
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", Result=$Result, Recommended=" + $Finding.RecommendedValue + ", Severity=" + $Finding.Severity
                    }

                    Write-ResultEntry -Text $Message -SeverityLevel $Finding.Severity

                    If ($Log) {
                        Add-MessageToFile -Text $Message -File $LogFile
                    }

                    If ($Report) {
                        $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $Finding.Severity + '","' + $Result + '","' + $Finding.RecommendedValue + '","' + $TestResult + '","' + $Finding.Severity + '"'
                        Add-MessageToFile -Text $Message -File $ReportFile
                    }

                    # Increment Counter
                    Switch ($Finding.Severity) {

                        "Low"    { $StatsLow++; Break }
                        "Medium" { $StatsMedium++; Break }
                        "High"   { $StatsHigh++; Break }
                    }
                }

                #
                # Only return received value
                #
            } Elseif ($Mode -eq "Config") {

                $Message = "ID " + $Finding.ID + "; " + $Finding.Name + "; Result=$Result"
                Write-ResultEntry -Text $Message

                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '",,"' + $Result + '",' + $Finding.RecommendedValue + ',,'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
                If ($Backup) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Category + '","' + $Finding.Name + '","' + $Finding.Method + '","' + $Finding.MethodArgument + '","' + $Finding.RegistryPath + '","' + $Finding.RegistryItem + '","' + $Finding.ClassName + '","' + $Finding.Namespace + '","' + $Finding.Property + '","' + $Finding.DefaultValue + '","' + $Result + '","' + $Finding.Operator + '","' + $Finding.Severity + '",'
                    Add-MessageToFile -Text $Message -File $BackupFile
                }
            }
        }
    }

    #
    # Start HailMary mode
    # HardeningKitty configures all settings in a finding list file.
    # Even though HardeningKitty works very carefully, please only
    # use HailyMary if you know what you are doing.
    #
    Elseif ($Mode -eq "HailMary") {

        # A CSV finding list is imported
        If ($FileFindingList.Length -eq 0) {

            $CurrentLocation = Get-Location
            $DefaultList = "$CurrentLocation\lists\finding_list_0x6d69636b_machine.csv"

            If (Test-Path -Path $DefaultList) {
                $FileFindingList = $DefaultList
            } Else {
                $Message = "The finding list $DefaultList was not found."
                Write-ProtocolEntry -Text $Message -LogLevel "Error"
                Continue
            }
        }

        $FindingList = Import-Csv -Path $FileFindingList -Delimiter ","
        $LastCategory = ""
        $ProcessmitigationEnableArray = @()
        $ProcessmitigationDisableArray = @()

        ForEach ($Finding in $FindingList) {

            #
            # Category
            #
            If ($LastCategory -ne $Finding.Category) {

                $Message = "Starting Category " + $Finding.Category
                Write-Output "`n"
                Write-ProtocolEntry -Text $Message -LogLevel "Info"
                $LastCategory = $Finding.Category
            }

            #
            # Registry
            # Create or modify a registry value.
            #
            If ($Finding.Method -eq 'Registry' -or $Finding.Method -eq 'RegistryList') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin) -and -not($Finding.RegistryPath.StartsWith("HKCU:\"))) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $RegType = "String"

                #
                # Basically this is true, but there is an exception for the finding "MitigationOptions_FontBocking",
                # the value "10000000000" is written to the registry as a string...
                #
                # ... and more exceptions are added over time:
                #
                # MitigationOptions_FontBocking => Mitigation Options: Untrusted Font Blocking
                # Machine => Network access: Remotely accessible registry paths
                # Retention => Event Log Service: *: Control Event Log behavior when the log file reaches its maximum size
                # AllocateDASD => Devices: Allowed to format and eject removable media
                # ScRemoveOption => Interactive logon: Smart card removal behavior
                # AutoAdminLogon => MSS: (AutoAdminLogon) Enable Automatic Logon (not recommended)
                #
                If ($Finding.RegistryItem -eq "MitigationOptions_FontBocking" -Or $Finding.RegistryItem -eq "Retention" -Or $Finding.RegistryItem -eq "AllocateDASD" -Or $Finding.RegistryItem -eq "ScRemoveOption" -Or $Finding.RegistryItem -eq "AutoAdminLogon") {
                    $RegType = "String"
                } ElseIf ($Finding.RegistryItem -eq "Machine") {
                    $RegType = "MultiString"
                    $Finding.RecommendedValue = $Finding.RecommendedValue -split ";"
                } ElseIf ($Finding.RecommendedValue -match "^\d+$") {
                    $RegType = "DWord"
                }

                if (!(Test-Path $Finding.RegistryPath)) {

                    $Result = New-Item $Finding.RegistryPath -Force;

                    If ($Result) {
                        $ResultText = "Registry key created"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.RegistryPath + ", " + $ResultText
                        $MessageSeverity = "Passed"
                        $TestResult = "Passed"
                        Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                        If ($Log) {
                            Add-MessageToFile -Text $Message -File $LogFile
                        }
                        If ($Report) {
                            $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                            Add-MessageToFile -Text $Message -File $ReportFile
                        }

                    } Else {
                        $ResultText = "Failed to create registry key"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.RegistryPath + ", " + $ResultText
                        $MessageSeverity = "High"
                        $TestResult = "Failed"
                        Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                        If ($Log) {
                            Add-MessageToFile -Text $Message -File $LogFile
                        }
                        If ($Report) {
                            $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                            Add-MessageToFile -Text $Message -File $ReportFile
                        }
                        Continue
                    }
                }

                #
                # The method RegistryList needs a separate handling, because the name of the registry key is dynamic, usually incremented.
                # Therefore, it is searched whether the value already exists or not. If the value does not exist, it counts how many
                # other values are already there in order to set the next higher value and not overwrite existing keys.
                #
                If ($Finding.Method -eq 'RegistryList') {

                    $ResultList = Get-ItemProperty -Path $Finding.RegistryPath
                    $ResultListCounter = 0
                    If ($ResultList | Where-Object { $_ -like "*" + $Finding.RegistryItem + "*" }) {
                        $ResultList.PSObject.Properties | ForEach-Object {
                            If ( $_.Value -eq $Finding.RegistryItem ) {
                                $Finding.RegistryItem = $_.Value.Name
                                Continue
                            }
                        }
                    } Else {
                        $ResultList.PSObject.Properties | ForEach-Object {
                            $ResultListCounter++
                        }
                    }
                    If ($ResultListCounter -eq 0) {
                        $Finding.RegistryItem = 1
                    } Else {
                        $Finding.RegistryItem = $ResultListCounter - 4
                    }
                }

                $Result = Set-ItemProperty -PassThru -Path $Finding.RegistryPath -Name $Finding.RegistryItem -Type $RegType -Value $Finding.RecommendedValue

                if ($Result) {
                    $ResultText = "Registry value created/modified"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.RegistryPath + ", " + $Finding.RegistryItem + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                } else {
                    $ResultText = "Failed to create registry value"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.RegistryPath + ", " + $Finding.RegistryItem + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # secedit
            # Set a security policy
            #
            If ($Finding.Method -eq 'secedit') {

                # Check if Secedit binary is available, skip test if not
                If (-Not (Test-Path $BinarySecedit)) {
                    Write-BinaryError -Binary $BinarySecedit -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $Area = "";

                Switch ($Finding.Category) {
                    "Account Policies" { $Area = "SECURITYPOLICY"; Break }
                    "Security Options" { $Area = "SECURITYPOLICY"; Break }
                }

                $TempFileName = [System.IO.Path]::GetTempFileName()
                $TempDbFileName = [System.IO.Path]::GetTempFileName()

                &$BinarySecedit /export /cfg $TempFileName /areas $Area | Out-Null

                $Data = Get-IniContent $TempFileName

                Set-HashtableValueDeep -Table $Data -Path $Finding.MethodArgument -Value $Finding.RecommendedValue

                Out-IniFile -InputObject $Data -FilePath $TempFileName -Encoding Unicode

                &$BinarySecedit /import /cfg $TempFileName /overwrite /areas $Area /db $TempDbFileName /quiet | Out-Null

                if ($LastExitCode -ne 0) {
                    $ResultText = "Failed to import security policy into temporary database"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                    Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                    If ($Log) {
                        Add-MessageToFile -Text $Message -File $LogFile
                    }
                    If ($Report) {
                        $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                        Add-MessageToFile -Text $Message -File $ReportFile
                    }
                    Remove-Item $TempFileName
                    Remove-Item $TempDbFileName
                    Continue
                }

                $ResultText = "Imported security policy into temporary database"
                $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                $MessageSeverity = "Passed"
                $TestResult = "Passed"

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }

                &$BinarySecedit /configure /db $TempDbFileName /overwrite /areas SECURITYPOLICY /quiet | Out-Null

                if ($LastExitCode -ne 0) {
                    $ResultText = "Failed to configure security policy"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                    Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                    If ($Log) {
                        Add-MessageToFile -Text $Message -File $LogFile
                    }
                    If ($Report) {
                        $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                        Add-MessageToFile -Text $Message -File $ReportFile
                    }
                    Remove-Item $TempFileName
                    Remove-Item $TempDbFileName
                    Continue
                }

                $ResultText = "Configured security policy"
                $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                $MessageSeverity = "Passed"
                $TestResult = "Passed"

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }

                Remove-Item $TempFileName
                Remove-Item $TempDbFileName
            }

            #
            # auditpol
            # Set an audit policy
            #
            If ($Finding.Method -eq 'auditpol') {

                # Check if Auditpol binary is available, skip test if not
                If (-Not (Test-Path $BinaryAuditpol)) {
                    Write-BinaryError -Binary $BinaryAuditpol -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $Success = if ($Finding.RecommendedValue -ilike "*success*") { "enable" } else { "disable" }
                $Failure = if ($Finding.RecommendedValue -ilike "*failure*") { "enable" } else { "disable" }

                $SubCategory = $Finding.MethodArgument

                &$BinaryAuditpol /set /subcategory:"$($SubCategory)" /success:$($Success) /failure:$($Failure) | Out-Null

                if ($LastExitCode -eq 0) {
                    $ResultText = "Audit policy set"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                } else {
                    $ResultText = "Failed to set audit policy"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # accountpolicy
            # Set a user account policy
            #
            If ($Finding.Method -eq 'accountpolicy') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if net binary is available, skip test if not
                If (-Not (Test-Path $BinaryNet)) {
                    Write-BinaryError -Binary $BinaryNet -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $Sw = "";

                Switch ($Finding.Name) {
                    "Force user logoff how long after time expires" { $Sw = "/FORCELOGOFF:$($Finding.RecommendedValue)"; Break }
                    "Minimum password age" { $Sw = "/MINPWAGE:$($Finding.RecommendedValue)"; Break }
                    "Maximum password age" { $Sw = "/MAXPWAGE:$($Finding.RecommendedValue)"; Break }
                    "Minimum password length" { $Sw = "/MINPWLEN:$($Finding.RecommendedValue)"; Break }
                    "Length of password history maintained" { $Sw = "/UNIQUEPW:$($Finding.RecommendedValue)"; Break }
                    "Account lockout threshold" { $Sw = "/lockoutthreshold:$($Finding.RecommendedValue)"; Break; }
                    "Account lockout duration" { $Sw = @("/lockoutwindow:$($Finding.RecommendedValue)", "/lockoutduration:$($Finding.RecommendedValue)"); Break }
                    "Reset account lockout counter" { $Sw = "/lockoutwindow:$($Finding.RecommendedValue)"; Break }
                }

                &$BinaryNet accounts $Sw | Out-Null

                if ($LastExitCode -eq 0) {
                    $ResultText = "Account policy set"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                } else {
                    $ResultText = "Failed to set account policy"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # accesschk
            # For the audit mode, accesschk is used, but the rights are set with secedit.
            #
            If ($Finding.Method -eq 'accesschk') {

                # Check if Secedit binary is available, skip test if not
                If (-Not (Test-Path $BinarySecedit)) {
                    Write-BinaryError -Binary $BinarySecedit -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $TempFileName = [System.IO.Path]::GetTempFileName()
                $TempDbFileName = [System.IO.Path]::GetTempFileName()

                &$BinarySecedit /export /cfg $TempFileName /areas USER_RIGHTS | Out-Null

                if ($Finding.RecommendedValue -eq "") {
                    (Get-Content -Encoding unicode $TempFileName) -replace "$($Finding.MethodArgument).*", "$($Finding.MethodArgument) = " | Out-File $TempFileName
                } else {
                    $ListTranslated = @()
                    $Finding.RecommendedValue -split ';' | Where-Object {
                        # Get SID to translate the account name
                        $AccountSid = Translate-SidFromWellkownAccount -AccountName $_
                        # Get account name from system with SID (local translation)
                        $AccountName = Get-AccountFromSid -AccountSid $AccountSid
                        $ListTranslated += $AccountName
                    }

                    # If User Right Assignment exists, replace values
                    If ( ((Get-Content -Encoding unicode $TempFileName) | Select-String $($Finding.MethodArgument)).Count -gt 0 ) {
                        (Get-Content -Encoding unicode $TempFileName) -replace "$($Finding.MethodArgument).*", "$($Finding.MethodArgument) = $($ListTranslated -join ',')" | Out-File $TempFileName
                    }
                    # If it does not exist, add a new entry into the file at the right position
                    Else {
                        $TempFileContent = Get-Content -Encoding unicode $TempFileName
                        $LineNumber = $TempFileContent.Count
                        $TempFileContent[$LineNumber - 3] = "$($Finding.MethodArgument) = $($ListTranslated -join ',')"
                        $TempFileContent[$LineNumber - 2] = "[Version]"
                        $TempFileContent[$LineNumber - 1] = 'signature="$CHICAGO$"'
                        $TempFileContent += "Revision=1"
                        $TempFileContent | Set-Content -Encoding unicode $TempFileName
                    }
                }

                &$BinarySecedit /import /cfg $TempFileName /overwrite /areas USER_RIGHTS /db $TempDbFileName /quiet | Out-Null

                if ($LastExitCode -ne 0) {
                    $ResultText = "Failed to import user right assignment into temporary database"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "High"
                    Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                    Remove-Item $TempFileName
                    Remove-Item $TempDbFileName
                    Continue
                }

                $ResultText = "Imported user right assignment into temporary database"
                $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                $MessageSeverity = "Passed"
                $TestResult = "Passed"

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }

                &$BinarySecedit /configure /db $TempDbFileName /overwrite /areas USER_RIGHTS /quiet | Out-Null

                if ($LastExitCode -ne 0) {
                    $ResultText = "Failed to configure system user right assignment"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                    Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                    If ($Log) {
                        Add-MessageToFile -Text $Message -File $LogFile
                    }
                    If ($Report) {
                        $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                        Add-MessageToFile -Text $Message -File $ReportFile
                    }
                    Remove-Item $TempFileName
                    Remove-Item $TempDbFileName
                    Continue
                }

                $ResultText = "Configured system user right assignment"
                $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $Finding.RecommendedValue + ", " + $ResultText
                $MessageSeverity = "Passed"
                $TestResult = "Passed"

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }

                Remove-Item $TempFileName
                Remove-Item $TempDbFileName
            }

            #
            # WindowsOptionalFeature
            # Install / Remove a Windows feature
            #
            If ($Finding.Method -eq 'WindowsOptionalFeature') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                #
                # Check if feature is installed and should be removed, or
                # it is missing and should be installed
                #
                try {
                    $ResultOutput = Get-WindowsOptionalFeature -Online -FeatureName $Finding.MethodArgument
                    $Result = $ResultOutput.State
                } catch {
                    $ResultText = "Could not check status"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                    Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                    If ($Log) {
                        Add-MessageToFile -Text $Message -File $LogFile
                    }
                    If ($Report) {
                        $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                        Add-MessageToFile -Text $Message -File $ReportFile
                    }
                    Continue
                }

                # Feature will be removed, a reboot will be suppressed
                If ($Result -eq "Enabled" -and $Finding.RecommendedValue -eq "Disabled") {

                    try {
                        $Result = Disable-WindowsOptionalFeature -NoRestart -Online -FeatureName $Finding.MethodArgument
                    } catch {
                        $ResultText = "Could not be removed"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                        $MessageSeverity = "High"
                        $TestResult = "Failed"
                        Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                        If ($Log) {
                            Add-MessageToFile -Text $Message -File $LogFile
                        }
                        If ($Report) {
                            $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                            Add-MessageToFile -Text $Message -File $ReportFile
                        }
                        Continue
                    }

                    $ResultText = "Feature removed"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                }
                # No changes required
                ElseIf ($Result -eq "Disabled" -and $Finding.RecommendedValue -eq "Disabled") {
                    $ResultText = "Feature is not installed"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                }
                # Feature will be installed, a reboot will be suppressed
                ElseIf ($Result -eq "Disabled" -and $Finding.RecommendedValue -eq "Enabled") {

                    try {
                        $Result = Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName $Finding.MethodArgument
                    } catch {
                        $ResultText = "Could not be installed"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                        $MessageSeverity = "High"
                        $TestResult = "Failed"
                        Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                        If ($Log) {
                            Add-MessageToFile -Text $Message -File $LogFile
                        }
                        If ($Report) {
                            $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                            Add-MessageToFile -Text $Message -File $ReportFile
                        }
                        Continue
                    }

                    $ResultText = "Feature installed"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                }
                # No changes required
                ElseIf ($Result -eq "Enabled" -and $Finding.RecommendedValue -eq "Enabled") {
                    $ResultText = "Feature is already installed"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # MpPreference
            # Set a Windows Defender policy
            #
            If ($Finding.Method -eq 'MpPreference') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $ResultMethodArgument = $Finding.MethodArgument
                $ResultRecommendedValue = $Finding.RecommendedValue

                Switch ($ResultRecommendedValue) {
                    "True" { $ResultRecommendedValue = 1; Break }
                    "False" { $ResultRecommendedValue = 0; Break }
                }

                # Build a hashtable MpPreferenceArgs for splatting arguments to Set-MpPreference. See https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting
                $MpPreferenceArgs = @{
                    $ResultMethodArgument = $ResultRecommendedValue
                }

                Set-MpPreference @MpPreferenceArgs

                if ($?) {
                    $ResultText = "Method value modified"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                } else {
                    $ResultText = "Failed to change Method value"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.MethodArgument + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Passed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # Microsoft Defender Preferences - Attack surface reduction rules (ASR rules)
            # The values are saved from a PowerShell function into an object.
            # The desired arguments can be accessed directly.
            #
            If ($Finding.Method -eq 'MpPreferenceAsr') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $ResultMethodArgument = $Finding.MethodArgument
                $ResultRecommendedValue = $Finding.RecommendedValue

                Switch ($ResultRecommendedValue) {
                    "True" { $ResultRecommendedValue = 1; Break }
                    "False" { $ResultRecommendedValue = 0; Break }
                }

                # Build a hashtable MpPreferenceArgs for splatting arguments to Set-MpPreference. See https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting
                $MpPreferenceArgs = @{
                    AttackSurfaceReductionRules_Ids     = $ResultMethodArgument
                    AttackSurfaceReductionRules_Actions = $ResultRecommendedValue
                }

                Add-MpPreference @MpPreferenceArgs

                if ($?) {
                    $ResultText = "ASR rule added to list"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $Finding.MethodArgument + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                } else {
                    $ResultText = "Failed to add ASR rule"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $Finding.MethodArgument + ", " + $ResultText
                    $MessageSeverity = "High"
                    $TestResult = "Failed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # Exploit protection
            # Set exploit protection values
            #
            # I noticed irregularities when the process mitigations were set individually,
            # in some cases settings that had already been set were then reset. Therefore,
            # the settings are collected in an array and finally set at the end of the processing.
            #
            If ($Finding.Method -eq 'Processmitigation') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $SettingArgumentArray = $Finding.MethodArgument.Split(".")

                If ( $Finding.RecommendedValue -eq "ON") {

                    If ( $SettingArgumentArray[1] -eq "Enable" ) {
                        $ProcessmitigationEnableArray += $SettingArgumentArray[0]
                    } Else {
                        $ProcessmitigationEnableArray += $SettingArgumentArray[1]
                    }
                } ElseIf ( $Finding.RecommendedValue -eq "OFF") {

                    If ($SettingArgumentArray[1] -eq "TelemetryOnly") {
                        $ProcessmitigationDisableArray += "SEHOPTelemetry"
                    } ElseIf ( $SettingArgumentArray[1] -eq "Enable" ) {
                        $ProcessmitigationDisableArray += $SettingArgumentArray[0]
                    } Else {
                        $ProcessmitigationDisableArray += $SettingArgumentArray[1]
                    }
                }
                $ResultText = "setting added to list"
                $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                $MessageSeverity = "Passed"
                $TestResult = "Passed"
                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # bcdedit
            # Force use of Data Execution Prevention, if it is not already set
            #
            If ($Finding.Method -eq 'bcdedit') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                # Check if Bcdedit binary is available, skip test if not
                If (-Not (Test-Path $BinaryBcdedit)) {
                    Write-BinaryError -Binary $BinaryBcdedit -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                try {

                    $ResultOutput = &$BinaryBcdedit
                    $ResultOutput = $ResultOutput | Where-Object { $_ -like "*" + $Finding.RecommendedValue + "*" }

                    If ($ResultOutput -match ' ([a-z,A-Z]+)') {
                        $Result = $Matches[1]
                    } Else {
                        $Result = $Finding.DefaultValue
                    }

                } catch {
                    $Result = $Finding.DefaultValue
                }

                If ($Result -ne $Finding.RecommendedValue) {

                    try {

                        $ResultOutput = &$BinaryBcdedit "/set" $Finding.MethodArgument $Finding.RecommendedValue

                    } catch {

                        $ResultText = "Setting could not be enabled"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                        $MessageSeverity = "High"
                        $TestResult = "Failed"
                    }

                    $ResultText = "Setting enabled. Please restart the system to activate it"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                } Else {

                    $ResultText = "Setting is already set correct"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }
                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }

            #
            # FirewallRule
            # Create a firewall rule. First it will be checked if the rule already exists
            #
            If ($Finding.Method -eq 'FirewallRule') {

                # Check if the user has admin rights, skip test if not
                If (-not($IsAdmin)) {
                    Write-NotAdminError -FindingID $Finding.ID -FindingName $Finding.Name -FindingMethod $Finding.Method
                    Continue
                }

                $FwRule = $Finding.MethodArgument
                $FwRuleArray = $FwRule.Split("|")

                $FwDisplayName = $Finding.Name
                $FwProfile = $FwRuleArray[0]
                $FwDirection = $FwRuleArray[1]
                $FwAction = $FwRuleArray[2]
                $FwProtocol = $FwRuleArray[3]
                $FwLocalPort = @($FwRuleArray[4]).Split(",")
                $FwProgram = $FwRuleArray[5]

                # Check if rule already exists
                try {

                    $ResultOutput = Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $FwDisplayName 2> $null
                    $Result = $ResultOutput.Enabled

                } catch {
                    $Result = $Finding.DefaultValue
                }

                # Go on if rule not exists
                If (-Not $Result) {

                    If ($FwProgram -eq "") {

                        $ResultRule = New-NetFirewallRule -DisplayName $FwDisplayName -Profile $FwProfile -Direction $FwDirection -Action $FwAction -Protocol $FwProtocol -LocalPort $FwLocalPort
                    } Else {
                        $ResultRule = New-NetFirewallRule -DisplayName $FwDisplayName -Profile $FwProfile -Direction $FwDirection -Action $FwAction -Program "$FwProgram"
                    }

                    If ($ResultRule.PrimaryStatus -eq "OK") {

                        # Excellent
                        $ResultText = "Rule created"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                        $MessageSeverity = "Passed"
                        $TestResult = "Passed"
                    } Else {
                        # Bogus
                        $ResultText = "Rule not created"
                        $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                        $MessageSeverity = "High"
                        $TestResult = "Failed"
                    }
                } Else {
                    # Excellent
                    $ResultText = "Rule already exists"
                    $Message = "ID " + $Finding.ID + ", " + $Finding.Name + ", " + $ResultText
                    $MessageSeverity = "Passed"
                    $TestResult = "Passed"
                }

                Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity

                If ($Log) {
                    Add-MessageToFile -Text $Message -File $LogFile
                }

                If ($Report) {
                    $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                    Add-MessageToFile -Text $Message -File $ReportFile
                }
            }
        }

        #
        # After all items of the checklist have been run through, the process mitigation settings can now be set...
        #
        If ( $ProcessmitigationEnableArray.Count -gt 0 -and $ProcessmitigationDisableArray.Count -gt 0) {

            $ResultText = "Process mitigation settings set"
            $MessageSeverity = "Passed"
            $TestResult = "Passed"

            try {
                $Result = Set-ProcessMitigation -System -Enable $ProcessmitigationEnableArray -Disable $ProcessmitigationDisableArray
            } catch {
                $ResultText = "Failed to set process mitigation settings"
                $MessageSeverity = "High"
                $TestResult = "Failed"
            }

            $Message = "Starting Category Microsoft Defender Exploit Guard"
            Write-Output "`n"
            Write-ProtocolEntry -Text $Message -LogLevel "Info"

            $Message = $ResultText
            Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
            If ($Log) {
                Add-MessageToFile -Text $Message -File $LogFile
            }
            If ($Report) {
                $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                Add-MessageToFile -Text $Message -File $ReportFile
            }
        } ElseIf ($ProcessmitigationEnableArray.Count -gt 0 -and $ProcessmitigationDisableArray.Count -eq 0) {
            $ResultText = "Process mitigation settings set"
            $MessageSeverity = "Passed"
            $TestResult = "Passed"

            try {
                $Result = Set-ProcessMitigation -System -Enable $ProcessmitigationEnableArray
            } catch {
                $ResultText = "Failed to set process mitigation settings"
                $MessageSeverity = "High"
                $TestResult = "Failed"
            }

            $Message = "Starting Category Microsoft Defender Exploit Guard"
            Write-Output "`n"
            Write-ProtocolEntry -Text $Message -LogLevel "Info"

            $Message = $ResultText
            Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
            If ($Log) {
                Add-MessageToFile -Text $Message -File $LogFile
            }
            If ($Report) {
                $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                Add-MessageToFile -Text $Message -File $ReportFile
            }
        } ElseIf ($ProcessmitigationEnableArray.Count -eq 0 -and $ProcessmitigationDisableArray.Count -gt 0) {
            $ResultText = "Process mitigation settings set"
            $MessageSeverity = "Passed"
            $TestResult = "Passed"

            try {
                $Result = Set-ProcessMitigation -System -Disable $ProcessmitigationDisableArray
            } catch {
                $ResultText = "Failed to set process mitigation settings"
                $MessageSeverity = "High"
                $TestResult = "Failed"
            }

            $Message = "Starting Category Microsoft Defender Exploit Guard"
            Write-Output "`n"
            Write-ProtocolEntry -Text $Message -LogLevel "Info"

            $Message = $ResultText
            Write-ResultEntry -Text $Message -SeverityLevel $MessageSeverity
            If ($Log) {
                Add-MessageToFile -Text $Message -File $LogFile
            }
            If ($Report) {
                $Message = '"' + $Finding.ID + '","' + $Finding.Name + '","' + $MessageSeverity + '","' + $ResultText + '",,"' + $TestResult + '",'
                Add-MessageToFile -Text $Message -File $ReportFile
            }
        }
    }

    Write-Output "`n"
    Write-ProtocolEntry -Text "HardeningKitty is done" -LogLevel "Info"

    If ($Mode -eq "Audit") {

        # HardeningKitty Score
        $StatsTotal = $StatsPassed + $StatsLow + $StatsMedium + $StatsHigh
        $ScoreTotal = $StatsTotal * 4
        $ScoreAchived = $StatsPassed * 4 + $StatsLow * 2 + $StatsMedium
        If ($ScoreTotal -ne 0 ) {
            $HardeningKittyScore = ([int] $ScoreAchived / [int] $ScoreTotal) * 5 + 1
        }
        $HardeningKittyScoreRounded = [math]::round($HardeningKittyScore, 2)

        # Overwrite HardeningKitty Score if no finding is passed
        If ($StatsPassed -eq 0 ) {
            $HardeningKittyScoreRounded = 1.00
        }

        If ($Script:StatsError -gt 0) {
            Write-ProtocolEntry -Text "During the execution of HardeningKitty errors occurred due to missing admin rights or tools. For a complete result, these errors should be resolved. Total errors: $Script:StatsError" -LogLevel "Error"
        }

        Write-ProtocolEntry -Text "Your HardeningKitty score is: $HardeningKittyScoreRounded. HardeningKitty Statistics: Total checks: $StatsTotal - Passed: $StatsPassed, Low: $StatsLow, Medium: $StatsMedium, High: $StatsHigh." -LogLevel "Info"
    }
    Write-Output "`n"
}

# SIG # Begin signature block
# MIIgIgYJKoZIhvcNAQcCoIIgEzCCIA8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUj8G/FpvpEYGAVC8JUvlKOoIa
# ZQygghn0MIIF4DCCBMigAwIBAgIQeO1YDfU4t32dWmgwBkYSEDANBgkqhkiG9w0B
# AQsFADCBkTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQx
# NzA1BgNVBAMTLkNPTU9ETyBSU0EgRXh0ZW5kZWQgVmFsaWRhdGlvbiBDb2RlIFNp
# Z25pbmcgQ0EwHhcNMjAwODA3MDAwMDAwWhcNMjMwODA3MjM1OTU5WjCBzzEYMBYG
# A1UEBRMPQ0hFLTEwOS44MDQuMzgyMRMwEQYLKwYBBAGCNzwCAQMTAkNIMR0wGwYD
# VQQPExRQcml2YXRlIE9yZ2FuaXphdGlvbjELMAkGA1UEBhMCQ0gxDTALBgNVBBEM
# BDgwNDgxEDAOBgNVBAgMB1rDvHJpY2gxEDAOBgNVBAcMB1rDvHJpY2gxGzAZBgNV
# BAkMEkJhZGVuZXJzdHJhc3NlIDYyMzEQMA4GA1UECgwHU2NpcCBBRzEQMA4GA1UE
# AwwHU2NpcCBBRzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAIvjKOZT
# ryv6pmIKN6ep8UVCcm+a5wTAt27yUUh4JyZhQjhMRk1SJZy5lLXimBQhmNlWAOWL
# yz5Gyecx3wBbaRYKQHIVH0LDBLDL2WU803JfTUi7TbsZCatq57oI/TAVoDClragI
# 0aPK/kbhREN1UN/mBKY3MLQmtJONeQawsEhLI1kwU+xmcllWu/VvO9Ld/K7rEvBi
# Pl+MR2vjc/Ns0h/gAizGxo6BlzD22XwyQWxPL8NTpTWSX+ZKrgh3AT+5iN/Q3mRV
# ewNR06W7TaKknwI8+wNrz2h/wNDAAO5BZmJ9aMvbJiJMF6IRx8907SoC2W+an0sX
# apQ12yFH6lCOm0MCAwEAAaOCAfIwggHuMB8GA1UdIwQYMBaAFN+P8yAM6cqmBNhb
# WDcqPatG3INJMB0GA1UdDgQWBBTRzSa1SEaHkraxCoNENvT8MuEWHTAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzARBglg
# hkgBhvhCAQEEBAMCBBAwSQYDVR0gBEIwQDA1BgwrBgEEAbIxAQIBBgEwJTAjBggr
# BgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwBwYFZ4EMAQMwVQYDVR0f
# BE4wTDBKoEigRoZEaHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09NT0RPUlNBRXh0
# ZW5kZWRWYWxpZGF0aW9uQ29kZVNpZ25pbmdDQS5jcmwwgYYGCCsGAQUFBwEBBHow
# eDBQBggrBgEFBQcwAoZEaHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09NT0RPUlNB
# RXh0ZW5kZWRWYWxpZGF0aW9uQ29kZVNpZ25pbmdDQS5jcnQwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTA7BgNVHREENDAyoCIGCCsGAQUFBwgD
# oBYwFAwSQ0gtQ0hFLTEwOS44MDQuMzgygQxpbmZvQHNjaXAuY2gwDQYJKoZIhvcN
# AQELBQADggEBACT7DLCxFVqNzRaCA/6PeNy1jJrCiCLLJsRM9Da7pkp7IJsVeKTC
# 4pF3YaiWf9/ZFwuBKorzoXZwH+P2EHi4fqjOlwBOxonnM6JxuMts5llladNiacoB
# dTiYe7xrkM/31vRauAuIj8zBNiNqfllmA3UJMHDObix9OAIbtDjZPli0IpAPDKKb
# pPTgoTjgyc33dVtF7rMZMPok/2iHsXJVzKBuYfwktZXTIQVKvHuwkG4+Vdw40/c9
# eBpPRpDvjrtXjoVcDy5eEYo4j2rxSkmfvOgLcoLBtjuqWw44+AAdfoCgNa2kfJ1j
# Xb7NDzGQS1hgiUuTOiTYtvKbUOuJoFXxDW8wggYiMIIECqADAgECAhBt1HLrAq4E
# BuPdhD9f4UXhMA0GCSqGSIb3DQEBDAUAMIGFMQswCQYDVQQGEwJHQjEbMBkGA1UE
# CBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQK
# ExFDT01PRE8gQ0EgTGltaXRlZDErMCkGA1UEAxMiQ09NT0RPIFJTQSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTAeFw0xNDEyMDMwMDAwMDBaFw0yOTEyMDIyMzU5NTla
# MIGRMQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAw
# DgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDE3MDUG
# A1UEAxMuQ09NT0RPIFJTQSBFeHRlbmRlZCBWYWxpZGF0aW9uIENvZGUgU2lnbmlu
# ZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAIr9vUPwPchVH/NZ
# ivBatNyT0WQVSoqEpS3LJvjgRTijuQHFTxMIWdAxVMrNkGGjPizyTRVc1O7DaiKX
# SNEGQzQJmcnPMMSfRP1WnO7M54O5gc3I2gscEkj/b6LsxHXLCXDPUeW7i5+qvXgG
# fZXWYYH22lPHrJ2zALoe1L5AYgmZgz1F3U1llQTM/PrHW3riLgw9VTVXNUiJifK5
# VqVLUBsc3piQvfMu3Iip8XWbqD6iBdlBte93rRfAWvWj202f0cSxe4O17hCUKy5y
# rr7vlSmcUmLFLG0i931EehBfY5NpTdl9spqxTrVZv/+F+72s7OErpuMsLOjZbttf
# TRd4y1MCAwEAAaOCAX4wggF6MB8GA1UdIwQYMBaAFLuvfgI9+qbxPISOre44mOzZ
# MjLUMB0GA1UdDgQWBBTfj/MgDOnKpgTYW1g3Kj2rRtyDSTAOBgNVHQ8BAf8EBAMC
# AYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzA+BgNV
# HSAENzA1MDMGBFUdIAAwKzApBggrBgEFBQcCARYdaHR0cHM6Ly9zZWN1cmUuY29t
# b2RvLmNvbS9DUFMwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybC5jb21vZG9j
# YS5jb20vQ09NT0RPUlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwcQYIKwYB
# BQUHAQEEZTBjMDsGCCsGAQUFBzAChi9odHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9D
# T01PRE9SU0FBZGRUcnVzdENBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au
# Y29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBmTuy3FndvEegbXWpO2fKL
# bLFWKECLwDHEmUgjPfgO6ICX720gCx8TxIb7FzQV4Y5U98K4AHMV4CjZ2rr6glTC
# 9+u/wzbQMJ/loRyU3+986PYseKKszyZqFaEVMdYxNJi9U0/EhIOjxJZcPdj+1vlU
# /2eTbfg+K2ssogh8VkiBMhiybqyQwdvk3jmLhuXHGEBZpN+WR7qyf7H4Vw+FgHQ4
# DjpYYh7+UuPmrlMJhv6Pm9tWVswHsInBBPFTC2xvd+yyH+z2W0BDYA8bqxhUtBAE
# jvgO6cuDsXryNE5qVEzpgyrpsDAlHM5ijg7rheYp/rFK4/KuPJH1TKG+yBcOXLtC
# TeMaipLNPiB+3el1seofdFyeVMKUN7Jh3QcWWX+WgBbgmbXSbrDJIwYVrNEj9DOL
# znXwwYbT/+Eu+pBP/kb5u9tPu7f+0Q0rBPHS0ZWFLIouuIVW8sOEUqHpM7HrUMih
# sJ/jw4s6h57nVdPTbTQXMA1oIgvVue1zNXLD7ac3zeNDrkXNNL8oyodi7UOkr/rL
# McshWGFGXrbGeqYeUyqo+FxRHzpaEA8owOR0i3TGBKr4SyYoCjKJ250qYHFqw5ZO
# Frljv2GVZ4xLLruwToPpTTHljici9Twme0SR09Ra8NN89Di+FJqZDouxW+rkiw8R
# nXdCghxcOtTaq4gvjVcwVDCCBuwwggTUoAMCAQICEDAPb6zdZph0fKlGNqd4Lbkw
# DQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVy
# c2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVT
# VCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24g
# QXV0aG9yaXR5MB4XDTE5MDUwMjAwMDAwMFoXDTM4MDExODIzNTk1OVowfTELMAkG
# A1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMH
# U2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0
# aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAyBsBr9ksfoiZfQGYPyCQvZyAIVSTuc+gPlPvs1rAdtYaBKXOR4O1
# 68TMSTTL80VlufmnZBYmCfvVMlJ5LsljwhObtoY/AQWSZm8hq9VxEHmH9EYqzcRa
# ydvXXUlNclYP3MnjU5g6Kh78zlhJ07/zObu5pCNCrNAVw3+eolzXOPEWsnDTo8Tf
# s8VyrC4Kd/wNlFK3/B+VcyQ9ASi8Dw1Ps5EBjm6dJ3VV0Rc7NCF7lwGUr3+Az9ER
# CleEyX9W4L1GnIK+lJ2/tCCwYH64TfUNP9vQ6oWMilZx0S2UTMiMPNMUopy9Jv/T
# UyDHYGmbWApU9AXn/TGs+ciFF8e4KRmkKS9G493bkV+fPzY+DjBnK0a3Na+WvtpM
# YMyou58NFNQYxDCYdIIhz2JWtSFzEh79qsoIWId3pBXrGVX/0DlULSbuRRo6b83X
# hPDX8CjFT2SDAtT74t7xvAIo9G3aJ4oG0paH3uhrDvBbfel2aZMgHEqXLHcZK5OV
# mJyXnuuOwXhWxkQl3wYSmgYtnwNe/YOiU2fKsfqNoWTJiJJZy6hGwMnypv99V9sS
# dvqKQSTUG/xypRSi1K1DHKRJi0E5FAMeKfobpSKupcNNgtCN2mu32/cYQFdz8HGj
# +0p9RTbB942C+rnJDVOAffq2OVgy728YUInXT50zvRq1naHelUF6p4MCAwEAAaOC
# AVowggFWMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQW
# BBQaofhhGSAPw0F3RSiO0TVfBhIEVTAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/
# BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUd
# IAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VT
# RVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEB
# BGowaDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51
# c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBtVIGlM10W4bVTgZF13wN6
# MgstJYQRsrDbKn0qBfW8Oyf0WqC5SVmQKWxhy7VQ2+J9+Z8A70DDrdPi5Fb5WEHP
# 8ULlEH3/sHQfj8ZcCfkzXuqgHCZYXPO0EQ/V1cPivNVYeL9IduFEZ22PsEMQD43k
# +ThivxMBxYWjTMXMslMwlaTW9JZWCLjNXH8Blr5yUmo7Qjd8Fng5k5OUm7Hcsm1B
# bWfNyW+QPX9FcsEbI9bCVYRm5LPFZgb289ZLXq2jK0KKIZL+qG9aJXBigXNjXqC7
# 2NzXStM9r4MGOBIdJIct5PwC1j53BLwENrXnd8ucLo0jGLmjwkcd8F3WoXNXBWia
# p8k3ZR2+6rzYQoNDBaWLpgn/0aGUpk6qPQn1BWy30mRa2Coiwkud8TleTN5IPZs0
# lpoJX47997FSkc4/ifYcobWpdR9xv1tDXWU9UIFuq/DQ0/yysx+2mZYm9Dx5i1xk
# zM3uJ5rloMAMcofBbk1a0x7q8ETmMm8c6xdOlMN4ZSA7D0GqH+mhQZ3+sbigZSo0
# 4N6o+TzmwTC7wKBjLPxcFgCo0MR/6hGdHgbGpm0yXbQ4CStJB6r97DDa8acvz7f9
# +tCjhNknnvsBZne5VhDhIG7GrrH5trrINV0zdo7xfCAMKneutaIChrop7rRaALGM
# q+P5CslUXdS5anSevUiumDCCBvYwggTeoAMCAQICEQCQOX+a0ko6E/K9kV8IOKlD
# MA0GCSqGSIb3DQEBDAUAMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVy
# IE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28g
# TGltaXRlZDElMCMGA1UEAxMcU2VjdGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQTAe
# Fw0yMjA1MTEwMDAwMDBaFw0zMzA4MTAyMzU5NTlaMGoxCzAJBgNVBAYTAkdCMRMw
# EQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAq
# BgNVBAMMI1NlY3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgU2lnbmVyICMzMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAkLJxP3nh1LmKF8zDl8KQlHLtWjpv
# AUN/c1oonyR8oDVABvqUrwqhg7YT5EsVBl5qiiA0cXu7Ja0/WwqkHy9sfS5hUdCM
# WTc+pl3xHl2AttgfYOPNEmqIH8b+GMuTQ1Z6x84D1gBkKFYisUsZ0vCWyUQfOV2c
# sJbtWkmNfnLkQ2t/yaA/bEqt1QBPvQq4g8W9mCwHdgFwRd7D8EJp6v8mzANEHxYo
# 4Wp0tpxF+rY6zpTRH72MZar9/MM86A2cOGbV/H0em1mMkVpCV1VQFg1LdHLuoCox
# /CYCNPlkG1n94zrU6LhBKXQBPw3gE3crETz7Pc3Q5+GXW1X3KgNt1c1i2s6cHvzq
# cH3mfUtozlopYdOgXCWzpSdoo1j99S1ryl9kx2soDNqseEHeku8Pxeyr3y1vGlRR
# bDOzjVlg59/oFyKjeUFiz/x785LaruA8Tw9azG7fH7wir7c4EJo0pwv//h1epPPu
# FjgrP6x2lEGdZB36gP0A4f74OtTDXrtpTXKZ5fEyLVH6Ya1N6iaObfypSJg+8kYN
# abG3bvQF20EFxhjAUOT4rf6sY2FHkbxGtUZTbMX04YYnk4Q5bHXgHQx6WYsuy/Rk
# LEJH9FRYhTflx2mn0iWLlr/GreC9sTf3H99Ce6rrHOnrPVrd+NKQ1UmaOh2DGld/
# HAHCzhx9zPuWFcUCAwEAAaOCAYIwggF+MB8GA1UdIwQYMBaAFBqh+GEZIA/DQXdF
# KI7RNV8GEgRVMB0GA1UdDgQWBBQlLmg8a5orJBSpH6LfJjrPFKbx4DAOBgNVHQ8B
# Af8EBAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBK
# BgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczov
# L3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAIwRAYDVR0fBD0wOzA5oDegNYYzaHR0
# cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUlNBVGltZVN0YW1waW5nQ0EuY3Js
# MHQGCCsGAQUFBwEBBGgwZjA/BggrBgEFBQcwAoYzaHR0cDovL2NydC5zZWN0aWdv
# LmNvbS9TZWN0aWdvUlNBVGltZVN0YW1waW5nQ0EuY3J0MCMGCCsGAQUFBzABhhdo
# dHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAc9rtaHLL
# wrlAoTG7tAOjLRR7JOe0WxV9qOn9rdGSDXw9NqBp2fOaMNqsadZ0VyQ/fg882fXD
# eSVsJuiNaJPO8XeJOX+oBAXaNMMU6p8IVKv/xH6WbCvTlOu0bOBFTSyy9zs7WrXB
# +9eJdW2YcnL29wco89Oy0OsZvhUseO/NRaAA5PgEdrtXxZC+d1SQdJ4LT03EqhOP
# l68BNSvLmxF46fL5iQQ8TuOCEmLrtEQMdUHCDzS4iJ3IIvETatsYL254rcQFtOiE
# CJMH+X2D/miYNOR35bHOjJRs2wNtKAVHfpsu8GT726QDMRB8Gvs8GYDRC3C5VV9H
# vjlkzrfaI1Qy40ayMtjSKYbJFV2Ala8C+7TRLp04fDXgDxztG0dInCJqVYLZ8roI
# ZQPl8SnzSIoJAUymefKithqZlOuXKOG+fRuhfO1WgKb0IjOQ5IRT/Cr6wKeXqOq1
# jXrO5OBLoTOrC3ag1WkWt45mv1/6H8Sof6ehSBSRDYL8vU2Z7cnmbDb+d0OZuGkt
# fGEv7aOwSf5bvmkkkf+T/FdpkkvZBT9thnLTotDAZNI6QsEaA/vQ7ZohuD+vprJR
# VNVMxcofEo1XxjntXP/snyZ2rWRmZ+iqMODSrbd9sWpBJ24DiqN04IoJgm6/4/a3
# vJ4LKRhogaGcP24WWUsUCQma5q6/YBXdhvUxggWYMIIFlAIBATCBpjCBkTELMAkG
# A1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMH
# U2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxNzA1BgNVBAMTLkNP
# TU9ETyBSU0EgRXh0ZW5kZWQgVmFsaWRhdGlvbiBDb2RlIFNpZ25pbmcgQ0ECEHjt
# WA31OLd9nVpoMAZGEhAwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKA
# AKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFH0PnhwfakDEsZAD7N4w8zpW
# zpalMA0GCSqGSIb3DQEBAQUABIIBAFf/MXcHYElXShM/Y78RQK9VLHM4FVFMN0sE
# 9vbrU1qEEBCPlYL5wvq5A7dYFSquzZ0B7Vl4BA8q4D6E77NsaD30v21CZlAZT9xw
# 0xpgEeavEBr3/Og1j+1/kP50LsEjfMo9eKSrwN8TWR3ml/m7BRS2M+XrwJVWNOYh
# qRCclFmRpgCxP3pVz7e5GIFXpk1YgTSdqLiPWO7g/n4lI8lC6+JxL0Jg3RTnIk/q
# 6cHGq0ZctDNWfoT5lBi2G5HAjsexv9lBKb4CNjjWI37rm5MqNW7rNGl0QUu39vDt
# ZQ/rl5ECA7MX1xXniLUDj2v54Za9JDD6WXa/67ga5O3/EzPkq/qhggNMMIIDSAYJ
# KoZIhvcNAQkGMYIDOTCCAzUCAQEwgZIwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
# EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0aWdvIFJTQSBUaW1lIFN0YW1w
# aW5nIENBAhEAkDl/mtJKOhPyvZFfCDipQzANBglghkgBZQMEAgIFAKB5MBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIyMDgzMTA1MTE0
# N1owPwYJKoZIhvcNAQkEMTIEMB5zlCu07ibMxSz5RLRuMt5abDCmf8BafavXyJVy
# QklxZx5xXTuJa7mlwN0+ZpR0cTANBgkqhkiG9w0BAQEFAASCAgAChDNq5KDqR0SA
# ZtY2FzbdvMVa1lz9V3afkIJ1Cr4qHuUn1UI91zbns1McJL9cf4DRv2WOlaaUzWrS
# SPFlC5qT9sK20BOgRDcyDpPKAJaFrbSERiByh8Nm1niGgJHhibBbMQUIRt1bltTf
# MC90KvZwvtFQ557Oydcz8sbCV0xUSd5VxFfysyYIOQRZ4yeI4nJX1Txbv8KUr+oz
# 4L59YLg+ZSmfP5pu1IT48QGeOscOAJaVlxQX5B9aCYEnXgRjuhxCEWG1rygSRsqz
# P2sviMRtc+irWxYSA4KK5E0ba8DNi7ANhJtEJ4EFdOoVw2cf+pAqMbNhv1Hqug9q
# k6xum1b7yi23hfIz67xCF/1EueNCc4x6zBKAMsEb0SbcSvMHGGA1lTw37JRsGbmS
# pz2DQFZ7X/cwUvdQMn947/8QqDbhQLzRmx7USHyYk4UxKl10tGyHZeanQ2rzBtxj
# 4jp9oC6/m7nd9NLHvtZVLDmShSS5DcFqtwBg1euNCPE2bqlgSiBTfj49qseCdvuh
# TzSY8WfIYPIqis6e3/deIoPKd8dlpXPWxPAnQa33TxHv2VWa/1951ITTHxi/08n4
# +W6uvj8wWt7bd2Gb/saFi9qqF6odQ8p6hsgi/dIxW8pdeQkTOUNI6pYKrWt972WK
# wBC8hjyZ7IQJdHf2JBqkG8dWWKtCWQ==
# SIG # End signature block
