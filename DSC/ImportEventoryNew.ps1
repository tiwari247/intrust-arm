[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
    [string]
    $XML,
	[Parameter(Mandatory=$false)]
    [switch]
    $Remove
)

$XMLFile = Get-ChildItem -Path $XML
[xml]$ITSSSMAP=(Get-Content -path $XML -Raw)


$regasm = gci 'C:\Windows\Microsoft.NET\Framework' -Filter 'regasm.exe' -Recurse | Sort-Object Directory -Descending | select -First 1
gci ${env:CommonProgramFiles(x86)} -Filter 'Interop.InTrustEnvironment.dll' -Recurse |%{[Reflection.Assembly]::LoadFrom($_.FullName)}


function Connect-ToServer([string]$serverName=$Env:ComputerName){
    $inTrustEnvironment = New-Object Interop.InTrustEnvironment.InTrustEnvironmentClass
    $inTrustServer = $inTrustEnvironment.ConnectToServer($serverName)
    return $inTrustServer
}

function Add-LogToEventory
{
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
        $LogName,
        [xml]
        $XmlLogContent,
		[string]
		$ServerName=$Env:ComputerName
	)

   $intrustServer = Connect-ToServer -serverName $ServerName

   $Error.Clear()
   try{
       $Log = $inTrustServer.Organization.Eventory.Logs.Add($LogName, $XmlLogContent.OuterXml)
   }
   catch {
       return $Error
   }

   return $Log
}

function Remove-EventoryLog
{
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$LogName,
		[string]
		$ServerName=$Env:ComputerName
	)
	$inTrustServer = Connect-ToServer -serverName $ServerName
	$RemoveLogs = $inTrustServer.Organization.Eventory.Logs | Where-Object {$_.Name -like "$LogName"}
	$RemoveLogs | % {$inTrustServer.Organization.Eventory.Logs.Remove($_.Name)}
}


if($Remove)
{
    Write-Host "Removin Log Eventory"
    Remove-EventoryLog -LogName $XMLFile.BaseName
}
else
{
    Write-Host "Add Log to eventory"
    Add-LogToEventory -LogName $XMLFile.BaseName -XmlLogContent $ITSSSMAP -ServerName localhost
}


