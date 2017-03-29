function Get-BartenderCommanderNodes {
    Get-TervisClusterApplicationNode -ClusterApplicationName BartenderCommander
}

function Invoke-BartenderCommanderProvision {
    Invoke-ClusterApplicationProvision -ClusterApplicationName BartenderCommander
    $Nodes = Get-BartenderCommanderNodes
    $Nodes | Install-WCSPrintersForBartenderCommander
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName Tervis
    $Nodes | Add-WCSODBCDSN -ODBCDSNTemplateName tervisBartender
    $Nodes | Set-BTLMIniFile
}

function Set-BTLMIniFile {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $BartenderInstallPath = "C:\Program Files (x86)\Seagull\BarTender Suite"    
        $ModulePath = (Get-Module -ListAvailable TervisBartender).ModuleBase
    }
    process {
        $BartenderInstallPathOnNode = "\\$ComputerName\$($BartenderInstallPath -replace ":","$")"
        Copy-Item -Path $ModulePath\BTLM.ini -Destination $BartenderInstallPathOnNode\BTLM.ini -Force
    }
}