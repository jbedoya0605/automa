#requires -version 2.0
# ================================================================
#                     SERVER AUDIT
#                         VERSION 1.1
# ================================================================
#
# Auditoria de servidores Windows
#
# - Sistema operativo
# - CPU / RAM
# - Red
# - Discos
# - Servicios
# - Eventos de seguridad
# - SQL Server
# - Bases de datos
# - MDF / NDF / LDF
# - Snapshots JSON
# - Comparacion de cambios
#
# Todo en un solo archivo.
#
# ================================================================
$ErrorActionPreference = "SilentlyContinue"
# ================================================================
# CONFIGURACION
# ================================================================
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataRoot = Join-Path $ScriptRoot "Data"
$LogRoot  = Join-Path $ScriptRoot "Logs"
$ServerName = $env:COMPUTERNAME
$ServerDataRoot = Join-Path $DataRoot $ServerName
foreach ($Folder in @($DataRoot, $LogRoot, $ServerDataRoot)) {
    if (-not (Test-Path $Folder)) {
        New-Item `
            -Path $Folder `
            -ItemType Directory `
            -Force | Out-Null
    }
}
$LatestFile   = Join-Path $ServerDataRoot "latest.json"
$PreviousFile = Join-Path $ServerDataRoot "previous.json"
# ================================================================
# COLORES
# ================================================================
$Cyan    = "Cyan"
$Green   = "Green"
$Yellow  = "Yellow"
$Red     = "Red"
$White   = "White"
$Gray    = "DarkGray"
$Blue    = "Blue"
$Magenta = "Magenta"
# ================================================================
# FUNCIONES DE INTERFAZ
# ================================================================
function Write-Centered {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    $Width = 66
    if ($Text.Length -gt $Width) {
        $Text = $Text.Substring(0, $Width)
    }
    $Left = [math]::Max(
        0,
        [math]::Floor(($Width - $Text.Length) / 2)
    )
    Write-Host (
        (" " * [int]$Left) + $Text
    ) -ForegroundColor $Color
}
function Write-Line {
    param(
        [string]$Character = "-"
    )
    Write-Host (
        ("  " + ($Character * 62))
    ) -ForegroundColor $Gray
}
function Write-Header {
    param(
        [string]$Title
    )
    Clear-Host
    Write-Host ""
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host "  |" -NoNewline -ForegroundColor $Cyan
    Write-Centered $Title $White
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host ""
}
function Write-Status {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Status = "OK"
    )
    switch ($Status) {
        "OK" {
            $Symbol = "[OK]"
            $Color = $Green
        }
        "WARNING" {
            $Symbol = "[!!]"
            $Color = $Yellow
        }
        "CRITICAL" {
            $Symbol = "[!!]"
            $Color = $Red
        }
        "INFO" {
            $Symbol = "[--]"
            $Color = $Cyan
        }
        default {
            $Symbol = "[--]"
            $Color = $White
        }
    }
    Write-Host "  $Symbol " -NoNewline -ForegroundColor $Color
    Write-Host ("{0,-32}" -f $Label) -NoNewline -ForegroundColor $White
    Write-Host $Value -ForegroundColor $Gray
}
function Write-ProgressBar {
    param(
        [int]$Percent,
        [string]$Text = ""
    )
    if ($Percent -lt 0) {
        $Percent = 0
    }
    if ($Percent -gt 100) {
        $Percent = 100
    }
    $Width = 40
    $Filled =
        [math]::Floor(
            ($Percent / 100) * $Width
        )
    $Empty =
        $Width - $Filled
    $Bar =
        ("#" * $Filled) +
        ("-" * $Empty)
    Write-Host ""
    Write-Host "  $Text"
    Write-Host ""
    Write-Host "  [$Bar] $Percent%" -ForegroundColor $Cyan
}
function Write-MenuItem {
    param(
        [string]$Number,
        [string]$Text,
        [string]$Description = ""
    )
    Write-Host "  [$Number] " -NoNewline -ForegroundColor $Cyan
    Write-Host ("{0,-30}" -f $Text) -NoNewline -ForegroundColor $White
    if ($Description) {
        Write-Host $Description -ForegroundColor $Gray
    }
}
function Write-Log {
    param(
        [string]$Message
    )
    $LogFile =
        Join-Path $LogRoot "ServerAudit.log"
    $Line = "{0} - {1}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Message
    Add-Content `
        -Path $LogFile `
        -Value $Line
}
function Write-Section {
    param(
        [string]$Title
    )
    Write-Host ""
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host "  | " -NoNewline -ForegroundColor $Cyan
    Write-Host $Title -ForegroundColor $White
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host ""
}
# ================================================================
# INFORMACION DEL SISTEMA
# ================================================================
function Get-SystemInformation {
    try {
        $OS =
            Get-CimInstance Win32_OperatingSystem
        $Computer =
            Get-CimInstance Win32_ComputerSystem
        $CPU =
            Get-CimInstance Win32_Processor |
            Select-Object -First 1
        $BIOS =
            Get-CimInstance Win32_BIOS
        $MemoryTotalGB =
            [math]::Round(
                $Computer.TotalPhysicalMemory / 1GB,
                2
            )
        $MemoryFreeGB =
            [math]::Round(
                $OS.FreePhysicalMemory / 1MB,
                2
            )
        $MemoryUsedGB =
            $MemoryTotalGB - $MemoryFreeGB
        if ($MemoryTotalGB -gt 0) {
            $MemoryUsedPercent =
                [math]::Round(
                    ($MemoryUsedGB / $MemoryTotalGB) * 100,
                    2
                )
        }
        else {
            $MemoryUsedPercent = 0
        }
        return [PSCustomObject]@{
            ComputerName =
                $env:COMPUTERNAME
            Domain =
                $Computer.Domain
            Manufacturer =
                $Computer.Manufacturer
            Model =
                $Computer.Model
            SerialNumber =
                $BIOS.SerialNumber
            OperatingSystem =
                $OS.Caption
            OSVersion =
                $OS.Version
            BuildNumber =
                $OS.BuildNumber
            Architecture =
                $OS.OSArchitecture
            LastBoot =
                $OS.LastBootUpTime
            CPUName =
                $CPU.Name
            CPUCores =
                $CPU.NumberOfCores
            LogicalProcessors =
                $CPU.NumberOfLogicalProcessors
            CPUCurrentClockMHz =
                $CPU.CurrentClockSpeed
            MemoryTotalGB =
                $MemoryTotalGB
            MemoryUsedGB =
                [math]::Round(
                    $MemoryUsedGB,
                    2
                )
            MemoryFreeGB =
                [math]::Round(
                    $MemoryFreeGB,
                    2
                )
            MemoryUsedPercent =
                $MemoryUsedPercent
        }
    }
    catch {
        return [PSCustomObject]@{
            Status = "ERROR"
            Error = $_.Exception.Message
        }
    }
}
# ================================================================
# RED
# ================================================================
function Get-NetworkInformation {
    try {
        $Adapters = @()
        $NetworkAdapters =
            Get-CimInstance `
                Win32_NetworkAdapterConfiguration `
                -Filter "IPEnabled=True"
        foreach ($Adapter in $NetworkAdapters) {
            $Adapters += [PSCustomObject]@{
                Description =
                    $Adapter.Description
                MACAddress =
                    $Adapter.MACAddress
                IPAddress =
                    ($Adapter.IPAddress -join ", ")
                SubnetMask =
                    ($Adapter.IPSubnet -join ", ")
                Gateway =
                    ($Adapter.DefaultIPGateway -join ", ")
                DNS =
                    ($Adapter.DNSServerSearchOrder -join ", ")
            }
        }
        return $Adapters
    }
    catch {
        return @()
    }
}
# ================================================================
# DISCOS
# ================================================================
function Get-DiskInformation {
    try {
        $Disks = @()
        $LogicalDisks =
            Get-CimInstance Win32_LogicalDisk `
                -Filter "DriveType=3"
        foreach ($Disk in $LogicalDisks) {
            if ($Disk.Size -gt 0) {
                $SizeGB =
                    [math]::Round(
                        $Disk.Size / 1GB,
                        2
                    )
                $FreeGB =
                    [math]::Round(
                        $Disk.FreeSpace / 1GB,
                        2
                    )
                $UsedGB =
                    $SizeGB - $FreeGB
                $UsedPercent =
                    [math]::Round(
                        ($UsedGB / $SizeGB) * 100,
                        2
                    )
                $Status = "OK"
                if ($UsedPercent -ge 90) {
                    $Status = "CRITICAL"
                }
                elseif ($UsedPercent -ge 80) {
                    $Status = "WARNING"
                }
                $Disks += [PSCustomObject]@{
                    Drive =
                        $Disk.DeviceID
                    VolumeName =
                        $Disk.VolumeName
                    FileSystem =
                        $Disk.FileSystem
                    SizeGB =
                        $SizeGB
                    UsedGB =
                        [math]::Round(
                            $UsedGB,
                            2
                        )
                    FreeGB =
                        $FreeGB
                    UsedPercent =
                        $UsedPercent
                    Status =
                        $Status
                }
            }
        }
        return $Disks
    }
    catch {
        return @()
    }
}
# ================================================================
# SERVICIOS
# ================================================================
function Get-ServiceInformation {
    try {
        $Services = @()
        $AllServices =
            Get-CimInstance Win32_Service
        foreach ($Service in $AllServices) {
            $Services += [PSCustomObject]@{
                Name =
                    $Service.Name
                DisplayName =
                    $Service.DisplayName
                State =
                    $Service.State
                StartMode =
                    $Service.StartMode
                StartName =
                    $Service.StartName
                PathName =
                    $Service.PathName
            }
        }
        return $Services
    }
    catch {
        return @()
    }
}
# ================================================================
# SEGURIDAD
# ================================================================
function Get-SecurityInformation {
    $StartTime =
        (Get-Date).AddHours(-24)
    $EventIds = @(
        4624,
        4625,
        4634,
        4647,
        4672,
        4720,
        4722,
        4726,
        4732,
        4740
    )
    try {
        $Events = @()
        $RawEvents =
            Get-WinEvent `
                -FilterHashtable @{
                    LogName = "Security"
                    StartTime = $StartTime
                    Id = $EventIds
                }
        foreach ($Event in $RawEvents) {
            $Events += [PSCustomObject]@{
                EventID =
                    $Event.Id
                TimeCreated =
                    $Event.TimeCreated
                ProviderName =
                    $Event.ProviderName
                MachineName =
                    $Event.MachineName
                Message =
                    $Event.Message
            }
        }
        $Summary = @()
        foreach ($ID in $EventIds) {
            $Count =
                @(
                    $Events |
                    Where-Object {
                        $_.EventID -eq $ID
                    }
                ).Count
            $Summary += [PSCustomObject]@{
                EventID = $ID
                Count = $Count
            }
        }
        return [PSCustomObject]@{
            Status = "OK"
            PeriodStart =
                $StartTime
            PeriodEnd =
                Get-Date
            TotalEvents =
                $Events.Count
            Summary =
                $Summary
            Events =
                $Events
        }
    }
    catch {
        return [PSCustomObject]@{
            Status = "ERROR"
            PeriodStart =
                $StartTime
            PeriodEnd =
                Get-Date
            TotalEvents = 0
            Summary = @()
            Events = @()
            Error =
                $_.Exception.Message
        }
    }
}
# ================================================================
# SQL SERVER
# ================================================================
function Get-SQLInformation {
    $SQLServices =
        Get-CimInstance Win32_Service |
        Where-Object {
            $_.Name -eq "MSSQLSERVER" -or
            $_.Name -like "MSSQL$*"
        }
    if (-not $SQLServices) {
        return [PSCustomObject]@{
            Installed = $false
            Instances = @()
        }
    }
    $Instances = @()
    foreach ($SQLService in $SQLServices) {
        if ($SQLService.Name -eq "MSSQLSERVER") {
            $InstanceName =
                "MSSQLSERVER"
            $ServerInstance =
                "."
        }
        else {
            $InstanceName =
                $SQLService.Name.Substring(6)
            $ServerInstance =
                ".\$InstanceName"
        }
        $Connection =
            New-Object System.Data.SqlClient.SqlConnection
        try {
            $Connection.ConnectionString =
                "Server=$ServerInstance;Integrated Security=True;Connection Timeout=5"
            $Connection.Open()
            # ----------------------------------------------------
            # BASES DE DATOS
            # ----------------------------------------------------
            $Command =
                $Connection.CreateCommand()
            $Command.CommandText = @"
SELECT
    d.name AS DatabaseName,
    d.state_desc AS State,
    d.recovery_model_desc AS RecoveryModel,
    d.create_date AS CreateDate,
    ISNULL(SUM(mf.size),0) * 8.0 / 1024 AS SizeMB
FROM sys.databases d
LEFT JOIN sys.master_files mf
    ON d.database_id = mf.database_id
GROUP BY
    d.name,
    d.state_desc,
    d.recovery_model_desc,
    d.create_date
ORDER BY
    d.name
"@
            $Reader =
                $Command.ExecuteReader()
            $Databases = @()
            while ($Reader.Read()) {
                $Databases +=
                    [PSCustomObject]@{
                        DatabaseName =
                            $Reader["DatabaseName"].ToString()
                        State =
                            $Reader["State"].ToString()
                        RecoveryModel =
                            $Reader["RecoveryModel"].ToString()
                        CreateDate =
                            $Reader["CreateDate"]
                        SizeMB =
                            [math]::Round(
                                [double]$Reader["SizeMB"],
                                2
                            )
                    }
            }
            $Reader.Close()
            # ----------------------------------------------------
            # ARCHIVOS
            # ----------------------------------------------------
            $CommandFiles =
                $Connection.CreateCommand()
            $CommandFiles.CommandText = @"
SELECT
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalName,
    physical_name AS PhysicalName,
    type_desc AS FileType,
    size * 8.0 / 1024 AS SizeMB,
    growth,
    is_percent_growth,
    max_size
FROM sys.master_files
ORDER BY
    database_id,
    file_id
"@
            $ReaderFiles =
                $CommandFiles.ExecuteReader()
            $Files = @()
            while ($ReaderFiles.Read()) {
                $Files +=
                    [PSCustomObject]@{
                        DatabaseName =
                            $ReaderFiles["DatabaseName"].ToString()
                        LogicalName =
                            $ReaderFiles["LogicalName"].ToString()
                        PhysicalName =
                            $ReaderFiles["PhysicalName"].ToString()
                        FileType =
                            $ReaderFiles["FileType"].ToString()
                        SizeMB =
                            [math]::Round(
                                [double]$ReaderFiles["SizeMB"],
                                2
                            )
                        Growth =
                            $ReaderFiles["growth"]
                        IsPercentGrowth =
                            $ReaderFiles["is_percent_growth"]
                        MaxSize =
                            $ReaderFiles["max_size"]
                    }
            }
            $ReaderFiles.Close()
            $Connection.Close()
            $Instances +=
                [PSCustomObject]@{
                    Instance =
                        $ServerInstance
                    ServiceName =
                        $SQLService.Name
                    ServiceState =
                        $SQLService.State
                    Status =
                        "Connected"
                    Databases =
                        $Databases
                    Files =
                        $Files
                }
        }
        catch {
            try {
                $Connection.Close()
            }
            catch {}
            $Instances +=
                [PSCustomObject]@{
                    Instance =
                        $ServerInstance
                    ServiceName =
                        $SQLService.Name
                    ServiceState =
                        $SQLService.State
                    Status =
                        "ConnectionError"
                    Error =
                        $_.Exception.Message
                    Databases =
                        @()
                    Files =
                        @()
                }
        }
    }
    return [PSCustomObject]@{
        Installed =
            $true
        Instances =
            $Instances
    }
}
# ================================================================
# COMPARACION
# ================================================================
function Compare-Audit {
    param(
        [string]$PreviousFile,
        [string]$CurrentFile
    )
    $Previous =
        Get-Content $PreviousFile -Raw |
        ConvertFrom-Json
    $Current =
        Get-Content $CurrentFile -Raw |
        ConvertFrom-Json
    $NewDatabases = @()
    $RemovedDatabases = @()
    $DatabaseSizeChanges = @()
    $NewServices = @()
    $RemovedServices = @()
    $ChangedServices = @()
    # ============================================================
    # BASES
    # ============================================================
    $PreviousDBs = @{}
    $CurrentDBs = @{}
    if (
        $Previous.SQL.Installed -eq $true -and
        $Current.SQL.Installed -eq $true
    ) {
        foreach ($Instance in $Previous.SQL.Instances) {
            foreach ($DB in $Instance.Databases) {
                $PreviousDBs[
                    $DB.DatabaseName
                ] =
                    [double]$DB.SizeMB
            }
        }
        foreach ($Instance in $Current.SQL.Instances) {
            foreach ($DB in $Instance.Databases) {
                $CurrentDBs[
                    $DB.DatabaseName
                ] =
                    [double]$DB.SizeMB
            }
        }
        foreach ($Database in $CurrentDBs.Keys) {
            if (
                -not $PreviousDBs.ContainsKey(
                    $Database
                )
            ) {
                $NewDatabases += $Database
            }
        }
        foreach ($Database in $PreviousDBs.Keys) {
            if (
                -not $CurrentDBs.ContainsKey(
                    $Database
                )
            ) {
                $RemovedDatabases += $Database
            }
        }
        foreach ($Database in $CurrentDBs.Keys) {
            if (
                $PreviousDBs.ContainsKey(
                    $Database
                )
            ) {
                $OldSize =
                    $PreviousDBs[$Database]
                $NewSize =
                    $CurrentDBs[$Database]
                $Difference =
                    $NewSize - $OldSize
                if (
                    [math]::Abs($Difference) -ge 100
                ) {
                    $DatabaseSizeChanges +=
                        [PSCustomObject]@{
                            Database =
                                $Database
                            PreviousMB =
                                [math]::Round(
                                    $OldSize,
                                    2
                                )
                            CurrentMB =
                                [math]::Round(
                                    $NewSize,
                                    2
                                )
                            DifferenceMB =
                                [math]::Round(
                                    $Difference,
                                    2
                                )
                        }
                }
            }
        }
    }
    # ============================================================
    # SERVICIOS
    # ============================================================
    $PreviousServices = @{}
    $CurrentServices = @{}
    foreach ($Service in $Previous.Services) {
        $PreviousServices[
            $Service.Name
        ] =
            $Service.State
    }
    foreach ($Service in $Current.Services) {
        $CurrentServices[
            $Service.Name
        ] =
            $Service.State
    }
    foreach ($Service in $CurrentServices.Keys) {
        if (
            -not $PreviousServices.ContainsKey(
                $Service
            )
        ) {
            $NewServices += $Service
        }
    }
    foreach ($Service in $PreviousServices.Keys) {
        if (
            -not $CurrentServices.ContainsKey(
                $Service
            )
        ) {
            $RemovedServices += $Service
        }
    }
    foreach ($Service in $CurrentServices.Keys) {
        if (
            $PreviousServices.ContainsKey(
                $Service
            )
        ) {
            if (
                $PreviousServices[$Service] -ne
                $CurrentServices[$Service]
            ) {
                $ChangedServices +=
                    [PSCustomObject]@{
                        Service =
                            $Service
                        PreviousState =
                            $PreviousServices[$Service]
                        CurrentState =
                            $CurrentServices[$Service]
                    }
            }
        }
    }
    # ============================================================
    # DISCOS
    # ============================================================
    $DiskAlerts = @()
    foreach ($Disk in $Current.Storage) {
        if ($Disk.Status -ne "OK") {
            $DiskAlerts +=
                [PSCustomObject]@{
                    Drive =
                        $Disk.Drive
                    UsedPercent =
                        $Disk.UsedPercent
                    Status =
                        $Disk.Status
                }
        }
    }
    return [PSCustomObject]@{
        NewDatabases =
            $NewDatabases
        RemovedDatabases =
            $RemovedDatabases
        DatabaseSizeChanges =
            $DatabaseSizeChanges
        NewServices =
            $NewServices
        RemovedServices =
            $RemovedServices
        ChangedServices =
            $ChangedServices
        DiskAlerts =
            $DiskAlerts
    }
}
# ================================================================
# MOSTRAR CAMBIOS
# ================================================================
function Show-Changes {
    param(
        $Changes
    )
    $TotalChanges = 0
    $TotalChanges +=
        $Changes.NewDatabases.Count
    $TotalChanges +=
        $Changes.RemovedDatabases.Count
    $TotalChanges +=
        $Changes.DatabaseSizeChanges.Count
    $TotalChanges +=
        $Changes.NewServices.Count
    $TotalChanges +=
        $Changes.RemovedServices.Count
    $TotalChanges +=
        $Changes.ChangedServices.Count
    $TotalChanges +=
        $Changes.DiskAlerts.Count
    Write-Section "CAMBIOS DETECTADOS"
    if ($TotalChanges -eq 0) {
        Write-Host ""
        Write-Host "  [OK] No se detectaron cambios importantes." `
            -ForegroundColor $Green
        return
    }
    Write-Host "  Cambios encontrados: " `
        -NoNewline `
        -ForegroundColor $White
    Write-Host $TotalChanges `
        -ForegroundColor $Yellow
    # ------------------------------------------------------------
    # BASES NUEVAS
    # ------------------------------------------------------------
    if ($Changes.NewDatabases.Count -gt 0) {
        Write-Host ""
        Write-Host "  [+] NUEVAS BASES DE DATOS" `
            -ForegroundColor $Green
        foreach ($Database in $Changes.NewDatabases) {
            Write-Host "      + $Database" `
                -ForegroundColor $White
        }
    }
    # ------------------------------------------------------------
    # BASES ELIMINADAS
    # ------------------------------------------------------------
    if ($Changes.RemovedDatabases.Count -gt 0) {
        Write-Host ""
        Write-Host "  [-] BASES ELIMINADAS" `
            -ForegroundColor $Red
        foreach ($Database in $Changes.RemovedDatabases) {
            Write-Host "      - $Database" `
                -ForegroundColor $White
        }
    }
    # ------------------------------------------------------------
    # TAMANO BASES
    # ------------------------------------------------------------
    if ($Changes.DatabaseSizeChanges.Count -gt 0) {
        Write-Host ""
        Write-Host "  [*] CAMBIOS DE TAMANO" `
            -ForegroundColor $Yellow
        foreach ($Change in $Changes.DatabaseSizeChanges) {
            $DifferenceGB =
                [math]::Round(
                    $Change.DifferenceMB / 1024,
                    2
                )
            Write-Host ""
            Write-Host "      Base      : $($Change.Database)"
            Write-Host "      Anterior  : $($Change.PreviousMB) MB"
            Write-Host "      Actual    : $($Change.CurrentMB) MB"
            if ($DifferenceGB -gt 0) {
                Write-Host "      Crecimiento: +$DifferenceGB GB" `
                    -ForegroundColor $Yellow
            }
            else {
                Write-Host "      Cambio    : $DifferenceGB GB" `
                    -ForegroundColor $Cyan
            }
        }
    }
    # ------------------------------------------------------------
    # SERVICIOS
    # ------------------------------------------------------------
    if ($Changes.NewServices.Count -gt 0) {
        Write-Host ""
        Write-Host "  [+] NUEVOS SERVICIOS" `
            -ForegroundColor $Green
        foreach ($Service in $Changes.NewServices) {
            Write-Host "      + $Service"
        }
    }
    if ($Changes.RemovedServices.Count -gt 0) {
        Write-Host ""
        Write-Host "  [-] SERVICIOS ELIMINADOS" `
            -ForegroundColor $Red
        foreach ($Service in $Changes.RemovedServices) {
            Write-Host "      - $Service"
        }
    }
    # ------------------------------------------------------------
    # ESTADO SERVICIOS
    # ------------------------------------------------------------
    if ($Changes.ChangedServices.Count -gt 0) {
        Write-Host ""
        Write-Host "  [!] CAMBIOS DE ESTADO" `
            -ForegroundColor $Yellow
        foreach ($Change in $Changes.ChangedServices) {
            Write-Host ""
            Write-Host "      $($Change.Service)"
            Write-Host "      $($Change.PreviousState) -> $($Change.CurrentState)"
        }
    }
    # ------------------------------------------------------------
    # DISCOS
    # ------------------------------------------------------------
    if ($Changes.DiskAlerts.Count -gt 0) {
        Write-Host ""
        Write-Host "  [!] ALERTAS DE DISCO" `
            -ForegroundColor $Red
        foreach ($Disk in $Changes.DiskAlerts) {
            Write-Host ""
            Write-Host "      Unidad : $($Disk.Drive)"
            Write-Host "      Uso    : $($Disk.UsedPercent)%"
            Write-Host "      Estado : $($Disk.Status)"
        }
    }
}
# ================================================================
# AUDITORIA COMPLETA
# ================================================================
function Start-FullAudit {
    Write-Header "AUDITORIA COMPLETA"
    Write-Host "  Servidor : " -NoNewline
    Write-Host $ServerName -ForegroundColor $Cyan
    Write-Host "  Inicio   : " -NoNewline
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") `
        -ForegroundColor $Gray
    Write-Host ""
    Write-Log "Inicio de auditoria."
    # ============================================================
    # SISTEMA
    # ============================================================
    Write-ProgressBar `
        -Percent 10 `
        -Text "Analizando sistema operativo y hardware..."
    $System =
        Get-SystemInformation
    Start-Sleep -Milliseconds 250
    # ============================================================
    # RED
    # ============================================================
    Write-ProgressBar `
        -Percent 20 `
        -Text "Analizando configuracion de red..."
    $Network =
        Get-NetworkInformation
    Start-Sleep -Milliseconds 250
    # ============================================================
    # DISCOS
    # ============================================================
    Write-ProgressBar `
        -Percent 35 `
        -Text "Analizando almacenamiento..."
    $Storage =
        Get-DiskInformation
    Start-Sleep -Milliseconds 250
    # ============================================================
    # SERVICIOS
    # ============================================================
    Write-ProgressBar `
        -Percent 50 `
        -Text "Analizando servicios..."
    $Services =
        Get-ServiceInformation
    Start-Sleep -Milliseconds 250
    # ============================================================
    # SEGURIDAD
    # ============================================================
    Write-ProgressBar `
        -Percent 65 `
        -Text "Analizando eventos de seguridad..."
    $Security =
        Get-SecurityInformation
    Start-Sleep -Milliseconds 250
    # ============================================================
    # SQL
    # ============================================================
    Write-ProgressBar `
        -Percent 80 `
        -Text "Analizando SQL Server..."
    $SQL =
        Get-SQLInformation
    Start-Sleep -Milliseconds 250
    # ============================================================
    # SNAPSHOT
    # ============================================================
    Write-ProgressBar `
        -Percent 95 `
        -Text "Construyendo snapshot JSON..."
    $Snapshot =
        [PSCustomObject]@{
            AuditVersion =
                "1.1"
            Timestamp =
                (Get-Date).ToString("o")
            Server =
                $ServerName
            System =
                $System
            Network =
                $Network
            Storage =
                $Storage
            Services =
                $Services
            Security =
                $Security
            SQL =
                $SQL
        }
    $Timestamp =
        Get-Date -Format "yyyy-MM-dd_HHmmss"
    $SnapshotFile =
        Join-Path `
            $ServerDataRoot `
            "$Timestamp.json"
    # ============================================================
    # SNAPSHOT ANTERIOR
    # ============================================================
    if (Test-Path $LatestFile) {
        Copy-Item `
            -Path $LatestFile `
            -Destination $PreviousFile `
            -Force
    }
    # ============================================================
    # GUARDAR
    # ============================================================
    $Snapshot |
        ConvertTo-Json -Depth 15 |
        Out-File `
            -FilePath $SnapshotFile `
            -Encoding UTF8
    Copy-Item `
        -Path $SnapshotFile `
        -Destination $LatestFile `
        -Force
    Write-ProgressBar `
        -Percent 100 `
        -Text "Auditoria completada."
    Start-Sleep -Milliseconds 300
    # ============================================================
    # RESUMEN
    # ============================================================
    Write-Header "RESULTADO DE AUDITORIA"
    Write-Status `
        "Sistema operativo" `
        $System.OperatingSystem `
        "OK"
    Write-Status `
        "CPU" `
        "$($System.CPUCores) cores / $($System.LogicalProcessors) threads" `
        "OK"
    $MemoryStatus = "OK"
    if ($System.MemoryUsedPercent -ge 90) {
        $MemoryStatus = "CRITICAL"
    }
    elseif ($System.MemoryUsedPercent -ge 80) {
        $MemoryStatus = "WARNING"
    }
    Write-Status `
        "Memoria" `
        "$($System.MemoryUsedGB) / $($System.MemoryTotalGB) GB ($($System.MemoryUsedPercent)%)" `
        $MemoryStatus
    Write-Status `
        "Discos" `
        "$($Storage.Count) encontrados" `
        "OK"
    Write-Status `
        "Servicios" `
        "$($Services.Count) encontrados" `
        "OK"
    if ($Security.Status -eq "OK") {
        Write-Status `
            "Eventos seguridad (24h)" `
            "$($Security.TotalEvents) eventos" `
            "OK"
    }
    else {
        Write-Status `
            "Eventos seguridad" `
            "No se pudo consultar" `
            "WARNING"
    }
    if ($SQL.Installed) {
        $InstanceCount =
            $SQL.Instances.Count
        $DatabaseCount = 0
        foreach ($Instance in $SQL.Instances) {
            $DatabaseCount +=
                $Instance.Databases.Count
        }
        Write-Status `
            "SQL Server" `
            "$InstanceCount instancia(s)" `
            "OK"
        Write-Status `
            "Bases de datos" `
            "$DatabaseCount encontradas" `
            "OK"
    }
    else {
        Write-Status `
            "SQL Server" `
            "No detectado" `
            "INFO"
    }
    # ============================================================
    # ALERTAS DE DISCO
    # ============================================================
    $CriticalDisks =
        @(
            $Storage |
            Where-Object {
                $_.Status -eq "CRITICAL"
            }
        )
    $WarningDisks =
        @(
            $Storage |
            Where-Object {
                $_.Status -eq "WARNING"
            }
        )
    if ($CriticalDisks.Count -gt 0) {
        Write-Host ""
        Write-Host "  ALERTAS CRITICAS" `
            -ForegroundColor $Red
        foreach ($Disk in $CriticalDisks) {
            Write-Host `
                "  $($Disk.Drive) -> $($Disk.UsedPercent)% utilizado" `
                -ForegroundColor $Red
        }
    }
    if ($WarningDisks.Count -gt 0) {
        Write-Host ""
        Write-Host "  ADVERTENCIAS" `
            -ForegroundColor $Yellow
        foreach ($Disk in $WarningDisks) {
            Write-Host `
                "  $($Disk.Drive) -> $($Disk.UsedPercent)% utilizado" `
                -ForegroundColor $Yellow
        }
    }
    # ============================================================
    # COMPARACION
    # ============================================================
    if (Test-Path $PreviousFile) {
        try {
            $Changes =
                Compare-Audit `
                    -PreviousFile $PreviousFile `
                    -CurrentFile $LatestFile
            Show-Changes $Changes
            $ChangesFile =
                Join-Path `
                    $ServerDataRoot `
                    "changes_$Timestamp.json"
            $Changes |
                ConvertTo-Json -Depth 10 |
                Out-File `
                    -FilePath $ChangesFile `
                    -Encoding UTF8
        }
        catch {
            Write-Host ""
            Write-Host "  [!!] Error comparando snapshots." `
                -ForegroundColor $Red
        }
    }
    else {
        Write-Section "PRIMER SNAPSHOT"
        Write-Host "  Este es el primer analisis de este servidor."
        Write-Host ""
        Write-Host "  En la siguiente ejecucion se podran detectar:"
        Write-Host ""
        Write-Host "    + Nuevas bases de datos"
        Write-Host "    - Bases eliminadas"
        Write-Host "    * Cambios de tamano"
        Write-Host "    + Nuevos servicios"
        Write-Host "    - Servicios eliminados"
        Write-Host "    ! Cambios de estado"
        Write-Host "    ! Alertas de almacenamiento"
    }
    # ============================================================
    # UBICACION
    # ============================================================
    Write-Section "ARCHIVOS GENERADOS"
    Write-Host "  Snapshot:"
    Write-Host "  $SnapshotFile" `
        -ForegroundColor $Cyan
    Write-Host ""
    Write-Host "  Ultimo snapshot:"
    Write-Host "  $LatestFile" `
        -ForegroundColor $Cyan
    Write-Log "Auditoria finalizada."
    Write-Host ""
    Write-Host "  [OK] Auditoria finalizada correctamente." `
        -ForegroundColor $Green
    Write-Host ""
    Read-Host "Presione ENTER para volver al menu"
}
# ================================================================
# INFORMACION RAPIDA
# ================================================================
function Show-ServerInformation {
    Write-Header "INFORMACION DEL SERVIDOR"
    $System =
        Get-SystemInformation
    Write-Status `
        "Nombre" `
        $System.ComputerName `
        "INFO"
    Write-Status `
        "Dominio" `
        $System.Domain `
        "INFO"
    Write-Status `
        "Fabricante" `
        $System.Manufacturer `
        "INFO"
    Write-Status `
        "Modelo" `
        $System.Model `
        "INFO"
    Write-Status `
        "Sistema operativo" `
        $System.OperatingSystem `
        "INFO"
    Write-Status `
        "Version" `
        $System.OSVersion `
        "INFO"
    Write-Status `
        "Build" `
        $System.BuildNumber `
        "INFO"
    Write-Status `
        "Arquitectura" `
        $System.Architecture `
        "INFO"
    Write-Status `
        "CPU" `
        $System.CPUName `
        "INFO"
    Write-Status `
        "Nucleos" `
        "$($System.CPUCores)" `
        "INFO"
    Write-Status `
        "Procesadores logicos" `
        "$($System.LogicalProcessors)" `
        "INFO"
    Write-Status `
        "RAM total" `
        "$($System.MemoryTotalGB) GB" `
        "INFO"
    Write-Status `
        "RAM utilizada" `
        "$($System.MemoryUsedPercent)%" `
        "INFO"
    Write-Status `
        "Ultimo arranque" `
        "$($System.LastBoot)" `
        "INFO"
    Write-Host ""
    Read-Host "Presione ENTER para volver"
}
# ================================================================
# INFORMACION DE DISCOS
# ================================================================
function Show-StorageInformation {
    Write-Header "ALMACENAMIENTO"
    $Storage =
        Get-DiskInformation
    if ($Storage.Count -eq 0) {
        Write-Host "  No se encontraron discos."
    }
    foreach ($Disk in $Storage) {
        switch ($Disk.Status) {
            "OK" {
                $Color = $Green
            }
            "WARNING" {
                $Color = $Yellow
            }
            "CRITICAL" {
                $Color = $Red
            }
        }
        Write-Host "  $($Disk.Drive)" `
            -ForegroundColor $Cyan
        Write-Host "    Volumen : $($Disk.VolumeName)"
        Write-Host "    Sistema : $($Disk.FileSystem)"
        Write-Host "    Tamano  : $($Disk.SizeGB) GB"
        Write-Host "    Usado   : $($Disk.UsedGB) GB"
        Write-Host "    Libre   : $($Disk.FreeGB) GB"
        Write-Host "    Uso     : " -NoNewline
        Write-Host "$($Disk.UsedPercent)% [$($Disk.Status)]" `
            -ForegroundColor $Color
        Write-Host ""
    }
    Read-Host "Presione ENTER para volver"
}
# ================================================================
# SQL
# ================================================================
function Show-SQLInformation {
    Write-Header "SQL SERVER"
    $SQL =
        Get-SQLInformation
    if (-not $SQL.Installed) {
        Write-Host "  SQL Server no fue detectado." `
            -ForegroundColor $Yellow
        Write-Host ""
        Read-Host "Presione ENTER para volver"
        return
    }
    foreach ($Instance in $SQL.Instances) {
        Write-Host ""
        Write-Host "  INSTANCIA: $($Instance.Instance)" `
            -ForegroundColor $Cyan
        Write-Host "  Servicio : $($Instance.ServiceName)"
        Write-Host "  Estado   : $($Instance.ServiceState)"
        Write-Host "  Conexion : $($Instance.Status)"
        Write-Host ""
        if ($Instance.Status -eq "Connected") {
            Write-Host "  BASES DE DATOS" `
                -ForegroundColor $White
            Write-Line
            foreach ($DB in $Instance.Databases) {
                $GB =
                    [math]::Round(
                        $DB.SizeMB / 1024,
                        2
                    )
                Write-Host "  $($DB.DatabaseName)" `
                    -ForegroundColor $Cyan
                Write-Host "    Estado : $($DB.State)"
                Write-Host "    Recovery: $($DB.RecoveryModel)"
                Write-Host "    Tamano : $GB GB"
                Write-Host ""
            }
            Write-Host "  ARCHIVOS MDF / NDF / LDF" `
                -ForegroundColor $White
            Write-Line
            foreach ($File in $Instance.Files) {
                $GB =
                    [math]::Round(
                        $File.SizeMB / 1024,
                        2
                    )
                Write-Host "  $($File.DatabaseName) / $($File.LogicalName)"
                Write-Host "    Tipo : $($File.FileType)"
                Write-Host "    Ruta : $($File.PhysicalName)"
                Write-Host "    Size : $GB GB"
                Write-Host ""
            }
        }
        else {
            Write-Host "  Error:"
            Write-Host "  $($Instance.Error)" `
                -ForegroundColor $Red
        }
    }
    Read-Host "Presione ENTER para volver"
}
# ================================================================
# SEGURIDAD
# ================================================================
function Show-SecurityInformation {
    Write-Header "SEGURIDAD - ULTIMAS 24 HORAS"
    $Security =
        Get-SecurityInformation
    if ($Security.Status -ne "OK") {
        Write-Host "  No se pudo consultar el registro Security." `
            -ForegroundColor $Red
        Write-Host ""
        Write-Host "  $($Security.Error)" `
            -ForegroundColor $Gray
        Read-Host "Presione ENTER para volver"
        return
    }
    Write-Status `
        "Total de eventos" `
        "$($Security.TotalEvents)" `
        "INFO"
    Write-Host ""
    Write-Host "  RESUMEN POR EVENT ID" `
        -ForegroundColor $White
    Write-Line
    foreach ($Item in $Security.Summary) {
        $Status = "OK"
        if ($Item.EventID -eq 4625 -and $Item.Count -gt 0) {
            $Status = "WARNING"
        }
        if ($Item.EventID -eq 4740 -and $Item.Count -gt 0) {
            $Status = "WARNING"
        }
        Write-Status `
            "Event ID $($Item.EventID)" `
            "$($Item.Count) eventos" `
            $Status
    }
    Write-Host ""
    Write-Host "  EVENTOS RECIENTES" `
        -ForegroundColor $White
    Write-Line
    $Recent =
        $Security.Events |
        Sort-Object TimeCreated -Descending |
        Select-Object -First 20
    foreach ($Event in $Recent) {
        Write-Host ""
        Write-Host "  [$($Event.EventID)] $($Event.TimeCreated)" `
            -ForegroundColor $Cyan
        $Message =
            $Event.Message -replace "`r`n", " "
        if ($Message.Length -gt 150) {
            $Message =
                $Message.Substring(0,150) + "..."
        }
        Write-Host "  $Message" `
            -ForegroundColor $Gray
    }
    Write-Host ""
    Read-Host "Presione ENTER para volver"
}
# ================================================================
# ULTIMO SNAPSHOT
# ================================================================
function Show-LatestSnapshot {
    Write-Header "ULTIMO SNAPSHOT"
    if (-not (Test-Path $LatestFile)) {
        Write-Host "  Todavia no existe ningun snapshot." `
            -ForegroundColor $Yellow
        Write-Host ""
        Read-Host "Presione ENTER para volver"
        return
    }
    try {
        $Snapshot =
            Get-Content $LatestFile -Raw |
            ConvertFrom-Json
        Write-Status `
            "Servidor" `
            $Snapshot.Server `
            "INFO"
        Write-Status `
            "Fecha" `
            $Snapshot.Timestamp `
            "INFO"
        Write-Host ""
        Write-Host "  DISCOS" `
            -ForegroundColor $White
        Write-Line
        foreach ($Disk in $Snapshot.Storage) {
            Write-Host `
                "  $($Disk.Drive) | $($Disk.UsedPercent)% | $($Disk.FreeGB) GB libres | $($Disk.Status)"
        }
        Write-Host ""
        Write-Host "  SQL SERVER" `
            -ForegroundColor $White
        Write-Line
        if ($Snapshot.SQL.Installed) {
            foreach ($Instance in $Snapshot.SQL.Instances) {
                Write-Host `
                    "  $($Instance.Instance) | $($Instance.Status)"
                foreach ($DB in $Instance.Databases) {
                    $GB =
                        [math]::Round(
                            $DB.SizeMB / 1024,
                            2
                        )
                    Write-Host `
                        "    $($DB.DatabaseName) | $GB GB | $($DB.State)"
                }
            }
        }
        else {
            Write-Host "  SQL Server no detectado."
        }
    }
    catch {
        Write-Host ""
        Write-Host "  Error leyendo snapshot." `
            -ForegroundColor $Red
    }
    Write-Host ""
    Read-Host "Presione ENTER para volver"
}
# ================================================================
# COMPARAR
# ================================================================
function Show-LastComparison {
    Write-Header "COMPARACION DE SNAPSHOTS"
    if (-not (Test-Path $PreviousFile)) {
        Write-Host "  No existe un snapshot anterior." `
            -ForegroundColor $Yellow
        Write-Host ""
        Read-Host "Presione ENTER para volver"
        return
    }
    if (-not (Test-Path $LatestFile)) {
        Write-Host "  No existe un snapshot actual." `
            -ForegroundColor $Yellow
        Write-Host ""
        Read-Host "Presione ENTER para volver"
        return
    }
    try {
        $Changes =
            Compare-Audit `
                -PreviousFile $PreviousFile `
                -CurrentFile $LatestFile
        Show-Changes $Changes
    }
    catch {
        Write-Host ""
        Write-Host "  Error realizando comparacion." `
            -ForegroundColor $Red
    }
    Write-Host ""
    Read-Host "Presione ENTER para volver"
}
# ================================================================
# MENU PRINCIPAL
# ================================================================
while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host "  |" -NoNewline -ForegroundColor $Cyan
    Write-Centered "S E R V E R   A U D I T" $White
    Write-Host "  |" -ForegroundColor $Cyan
    Write-Host "  |" -NoNewline -ForegroundColor $Cyan
    Write-Centered "V E R S I O N   1 . 1" $Gray
    Write-Host "  |" -ForegroundColor $Cyan
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host ""
    Write-Host "  SERVER" -ForegroundColor $Cyan
    Write-Line
    Write-Host "  Nombre       : " -NoNewline
    Write-Host $ServerName -ForegroundColor $White
    try {
        $OS =
            Get-CimInstance Win32_OperatingSystem
        Write-Host "  Sistema      : " -NoNewline
        Write-Host $OS.Caption -ForegroundColor $White
        Write-Host "  Version      : " -NoNewline
        Write-Host $OS.Version -ForegroundColor $Gray
    }
    catch {}
    Write-Host "  Fecha        : " -NoNewline
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") `
        -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  AUDITORIA" -ForegroundColor $Cyan
    Write-Line
    Write-MenuItem `
        "1" `
        "Auditoria completa" `
        "Analizar todo"
    Write-Host ""
    Write-Host "  CONSULTAS" -ForegroundColor $Cyan
    Write-Line
    Write-MenuItem `
        "2" `
        "Informacion del servidor" `
        "Sistema / CPU / RAM"
    Write-MenuItem `
        "3" `
        "Almacenamiento" `
        "Discos y espacio"
    Write-MenuItem `
        "4" `
        "SQL Server" `
        "Bases y archivos"
    Write-MenuItem `
        "5" `
        "Seguridad" `
        "Eventos Security"
    Write-Host ""
    Write-Host "  HISTORIAL" -ForegroundColor $Cyan
    Write-Line
    Write-MenuItem `
        "6" `
        "Comparar snapshots" `
        "Detectar cambios"
    Write-MenuItem `
        "7" `
        "Ver ultimo snapshot" `
        "Consultar JSON"
    Write-Host ""
    Write-Host "  SISTEMA" -ForegroundColor $Cyan
    Write-Line
    Write-MenuItem `
        "0" `
        "Salir"
    Write-Host ""
    Write-Host "  +----------------------------------------------------------------+" `
        -ForegroundColor $Cyan
    Write-Host ""
    $Option =
        Read-Host "  Seleccione una opcion"
    switch ($Option) {
        "1" {
            Start-FullAudit
        }
        "2" {
            Show-ServerInformation
        }
        "3" {
            Show-StorageInformation
        }
        "4" {
            Show-SQLInformation
        }
        "5" {
            Show-SecurityInformation
        }
        "6" {
            Show-LastComparison
        }
        "7" {
            Show-LatestSnapshot
        }
        "0" {
            Clear-Host
            Write-Host ""
            Write-Host "  +----------------------------------------------------------------+" `
                -ForegroundColor $Cyan
            Write-Host ""
            Write-Centered "SERVER AUDIT FINALIZADO" $Green
            Write-Host ""
            Write-Host "  +----------------------------------------------------------------+" `
                -ForegroundColor $Cyan
            Write-Host ""
            exit
        }
        default {
            Write-Host ""
            Write-Host "  [!!] Opcion no valida." `
                -ForegroundColor $Red
            Start-Sleep -Seconds 2
        }
    }
}