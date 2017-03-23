function Get-BartenderCommanderNodes {
    Get-TervisClusterApplicationNode -ClusterApplicationName BartenderCommander
}

function Invoke-BartenderCommanderProvision {
    Invoke-ClusterApplicationProvision -ClusterApplicationName BartenderCommander
    $Nodes = Get-BartenderCommanderNodes
    $Nodes | Install-WCSPrintersForBartenderCommander
}