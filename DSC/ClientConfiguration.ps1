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
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
    Import-DscResource -ModuleName TemplateHelpDSC

    $LogFolder = "TempLog"
    $LogPath = "c:\$LogFolder"
    $DName = $DomainName.Split(".")[0]
    $DCComputerAccount = "$DName\$DCName$"
    $PSComputerAccount = "$DName\$PSName$"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $PrimarySiteName = $PSName.split(".")[0] + "$"

    Node localhost
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

        SetDNS DnsServerAddress
        {
            DNSIPAddress = $DNSIPAddress
            Ensure = "Present"
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        InstallFeatureForSCCM InstallFeature
        {
            Name = "Client"
            Role = "Client"
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        WaitForDomainReady WaitForDomain
        {
            Ensure = "Present"
            DCName = $DCName
            DependsOn = "[SetDNS]DnsServerAddress"
        }

        JoinDomain JoinDomain
        {
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[WaitForDomainReady]WaitForDomain"
        }

        WaitForConfigurationFile WaitForPSJoinDomain
        {
            Role = "DC"
            MachineName = $DCName
            LogFolder = $LogFolder
            ReadNode = "PSJoinDomain"
            Ensure = "Present"
            DependsOn = "[JoinDomain]JoinDomain"
        }

        File ShareFolder
        {            
            DestinationPath = $LogPath     
            Type = 'Directory'            
            Ensure = 'Present'
            DependsOn = "[WaitForConfigurationFile]WaitForPSJoinDomain"
        }

        FileReadAccessShare DomainSMBShare
        {
            Name   = $LogFolder
            Path = $LogPath
            Account = $DCComputerAccount,$PSComputerAccount
            DependsOn = "[File]ShareFolder"
        }

        OpenFirewallPortForSCCM OpenFirewall
        {
            Name = "Client"
            Role = "Client"
            DependsOn = "[JoinDomain]JoinDomain"
        }

        AddUserToLocalAdminGroup AddADUserToLocalAdminGroup {
            Name = $($Admincreds.UserName)
            DomainName = $DomainName
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

        AddUserToLocalAdminGroup AddADComputerToLocalAdminGroup {
            Name = "$PrimarySiteName"
            DomainName = $DomainName
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

        WriteConfigurationFile WriteClientFinished
        {
            Role = "Client"
            LogPath = $LogPath
            WriteNode = "ClientFinished"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[AddUserToLocalAdminGroup]AddADUserToLocalAdminGroup","[AddUserToLocalAdminGroup]AddADComputerToLocalAdminGroup"
        }

#        DownloadAndRunETW DwnldETW
#        {
#            CM = "CM"
#            Ensure = "Present"
#            DependsOn = "[WriteConfigurationFile]WriteClientFinished"
#        }

        DownloadAndRunSysmon DwnldSysmon
        {
            CM = "CM"
            Ensure = "Present"
            DependsOn = "[WriteConfigurationFile]WriteClientFinished"
        }

#        DownloadAndRunSilkETW DwnldSilk
#        {
#            CM = "CM"
#            Ensure = "Present"
#            DependsOn = "[DownloadAndRunSysmon]DwnldSysmon"
#        }
#        Environment Path
#        {
#            Name = "Path"
#            Path = $true
#            Value = "C:\SilkETW\v8\SilkService\"
#            DependsOn = "[DownloadAndRunSilkETW]DwnldSilk"
#        }
#        StartSilkETW StartSilk
#        {
#            CM = "CM"
#            Ensure = "Present"
#            DependsOn = "[Environment]Path"
#        }
    }
}