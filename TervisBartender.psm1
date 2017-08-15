$ModulePath = (Get-Module -ListAvailable TervisBartender).ModuleBase

function Get-BartenderCommanderNodes {
    Get-TervisApplicationNode -ApplicationName BartenderCommander
}

function Invoke-BartenderCommanderProvision {
    param (
        $EnvironmentName
    )
    Invoke-ApplicationProvision -ApplicationName BartenderCommander -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisApplicationNode -ApplicationName BartenderCommander -EnvironmentName $EnvironmentName
    $Nodes | Install-WCSPrinters -PrintEngineOrientationRelativeToLabel Bottom
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName Tervis
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName tervisBartender
    $Nodes | Set-TervisBartenderFiles
    $Nodes | Set-TervisCommanderTaskList
    $Nodes | New-BartenderCommanderFirewallRules
    $Nodes | Install-BartenderCommanderScheduledTasks
}

function Invoke-BartenderLicenseServerProvision {
    param (
        $EnvironmentName
    )
    Invoke-ApplicationProvision -ApplicationName BartenderLicenseServer -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisApplicationNode -ApplicationName BartenderLicenseServer -EnvironmentName $EnvironmentName
    $Nodes | Start-BartenderLicenseServerService
}

function Invoke-BartenderIntegrationServiceProvision {
    param (
        $EnvironmentName
    )
    Invoke-ApplicationProvision -ApplicationName BartenderIntegrationService -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisApplicationNode -ApplicationName BartenderIntegrationService -EnvironmentName $EnvironmentName
    $Nodes | Install-WCSPrinters -PrintEngineOrientationRelativeToLabel Bottom
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName Tervis
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName tervisBartender
    $Nodes | New-BartenderIntegrationServiceFirewallRules
    $Nodes | Set-TervisBartenderIntegrationServiceFiles
    $Nodes | Restart-BartenderIntegrationService
}

function New-BartenderCommanderFirewallRules {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $FirewallRule = Get-NetFirewallRule -Name "BartenderCommanderTask" -ErrorAction SilentlyContinue
            if (-not $FirewallRule) {
                New-NetFirewallRule -Name "BartenderCommanderTask" -DisplayName "Bartender Commander Task" -Direction Inbound -LocalPort 5170 -Protocol TCP -Action Allow -Group BartenderCommander | Out-Null
            }
        }
    }
}

function New-BartenderIntegrationServiceFirewallRules {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        New-TervisFirewallRule -ComputerName $ComputerName -Name BartenderIntegrationServiceDeployment -DisplayName "Bartender Integration Service Deployment" -Direction Inbound -LocalPort 5170 -Protocol TCP -Action Allow -Group BartenderIntegrationService        
    }
}

function New-BartenderLicenseServerFirewallRules {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        New-TervisFirewallRule -ComputerName $ComputerName -DisplayName "Bartender License Server" -Group Bartender -LocalPort 5160 -Name "BartenderLicenseServer" -Direction Inbound -Action Allow -Protocol tcp
    }
}

function Start-BartenderLicenseServerService {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $ServiceStatus = Get-Service -Name "Seagull License Server"
            if ($ServiceStatus.Status -ne "Running") {
                Start-Service -Name "Seagull License Server"
            }
        }
    }
}

function Set-TervisBartenderFiles {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $PathToContainProgramData = "C:\"
    }
    process {
        $PathToContainProgramDataOnNode = $PathToContainProgramData | ConvertTo-RemotePath -ComputerName $ComputerName
        Copy-Item -Path $ModulePath\ProgramData -Destination $PathToContainProgramDataOnNode -Force -Recurse
    }
}

function Set-TervisBartenderIntegrationServiceFiles {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $PathToToIntegrationServiceFilesLocal = "C:\ProgramData\Seagull\Services\Integrations\Service"
    }
    process {
        $PathToToIntegrationServiceFilesRemote = $PathToToIntegrationServiceFilesLocal |
        ConvertTo-RemotePath -ComputerName $ComputerName

        Copy-Item -Path "$ModulePath\Integrations\BTXML receive on TCP Port 5170.btin" -Destination $PathToToIntegrationServiceFilesRemote -Force -Recurse
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

function Restart-BartenderIntegrationService {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Get-Service -ComputerName $ComputerName -Name "BarTender Integration Service" |
        Restart-Service
    }
}

function ConvertTo-RemotePath {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$Path,
        [Parameter(Mandatory)]$ComputerName
    )
    process {
        "\\$ComputerName\$($Path-replace ":","$")"
    }
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

function Install-BartenderCommanderScheduledTasks {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $SystemCredential = New-Object System.Management.Automation.PSCredential ('System',(New-Object System.Security.SecureString))
        $Argument = "-NoProfile -Command `"& {Stop-Service -Name 'Commander Service' -Force -PassThru | Start-Service}`""
    }
    process {
        Install-TervisScheduledTask -Credential $SystemCredential `
            -TaskName "Restart Commander Service" `
            -Execute PowerShell `
            -Argument $Argument `
            -RepetitionIntervalName EveryDayAt3am `
            -ComputerName $ComputerName
    }
}

function Send-BartenderIntegrationServiceBTXMLJob {
    param (
        $PathToBartenderLabel,
        $Printer,
        $ContainerCode,
        $ComputerName
    )
    $EndOfTextControlCharacter = [char]0x0003
    $BTXML = @"
<?xml version="1.0" encoding="UTF-8"?>
<XMLScript Version="2.0">
   <Command>
      <Print ReturnPrintData="true" ReturnLabelData="true" ReturnChecksum="false">
         <Format>$PathToBartenderLabel</Format>
         <PrintSetup>
            <Printer>$Printer</Printer>
            <Performance>
               <AllowFormatCaching>true</AllowFormatCaching>
               <AllowGraphicsCaching>true</AllowGraphicsCaching>
               <AllowSerialization>true</AllowSerialization>
               <AllowStaticGraphics>true</AllowStaticGraphics>
               <AllowStaticObjects>true</AllowStaticObjects>
               <AllowVariableDataOptimization>false</AllowVariableDataOptimization>
               <WarnWhenUsingTrueTypeFonts>true</WarnWhenUsingTrueTypeFonts>
            </Performance>
         </PrintSetup>
         <QueryPrompt Name="ContainerCode">
            <Value>$ContainerCode</Value>
         </QueryPrompt>
      </Print>
   </Command>
</XMLScript>
"@

    $Data = $BTXML + $EndOfTextControlCharacter
    Send-TCPClientData -ComputerName $ComputerName -Port 5170 -Data $Data -Encoding ([System.Text.Encoding]::Default) -NoReply
}
