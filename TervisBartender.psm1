$ModulePath = (Get-Module -ListAvailable TervisBartender).ModuleBase

function Get-BartenderCommanderNodes {
    Get-TervisClusterApplicationNode -ClusterApplicationName BartenderCommander
}

function Invoke-BartenderCommanderProvision {
    param (
        $EnvironmentName
    )
    Invoke-ClusterApplicationProvision -ClusterApplicationName BartenderCommander
    $Nodes = Get-TervisClusterApplicationNode -ClusterApplicationName BartenderCommander -EnvironmentName $EnvironmentName
    $Nodes | Install-WCSPrintersForBartenderCommander
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName Tervis
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName tervisBartender
    $Nodes | Set-TervisBTLMIniFile
    $Nodes | Set-TervisCommanderTaskList
    New-NetFirewallRule -Name "BartenderCommanderTask" -Direction Inbound -LocalPort 5170 -Protocol TCP -Action Allow -Group BartenderCommander
}

function Set-TervisBTLMIniFile {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $BartenderProgramData = "C:\ProgramData\Seagull\BarTender"    
    }
    process {
        $BartenderProgramDataPathOnNode = $BartenderProgramData | ConvertTo-RemotePath -ComputerName $ComputerName
        Copy-Item -Path $ModulePath\BTLM.ini -Destination $BartenderProgramDataPathOnNode\BTLM.ini -Force
    }
}

function Set-TervisCommanderTaskList {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName = "localhost",
        [Switch]$Force
    )
    begin {
        $TervisCommanderDataPathLocal = "C:\ProgramData\TervisSeagull\Commander"
    }
    process {        
        $TervisCommanderDataPathRemote = $TervisCommanderDataPathLocal | ConvertTo-RemotePath -ComputerName $ComputerName
        if (-not (Test-Path -Path $TervisCommanderDataPathRemote\btxml.tl) -or $Force) {
            New-Item -ItemType Directory -Path $TervisCommanderDataPathRemote -Force | Out-Null
            Copy-Item -Path $ModulePath\btxml.tl -Destination $TervisCommanderDataPathRemote\btxml.tl
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                $CommanderPreferencesPath = "HKLM:\SOFTWARE\WOW6432Node\Seagull Scientific\Commander\Preferences"
                Set-ItemProperty -Path $CommanderPreferencesPath -Type String -Name "Config File" -Value "$Using:TervisCommanderDataPathLocal\btxml.tl" | Out-Null
                Set-ItemProperty -Path $CommanderPreferencesPath -Type DWord -Name "Load File Option" -Value 2 | Out-Null
                Set-ItemProperty -Path $CommanderPreferencesPath -Type DWord -Name "Detection Option" -Value 2 | Out-Null
                Restart-Service -Name "Commander Service"
            }
        }
    }
}

function ConvertTo-RemotePath {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$Path,
        [Parameter(Mandatory)]$ComputerName
    )
    "\\$ComputerName\$($Path-replace ":","$")"
}

function Restart-CommanderService {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName = "localhost"
    )
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Restart-Service -Name "Commander Service"
        }
    }
}

function Remove-TervisCommanderTaskList {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName = "localhost"
    )
    process {
        Remove-Item "\\$ComputerName\C$\ProgramData\TervisSeagull\Commander\btxml.tl"
    }
}