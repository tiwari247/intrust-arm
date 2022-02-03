configuration Configuration
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [String]$DCName,
        [Parameter(Mandatory)]
        [String]$INTRName,
        [Parameter(Mandatory)]
        [String]$ClientName,
        [Parameter(Mandatory)]
        [String]$PSName,
        [Parameter(Mandatory)]
		[String]$IntrUrl,
		[Parameter(Mandatory)]
		[String]$IntrUpdateUrl,
        [Parameter(Mandatory)]
		[String]$IntrLicUrl,
		[Parameter(Mandatory)]
		[String]$GPOURL,
		[Parameter(Mandatory)]
		[String]$ETWURL,
		[Parameter(Mandatory)]
		[String]$ITSSURL,
        [Parameter(Mandatory)]
        [String]$ITSSUpdateURL,
        [Parameter(Mandatory)]
        [String]$DNSIPAddress,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
		[Parameter(Mandatory)]
		[String]$SMTPSmartHostAddress,
		[Parameter(Mandatory)]
		[String]$SMTPSmartHostPort,
		[Parameter(Mandatory)]
		[String]$SMTPSmartHostUserName,
		[Parameter(Mandatory)]
		[String]$SMTPSmartHostPassword,
		[Parameter(Mandatory)]
		[String]$SMTPMailFrom,
		[Parameter(Mandatory)]
		[String]$DefaultOperatorAddress
    )
	
    Import-DscResource -ModuleName TemplateHelpDSC
	Import-DscResource -Module xCredSSP
	
    $LogFolder = "TempLog"
    $CM = "IntrFull"
    $LogPath = "c:\$LogFolder"
    $DName = $DomainName.Split(".")[0]
    $DCComputerAccount = "$DName\$DCName$"
    $INTRComputerAccount = "$DName\$INTRName$"
    
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    $admname = $Admincreds.UserName
	$admpwd=$Admincreds.GetNetworkCredential().password

    Node LOCALHOST
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
        SetCustomPagingFile PagingSettings
        {
            Drive       = 'C:'
            InitialSize = '8192'
            MaximumSize = '8192'
        }
        
        AddBuiltinPermission AddSQLPermission
        {
            Ensure = "Present"
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        InstallFeatureForSCCM InstallFeature
        {
            NAME = "PS"
            Role = "Site Server"
            DependsOn = "[AddBuiltinPermission]AddSQLPermission"
        }

#        InstallADK ADKInstall
#        {
#            ADKPath = "C:\adksetup.exe"
#            ADKWinPEPath = "c:\adksetupwinpe.exe"
#            Ensure = "Present"
#            DependsOn = "[InstallFeatureForSCCM]InstallFeature"
#        }

#        DownloadSCCM DownLoadSCCM
#        {
#            CM = $CM
#            ExtPath = $LogPath
#			IntrUrl= $IntrUrl
#			IntrUpdateUrl= $IntrUpdateUrl
#			IntrLicUrl= $IntrLicUrl
#            Ensure = "Present"
#            DependsOn = "[InstallFeatureForSCCM]InstallFeature"
#        }

        DownloadITSS DownLoadITSS
        {
            CM = "ITSS"
            ExtPath = $LogPath
			ITSSUrl= $ITSSUrl
			ITSSUpdateUrl= $ITSSUpdateUrl
			ITSSLicUrl= ""#$IntrLicUrl
            Ensure = "Present"
            DependsOn = "[InstallFeatureForSCCM]InstallFeature"
        }

        SetDNS DnsServerAddress
        {
            DNSIPAddress = $DNSIPAddress
            Ensure = "Present"
            DependsOn = "[DownloadITSS]DownLoadITSS"
        }

        WaitForDomainReady WaitForDomain
        {
            Ensure = "Present"
            DCName = $DCName
            WaitSeconds = 0
            DependsOn = "[SetDNS]DnsServerAddress"
        }

        JoinDomain JoinDomain
        {
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[WaitForDomainReady]WaitForDomain"
        }
        
        File ShareFolder
        {            
            DestinationPath = $LogPath     
            Type = 'Directory'            
            Ensure = 'Present'
            DependsOn = "[JoinDomain]JoinDomain"
        }

        FileReadAccessShare DomainSMBShare
        {
            Name   = $LogFolder
            Path =  $LogPath
            Account = $DCComputerAccount
            DependsOn = "[File]ShareFolder"
        }
        
        OpenFirewallPortForSCCM OpenFirewall
        {
            Name = "PS"
            Role = "Site Server"
            DependsOn = "[JoinDomain]JoinDomain"
        }

        WaitForConfigurationFile DelegateControl
        {
            Role = "DC"
            MachineName = $DCName
            LogFolder = $LogFolder
            ReadNode = "DelegateControl"
            Ensure = "Present"
            DependsOn = "[OpenFirewallPortForSCCM]OpenFirewall"
        }

        ChangeSQLServicesAccount ChangeToLocalSystem
        {
            SQLInstanceName = "MSSQLSERVER"
            Ensure = "Present"
            DependsOn = "[WaitForConfigurationFile]DelegateControl"
        }

 #       FileReadAccessShare CMSourceSMBShare
 #       {
 #           Name   = $CM
 #           Path =  "c:\$CM"
 #           Account = $DCComputerAccount
 #           DependsOn = "[ChangeSQLServicesAccount]ChangeToLocalSystem"
 #       }
		
		xCredSSP Server
        {
            Ensure = "Present"
            Role = "Server"
            SuppressReboot = $true
			DependsOn = "[ChangeSQLServicesAccount]ChangeToLocalSystem"
        }
        xCredSSP Client
        {
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*"
			DependsOn = "[xCredSSP]Server"
        }

        RegisterTaskScheduler InstallAndUpdateSCCM
        {
            TaskName = "ScriptWorkFlow"
            ScriptName = "ScriptWorkFlow.ps1"
            ScriptPath = $PSScriptRoot
            ScriptArgument = "$DomainName $CM $DName\$($Admincreds.UserName) $INTRName $ClientName"
            Ensure = "Present"
            DependsOn = "[xCredSSP]Client"
        }
        DownloadAndRunSysmon DwnldSysmon
        {
            CM = "CM"
            Ensure = "Present"
            DependsOn = "[xCredSSP]Client"
        }

 #       InstallITSS InstallITSSTask
 #       {
 #           CM = "ITSS"
 #           Adminpass = $admpwd
#			DomainName = $DomainName
#            Credential = $DomainCreds
#			PSName = $PSName
#            INTRName = $INTRName
#			ScriptPath = $PSScriptRoot
#            Ensure = "Present"
#            DependsOn = "[DownloadAndRunSysmon]DwnldSysmon"
#        }
#        InstallITSSUpdate InstallITSSUpdateTask
#        {
#            CM = "ITSS_U"
#            Adminpass = $admpwd
#			DomainName = $DomainName
#            Credential = $DomainCreds
#			PSName = $PSName
#            INTRName = $INTRName
#			ScriptPath = $PSScriptRoot
#            Ensure = "Present"
#            DependsOn = "[InstallITSS]InstallITSSTask"
#        }
    }
}