﻿configuration Configuration
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

    $LogFolder = "TempLog"
    $LogPath = "c:\$LogFolder"
    $CM = "CMCB"
    $DName = $DomainName.Split(".")[0]
    $PSComputerAccount = "$DName\$PSName$"
    $INTRComputerAccount = "$DName\$INTRName$"
    $ClientComputerAccount = "$DName\$ClientName$"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

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
        
        InstallFeatureForSCCM InstallFeature
        {
            Name = 'DC'
            Role = 'DC'
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        SetupDomain FirstDS
        {
            DomainFullName = $DomainName
            SafemodeAdministratorPassword = $DomainCreds
            DependsOn = "[InstallFeatureForSCCM]InstallFeature"
        }

        InstallCA InstallCA
        {
            HashAlgorithm = "SHA256"
            DependsOn = "[SetupDomain]FirstDS"
        }
		
		InstallGPO DeployingAuditGPO
        {
            GPOURL = $GPOURL
			DomainDNSName = $DomainName
            DependsOn = "[InstallCA]InstallCA"
        }

        VerifyComputerJoinDomain WaitForPS
        {
            ComputerName = $PSName
            Ensure = "Present"
            DependsOn = "[InstallGPO]DeployingAuditGPO"
        }

        VerifyComputerJoinDomain WaitForINTR
        {
            ComputerName = $INTRName
            Ensure = "Present"
            DependsOn = "[InstallGPO]DeployingAuditGPO"
        }

        VerifyComputerJoinDomain WaitForClient
        {
            ComputerName = $ClientName
            Ensure = "Present"
            DependsOn = "[InstallGPO]DeployingAuditGPO"
        }

        File ShareFolder
        {            
            DestinationPath = $LogPath     
            Type = 'Directory'            
            Ensure = 'Present'
            DependsOn = @("[VerifyComputerJoinDomain]WaitForPS","[VerifyComputerJoinDomain]WaitForINTR","[VerifyComputerJoinDomain]WaitForClient")
        }

        FileReadAccessShare DomainSMBShare
        {
            Name   = $LogFolder
            Path =  $LogPath
            Account = $PSComputerAccount,$INTRComputerAccount,$ClientComputerAccount
            DependsOn = "[File]ShareFolder"
        }

        WriteConfigurationFile WritePSJoinDomain
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "PSJoinDomain"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

        WriteConfigurationFile WriteINTRJoinDomain
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "INTRJoinDomain"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

        WriteConfigurationFile WriteClientJoinDomain
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "ClientJoinDomain"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }
		
        DownloadAndRunSysmon DwnldSysmon
        {
            CM = "CM"
            Ensure = "Present"
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

 #       DelegateControl AddPS
 #       {
 #           Machine = $PSName
 #           DomainFullName = $DomainName
 #           Ensure = "Present"
 #           DependsOn = "[WriteConfigurationFile]WritePSJoinDomain"
 #       }

 #       DelegateControl AddINTR
 #       {
 #           Machine = $INTRName
 #           DomainFullName = $DomainName
 #           Ensure = "Present"
 #           DependsOn = "[WriteConfigurationFile]WriteINTRJoinDomain"
 #       }

        WriteConfigurationFile WriteDelegateControlfinished
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "DelegateControl"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = @("[FileReadAccessShare]DomainSMBShare","[FileReadAccessShare]DomainSMBShare")
        }

#        WaitForExtendSchemaFile WaitForExtendSchemaFile
#        {
#            MachineName = $PSName
#            ExtFolder = $CM
#            Ensure = "Present"
#            DependsOn = "[WriteConfigurationFile]WriteDelegateControlfinished"
#        }
    }
}