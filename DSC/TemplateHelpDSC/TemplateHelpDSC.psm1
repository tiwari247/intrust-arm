enum Ensure
{
    Absent
    Present
}

enum StartupType
{
    auto
    delayedauto
    demand
}

[DscResource()]
class InstallSMTPRelay
{
    [DscProperty(Key)]
    [string] $SmartHostAddress

    [DscProperty(Key)]
    [string] $SmartHostPort

    [DscProperty(Key)]
    [string] $SmartHostUserName

    [DscProperty(Key)]
    [string] $SmartHostPassword

    [void] Set()
    {
        try
        {
		$_SmartHostAddress = $this.SmartHostAddress
		$_SmartHostPort = $this.SmartHostPort
		$_SmartHostUserName = $this.SmartHostUserName
		$_SmartHostPassword = $this.SmartHostPassword
		Write-Verbose "Configuring SMTP Relay..." 
		Import-Module ServerManager
		Add-WindowsFeature SMTP-Server,Web-Mgmt-Console,WEB-WMI

		Set-Service "SMTPSVC" -StartupType Automatic -ErrorAction SilentlyContinue
		Start-Service "SMTPSVC" -ErrorAction SilentlyContinue

		$SmtpConfig = Get-WMIObject -Namespace root/MicrosoftIISv2 -ComputerName localhost -Query "Select * From IisSmtpServerSetting"

		$RelayIpList = @( 24,0,0,128,32,0,0,128,60,0,0,128,68,0,0,128,1,0,0,0,76,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,2,0,0,0,1,0,0,0,4,0,0,0,0,0,0,0,76,0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,255,255 )

		$Networkip =@()
		$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName    localhost | ? {$_.IPEnabled}
		foreach($Network in $Networks)  {  $Networkip = $Network.IpAddress[0]  }
		$ipList = @()
		$octet = @()
		$ipList = "127.0.0.1"
		$octet += $ipList.Split(".")
		$octet += $Networkip.Split(".")
		$RelayIpList += $octet

		#$RelayIpList[36] +=2 
		#$RelayIpList[44] +=2

		$SmtpConfig.MaxMessageSize = "15728640"                                                  
		$SmtpConfig.MaxSessionSize = "52428800"                                                   
		$SmtpConfig.RelayForAuth = "-1"                                                          
		$SmtpConfig.RelayIpList = $RelayIpList
		$SmtpConfig.RemoteSmtpPort = $_SmartHostPort                                                         
		$SmtpConfig.RouteAction = "268"                                                         
		$SmtpConfig.RoutePassword = $_SmartHostPassword                                                    
		$SmtpConfig.RouteUserName = $_SmartHostUserName
		$SmtpConfig.SmartHost = $_SmartHostAddress           
		$SmtpConfig.SmartHostType = "2"                                                     

		$SmtpConfig.Put()

		Restart-Service "SMTPSVC" -ErrorAction SilentlyContinue

		$StatusPath = "$env:windir\temp\InstallSMTPRelayStatus.txt"
		"Finished" >> $StatusPath

		Write-Verbose "Finished installing SMTP relay."
        }
        catch
        {
            Write-Verbose "Failed to configure SMTP relay."
        }
    }

    [bool] Test()
    {
		$StatusPath = "$env:windir\temp\InstallSMTPRelayStatus.txt"
		if(Test-Path $StatusPath)
		{
		return $true
		}

        return $false
    }

    [InstallSMTPRelay] Get()
    {
        return $this
    }
    
}

[DscResource()]
class InstallADK
{
    [DscProperty(Key)]
    [string] $ADKPath

    [DscProperty(Mandatory)]
    [string] $ADKWinPEPath

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_adkpath = $this.ADKPath
        if(!(Test-Path $_adkpath))
        {
            #ADK 1809 (17763)
            $adkurl = "https://go.microsoft.com/fwlink/?linkid=2026036"
            Invoke-WebRequest -Uri $adkurl -OutFile $_adkpath
        }

        $_adkWinPEpath = $this.ADKWinPEPath
        if(!(Test-Path $_adkWinPEpath))
        {
            #ADK add-on (17763)
            $adkurl = "https://go.microsoft.com/fwlink/?linkid=2022233"
            Invoke-WebRequest -Uri $adkurl -OutFile $_adkWinPEpath
        }
        #Install DeploymentTools
        $adkinstallpath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"
        while(!(Test-Path $adkinstallpath))
        {
            $cmd = $_adkpath
            $arg1  = "/Features"
            $arg2 = "OptionId.DeploymentTools"
            $arg3 = "/q"

            try
            {
                Write-Verbose "Installing ADK DeploymentTools..."
                & $cmd $arg1 $arg2 $arg3 | out-null
                Write-Verbose "ADK DeploymentTools Installed Successfully!"
            }
            catch
            {
                $ErrorMessage = $_.Exception.Message
                throw "Failed to install ADK DeploymentTools with below error: $ErrorMessage"
            }

            Start-Sleep -Seconds 10
        }

        #Install UserStateMigrationTool
        $adkinstallpath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool"
        while(!(Test-Path $adkinstallpath))
        {
            $cmd = $_adkpath
            $arg1  = "/Features"
            $arg2 = "OptionId.UserStateMigrationTool"
            $arg3 = "/q"

            try
            {
                Write-Verbose "Installing ADK UserStateMigrationTool..."
                & $cmd $arg1 $arg2 $arg3 | out-null
                Write-Verbose "ADK UserStateMigrationTool Installed Successfully!"
            }
            catch
            {
                $ErrorMessage = $_.Exception.Message
                throw "Failed to install ADK UserStateMigrationTool with below error: $ErrorMessage"
            }

            Start-Sleep -Seconds 10
        }

        #Install WindowsPreinstallationEnvironment
        $adkinstallpath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
        while(!(Test-Path $adkinstallpath))
        {
            $cmd = $_adkWinPEpath
            $arg1  = "/Features"
            $arg2 = "OptionId.WindowsPreinstallationEnvironment"
            $arg3 = "/q"

            try
            {
                Write-Verbose "Installing WindowsPreinstallationEnvironment for ADK..."
                & $cmd $arg1 $arg2 $arg3 | out-null
                Write-Verbose "WindowsPreinstallationEnvironment for ADK Installed Successfully!"
            }
            catch
            {
                $ErrorMessage = $_.Exception.Message
                throw "Failed to install WindowsPreinstallationEnvironment for ADK with below error: $ErrorMessage"
            }

            Start-Sleep -Seconds 10
        }
    }

    [bool] Test()
    {
        $key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
        $subKey =  $key.OpenSubKey("SOFTWARE\Microsoft\Windows Kits\Installed Roots")
        if($subKey)
        {
            if($subKey.GetValue('KitsRoot10') -ne $null)
            {
                if($subKey.GetValueNames() | ?{$subkey.GetValue($_) -like "*Deployment Tools*"})
                {
                    return $true
                }
            }
        }
        return $false
    }

    [InstallADK] Get()
    {
        return $this
    }
}

[DscResource()]
class InstallAndConfigWSUS
{
    [DscProperty(Key)]
    [string] $WSUSPath

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_WSUSPath = $this.WSUSPath
        if(!(Test-Path -Path $_WSUSPath))
        {
            New-Item -Path $_WSUSPath -ItemType Directory
        }
        Write-Verbose "Installing WSUS..."
        Install-WindowsFeature -Name UpdateServices,UpdateServices-WidDB -IncludeManagementTools
        Write-Verbose "Finished installing WSUS..."

        Write-Verbose "Starting the postinstall for WSUS..."
        sl "C:\Program Files\Update Services\Tools"
        .\wsusutil.exe postinstall CONTENT_DIR=C:\WSUS
        Write-Verbose "Finished the postinstall for WSUS"
    }

    [bool] Test()
    {
        if((Get-WindowsFeature -Name UpdateServices).installed -eq 'True')
        {
            return $true
        }
        return $false
    }

    [InstallAndConfigWSUS] Get()
    {
        return $this
    }
    
}

[DscResource()]
class InstallITSS
{
    [DscProperty(Key)]
    [string] $CM
	
	[DscProperty(Key)]
    [string] $AdminPass
	
    [DscProperty(Key)]
    [string] $DomainName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $Credential

	
	[DscProperty(Key)]
    [string] $PSName

    [DscProperty(Key)]
    [string] $INTRName
	
	[DscProperty(Key)]
    [string] $ScriptPath

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
		$_CM = $this.CM
		$_SP=$this.ScriptPath
		$usernm=$this.Credential.UserName
		$PScreds=$this.Credential
		$admpass=$this.AdminPass
		$sqlsrv=$this.PSName
        $intrsrv=$this.INTRName
        $cmpath = "c:\$_CM.exe"
        $cmsourcepath = "c:\$_CM"
		$creds=$usernm

			$StatusPath = "$cmsourcepath\Installcmd.txt"
            "Started..." >> $StatusPath
			#${DomainName}\$($creds.UserName)
            $arglist=' /install /quiet /log `"'+$cmsourcepath+'\install.log`" ADC_USERNAME='+$creds+' ADC_PASSWORD='+$admpass+' IT_SQL_SETTINGS_INITIALIZED=1 ADC_SQL_SERVER='+$sqlsrv+' ADC_SQL_DB_NAME=ITSS_AdcCfg ADC_SQL_TYPE=1 ADC_SQL_USERNAME='+$creds+' ADC_SQL_PASSWD='+$admpass+' IACCEPTSQLNCLILICENSETERMS=YES SIP_OPTIN=#0 MMWEBUI_PORT=`"443`" ALLOWUSAGEDATACOLLECTION=`"False`" INSTALL_ADC=#1'
            $filepath="$cmsourcepath\Components\ITSearchSuite.exe"
            $command0="& {start-process -Filepath '"+$filepath+"' -ArgumentList (`""+$arglist+"`") -verb Runas -wait}"
            $command=" -noprofile -command `""+$command0+"`""
            $ps_script=$filepath+" /install /quiet /log "+$cmsourcepath+"\install.log ADC_USERNAME="+$creds+" ADC_PASSWORD="+$admpass+" IT_SQL_SETTINGS_INITIALIZED=1 ADC_SQL_SERVER="+$sqlsrv+" ADC_SQL_DB_NAME=ITSS_AdcCfg ADC_SQL_TYPE=1 ADC_SQL_USERNAME="+$creds+" ADC_SQL_PASSWD="+$admpass+" IACCEPTSQLNCLILICENSETERMS=YES SIP_OPTIN=#0 MMWEBUI_PORT=`"443`" ALLOWUSAGEDATACOLLECTION=`"False`" INSTALL_ADC=#1"
            $StatusPath = "$cmsourcepath\Installcmd.ps1"
            $ps_script >> $StatusPath
			#Start-Process powershell -Credential $PScreds -wait -ArgumentList (" -command `"start-process powershell -wait -ArgumentList ' -File "+$StatusPath+"'`"")
            #Start-Process $filepath -Credential $PScreds -LoadUserProfile -wait -ArgumentList (" /install /quiet /log "+$cmsourcepath+"\install.log ADC_USERNAME="+$creds+" ADC_PASSWORD="+$admpass+" IT_SQL_SETTINGS_INITIALIZED=1 ADC_SQL_SERVER="+$sqlsrv+" ADC_SQL_DB_NAME=ITSS_AdcCfg ADC_SQL_TYPE=1 ADC_SQL_USERNAME="+$creds+" ADC_SQL_PASSWD="+$admpass+" IACCEPTSQLNCLILICENSETERMS=YES SIP_OPTIN=#0 MMWEBUI_PORT=`"443`" ALLOWUSAGEDATACOLLECTION=`"False`" INSTALL_ADC=#1")
            $output = Invoke-Command -ScriptBlock { 
                param($instpsmpath,$intrsrv,$usernm,$admpass,$cmsourcepath)
                Start-Process powershell -wait -verb runas -ArgumentList ("-File "+$instpsmpath)

    	    } -ArgumentList $StatusPath,$intrsrv,$usernm,$admpass,$cmsourcepath -ComputerName localhost -authentication credssp -Credential $PScreds -Verbose
            Write-output $output

		    $output = Invoke-Command -ScriptBlock { 
                param($instpsmpath,$intrsrv,$sqlsrv,$usernm,$admpass,$cmsourcepath)
                 $props = @{
                    'server'=$intrsrv
                    'user'=$usernm
                    'password'=$admpass
                    'selectedReps'=@(
                                            (New-Object -TypeName PSObject -Property @{'Name'='Default InTrust Audit Repository'})
                                    )
                }
                #cd "C:\Program Files\Quest\IT Security Search\Scripts\"
                
                add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
                [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
                $url="https://localhost/api/1.0/settings"
                $settings = Invoke-RestMethod -Method Get -Uri $url -UseDefaultCredentials -ContentType 'application/json'
                $connectors = $settings.connectors
                $connectors.PSObject.Properties.Remove('InTrust')
                $StatusPath = "$cmsourcepath\Installcmd.txt"
                $connectors >> $StatusPath
                $parameters = New-Object -TypeName PSObject -Property $props
                $newConnector = New-Object -TypeName PSObject -Property @{'active'='true';'parameters'=$parameters}

                Add-Member -InputObject $connectors -MemberType NoteProperty -Name 'InTrust' -Value $newConnector

                $json = ConvertTo-Json -InputObject $settings -Depth 10
                Invoke-RestMethod -Method Put -Uri $url -UseDefaultCredentials -Body $json
                #./Set-ItssConnectorSettings.ps1 -ComputerName localhost -ConnectorId 'InTrust' -Properties $props

                ls cert:\LocalMachine\My | ?{$_.Issuer -eq "CN="+$sqlsrv} | export-certificate -FilePath "$cmsourcepath\itss_cert.cer"
                Import-Certificate -FilePath "$cmsourcepath\itss_cert.cer" -CertStoreLocation Cert:\LocalMachine\Root

		    } -ArgumentList $StatusPath,$intrsrv,$sqlsrv,$usernm,$admpass,$cmsourcepath -ComputerName localhost -authentication credssp -Credential $PScreds -Verbose
  
		
    }

    [bool] Test()
    {
        $key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
        $subKey =  $key.OpenSubKey("SOFTWARE\Quest\IT Security Search")
        if($subKey)
        {
            if($subKey.GetValue('DllPath') -ne $null)
            {
                return $true
            }
        }
        return $false
    }

    [InstallITSS] Get()
    {
        return $this
    }
    
}


[DscResource()]
class InstallITSSUpdate
{
    [DscProperty(Key)]
    [string] $CM
	
	[DscProperty(Key)]
    [string] $AdminPass
	
    [DscProperty(Key)]
    [string] $DomainName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $Credential

	
	[DscProperty(Key)]
    [string] $PSName

    [DscProperty(Key)]
    [string] $INTRName
	
	[DscProperty(Key)]
    [string] $ScriptPath

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
		$_CM = $this.CM
		$_SP=$this.ScriptPath
		$usernm=$this.Credential.UserName
		$PScreds=$this.Credential
		$admpass=$this.AdminPass
		$sqlsrv=$this.PSName
        $intrsrv=$this.INTRName

        $cmsourcepath = "c:\$_CM"
		$creds=$usernm

        $output = Invoke-Command -ScriptBlock { 
        param($cmsourcepath)
        (ls $cmsourcepath) | %{Start-Process msiexec.exe -Wait -ArgumentList ('/I '+$cmsourcepath+'\'+$_.Name+' /quiet')}

    	} -ArgumentList $cmsourcepath -ComputerName localhost -authentication credssp -Credential $PScreds -Verbose
        Write-output $output

  
		
    }

    [bool] Test()
    {
        $key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
        $subKey =  $key.OpenSubKey("SOFTWARE\Quest\IT Security Search")
        if($subKey)
        {
            if($subKey.GetValue('DllPath') -ne $null)
            {
                return $true
            }
        }
        return $false
    }

    [InstallITSSUpdate] Get()
    {
        return $this
    }
    
}


[DscResource()]
class InstallInTrust
{
    [DscProperty(Key)]
    [string] $CM
	
	[DscProperty(Key)]
    [string] $AdminPass
	
    [DscProperty(Key)]
    [string] $DomainName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $Credential

	[DscProperty(Key)]
    [string] $MailFromAddress

	[DscProperty(Key)]
    [string] $DefaultOperatorAddress
	
	[DscProperty(Key)]
    [string] $PSName
	
	[DscProperty(Key)]
    [string] $ScriptPath

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
		$_CM = $this.CM
		$_SP=$this.ScriptPath
		$usernm=$this.Credential.UserName
		$PScreds=$this.Credential
		$admpass=$this.AdminPass
		$sqlsrv=$this.PSName
		$emailfrom = $this.MailFromAddress
		$emailto = $this.DefaultOperatorAddress
		$instpsmpath="$_SP\Installation.psm1"
		$instparpsmpath="$_SP\SetInstallationParameters.psm1"
        $cmpath = "c:\$_CM.exe"
        $cmsourcepath = "c:\$_CM"
		$creds=$usernm

		$output = Invoke-Command -ScriptBlock { 
			param($instpsmpath,$instparpsmpath,$admpass,$sqlsrv,$creds,$cmsourcepath,$_SP,$emailfrom,$emailto)
			$StatusPath = "$cmsourcepath\Installcmd.txt"
            "Started..." >> $StatusPath
			Import-Module $instpsmpath
			Import-Module $instparpsmpath

			

			$cmd="Initialize-EnvironmentVariables -commonPsw $admpass -sqlServer $sqlsrv -sqlReportServer $sqlsrv -serviceAccount $creds"
			Initialize-EnvironmentVariables -commonPsw $admpass -sqlServer $sqlsrv -sqlReportServer $sqlsrv -mailSender $emailfrom -operatorEmail $emailto -serviceAccount $creds
			$StatusPath = "$cmsourcepath\Installcmd.txt"
            $cmd >> $StatusPath
		
			Install-VCRedist -PackageRootPath $cmsourcepath
			Install-SQLNativeClient -PackageRootPath $cmsourcepath
			$cmd="Install-InTrustServer -PackageRootPath $cmsourcepath -username $usernm -Credential $PScreds"
			Install-InTrustServer -PackageRootPath $cmsourcepath
			$StatusPath = "$cmsourcepath\Installcmd.txt"
			    $cmd >> $StatusPath
			Install-InTrustManager -PackageRootPath $cmsourcepath

			Install-InTrustDeploymentManager -PackageRootPath $cmsourcepath
			Install-InTrustRV -PackageRootPath $cmsourcepath
			Install-InTrustDefaultKnowledgePacks -PackageRootPath $cmsourcepath
			Install-InTrustResourceKit -PackageRootPath $cmsourcepath
			
			Start-Process -Filepath ("$cmsourcepath\Update.exe") -ArgumentList (' /Q') -wait
			Start-Process -Filepath ("$cmsourcepath\QuestInTrust1141Update20200703.exe") -ArgumentList (' /Q') -wait
			#$cmd="Start-Process -Filepath ($_SP\NotifyThroughEventLog.exe) -ArgumentList (' -v') -wait"
			#$StatusPath = "$cmsourcepath\Installcmd.txt"
			#$cmd >> $StatusPath
			cd $_SP
			echo "yes" | .\NotifyThroughEventLog.exe #Start-Process -Filepath ("$_SP\NotifyThroughEventLog.exe") -ArgumentList (' -v') -wait
			
			$cmd="Install-InTrustLicense -LicenseFullName $cmsourcepath\License.asc"
			Install-InTrustLicense -LicenseFullName "$cmsourcepath\License.asc"
			$StatusPath = "$cmsourcepath\Installcmd.txt"
			    $cmd >> $StatusPath
			#(Get-Content -path "C:\Program Files (x86)\Quest\InTrust\Server\ADC\adctracer.ini" -Raw) -replace '#TaskScheduler=40','TaskScheduler=40' | set-content -path "C:\Program Files (x86)\Quest\InTrust\Server\ADC\adctracer.ini" -Force	
			
			# Changing org parameters
			$PDOImportTool = Get-ChildItem -Path ${env:ProgramFiles(x86)} -Filter "InTrustPDOImport.exe" -Recurse -ErrorAction Ignore
			$OrgParamsPath = "$_SP\"
			Get-ChildItem -Path $OrgParamsPath | ?{$_.Name -like "*.xml"} | ForEach-Object { Start-Process -File $PDOImportTool.FullName -ArgumentList (' -import "' + $_.FullName +'"') -Wait -NoNewWindow }

					$cfgBrowserDll = gci ${env:ProgramFiles(x86)} -Filter Quest.InTrust.ConfigurationBrowser.dll -Recurse -ErrorAction Ignore

					[Reflection.Assembly]::LoadFrom($cfgBrowserDll.FullName) | Out-Null

					$cfgBrowser = New-Object Quest.InTrust.ConfigurationBrowser.InTrustConfigurationBrowser($false)

					$cfgBrowser.ConnectLocal()
					$currentName = "AllDomainAllLogs"
					$collection = $cfgBrowser.Configuration.Collections.AddCollection([Guid]::NewGuid(),$currentName)
					$collection.IsEnabled = $true
					$collection.RepositoryId = $cfgBrowser.Configuration.DataStorages.GetDefaultRepository().Guid
					$rtcSite = $cfgBrowser.Configuration.Sites.AddRtcSite($currentName)
					$collection.AddSiteReference($rtcSite.Guid)
					$rtcSite.AddDomain([Guid]::NewGuid(),$env:USERDNSDOMAIN,$false)
					$rtcSite.OwnerServerId = $cfgBrowser.GetServer().Guid
					$rtcSite.Update()
					$cfgBrowser.Configuration.DataSources.ListDataSources() | ?{$_.ProviderID -eq 'a9e5c7a2-5c01-41b7-9d36-e562dfddefa9' -and $_.Name -notlike "*Change Auditor*" -and $_.Name -notlike "*Active Roles*"} | %{$collection.AddDataSourceReference($_.Guid)}
					$cfgBrowser.Configuration.DataSources.ListDataSources() | ?{$_.ProviderID -eq '5115b8aa-29ae-4c6d-ae14-0bb7521e10fb'} | %{$collection.AddDataSourceReference($_.Guid)}
					$cfgBrowser.Configuration.DataSources.ListDataSources() | ?{$_.Name -eq 'Detection Lab Microsoft ETW Log'} | %{$collection.AddDataSourceReference($_.Guid)}

#                    if(($cfgBrowser.Configuration.DataSources.ListDataSources()|?{$_.LogName -like '*ETW*'}) -eq $null)
#                    {
#                        $dataSource = $cfgBrowser.Configuration.DataSources.AddWinEvtDataSource("InTrust-ATC")
#                        $dataSource.LogName = "InTrust-ATC"
#                        $dataSource.Update()
#                        $collection.AddDataSourceReference($dataSource.Guid)
#                    }

                    if(($cfgBrowser.Configuration.DataSources.ListDataSources()|?{$_.LogName -like '*Sysmon*'}) -eq $null)
                    {
                        $dataSource = $cfgBrowser.Configuration.DataSources.AddWinEvtDataSource("Microsoft-Windows-Sysmon/Operational")
                        $dataSource.LogName = "Microsoft-Windows-Sysmon/Operational"
                        $dataSource.Update()
                        $collection.AddDataSourceReference($dataSource.Guid)
                    }
#                    if(($cfgBrowser.Configuration.DataSources.ListDataSources()|?{$_.LogName -like '*SilkService-Log*'}) -eq $null)
#                    {
#                        $dataSource = $cfgBrowser.Configuration.DataSources.AddWinEvtDataSource("SilkService-Log")
#                        $dataSource.LogName = "SilkService-Log"
#                        $dataSource.Update()
#                        $collection.AddDataSourceReference($dataSource.Guid)
#                    }


					$collection.Update()
					$collection.Dispose();$rtcSite.Dispose();
					
					$site = $cfgBrowser.Configuration.Sites.ListSites() | ? {$_.Name -like "All Windows servers"}

					$site.AddDomain([Guid]::NewGuid(),$env:USERDNSDOMAIN,$false)
					$site.Update() 
					$site = $cfgBrowser.Configuration.Sites.ListSites() | ? {$_.Name -like "All workstations"}

					$site.AddDomain([Guid]::NewGuid(),$env:USERDNSDOMAIN,$false)
					$site.Update() 

					$site = $cfgBrowser.Configuration.Sites.ListSites() | ? {$_.Name -like "Redhat*"}

					$site.AddComputer([Guid]::NewGuid(),"sgazlabcl02.internal.cloudapp.net",$false)
					$site.Update() 
					
                    $task=$cfgBrowser.Configuration.Children["ADCTasks"].Children | ?{$_.Name -like "Redhat Linux Daily*"}
                    $task.Properties["Enabled"].Value=1
                    $task.Update()
                    $adctask=$cfgBrowser.Configuration.Children["ITGCTasks"].Children | ?{$_.Properties["Guid"].Value -eq '{26F70CB0-BD7F-4498-8C1E-AADCEACB15E3}'}
                    $adctask.Properties["Policy"].Value='{B76D9201-6ECA-451A-9823-404B86EC2780}'
                    $adctask.Properties["Storages"].Value.Remove($adctask.Properties["Storages"].Value.Item(2),$false)
                    $adctask.Update()

					$_Policies = $cfgBrowser.Configuration.Children["ITRTPolicies"].Children

					foreach($_Policy in $_Policies)
					{
						$notifications = $_Policy.Properties["Notifications"].Value
						$notification = $notifications.Add("ITRTNotification",$false)
     
						$notification.Properties["NotificationType"].Value = "{976ACA10-0476-4288-A96E-BCC8D0A4D154}"      
						$notification.Properties["Enabled"].Value = 1
						$op=$cfgBrowser.Configuration.Children["ADCNotificationOperators"].Children | ?{$_.Name -eq "Event Log Recipient"}
						$recipient = $notification.Properties["Recipients"].Value.Add("ITRTNotificationRecipient",$false)
						$recipient.Properties["RecipientGuid"].Value = $op.Guid.ToString("B")
						$recipient.Update()

						$notification.Update()
					}
					$rulegroup1=$cfgBrowser.Configuration.Children["ITRTProcessingRuleGroups"].Children | ?{$_.Name -like "Windows*"}
					$rulegroup2=($cfgBrowser.Configuration.Children["ITRTProcessingRuleGroups"].Children | ?{$_.Name -like "Advanced*"}).Children | ?{$_.Name -like "Windows*"}
                    $rulegroup3=$cfgBrowser.Configuration.Children["ITRTProcessingRuleGroups"].Children | ?{$_.Name -like "Redhat*"}					
   					$rulegroup4=($cfgBrowser.Configuration.Children["ITRTProcessingRuleGroups"].Children | ?{$_.Name -like "Advanced*"}).Children | ?{$_.Name -like "Linux*"}
                    Add-SiteToPolicy -SiteName "All workstations" -PolicyName "Windows/AD Security: full"
					Enable-Policy -PolicyName "Windows/AD Security: full" -Yes
                    Enable-Policy -PolicyName "Redhat Linux: security" -Yes
					List-Rules -Group $rulegroup1 | %{Enable-Rule -RuleName $_.Name -Yes -NoEventsSQL}
					List-Rules -Group $rulegroup2 | %{Enable-Rule -RuleName $_.Name -Yes -NoEventsSQL}
                    List-Rules -Group $rulegroup3 | %{Enable-Rule -RuleName $_.Name -Yes -NoEventsSQL}
                    List-Rules -Group $rulegroup4 | %{Enable-Rule -RuleName $_.Name -Yes -NoEventsSQL}
		} -ArgumentList $instpsmpath,$instparpsmpath,$admpass,$sqlsrv,$creds,$cmsourcepath,$_SP,$emailfrom,$emailto -ComputerName localhost -authentication credssp -Credential $PScreds -ConfigurationName microsoft.powershell32 -Verbose
        Write-output $output

		
		
    }

    [bool] Test()
    {
        $key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
        $subKey =  $key.OpenSubKey("SOFTWARE\Aelita\ADC\Server")
        if($subKey)
        {
            if($subKey.GetValue('LocalServerID') -ne $null)
            {
                return $true
            }
        }
        return $false
    }

    [InstallInTrust] Get()
    {
        return $this
    }
    
}

[DscResource()]
class WriteConfigurationFile
{
    [DscProperty(Key)]
    [string] $Role

    [DscProperty(Mandatory)]
    [string] $LogPath

    [DscProperty(Key)]
    [string] $WriteNode

    [DscProperty(Mandatory)]
    [string] $Status

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_Role = $this.Role
        $_Node = $this.WriteNode
        $_Status = $this.Status
        $_NoChildNode = $this.NoChildNode
        $_LogPath = $this.LogPath
        $ConfigurationFile = Join-Path -Path $_LogPath -ChildPath "$_Role.json"
        $Configuration = Get-Content -Path $ConfigurationFile | ConvertFrom-Json

        $Configuration.$_Node.Status = $_Status
        $Configuration.$_Node.EndTime = Get-Date -format "yyyy-MM-dd HH:mm:ss"
        
        $Configuration | ConvertTo-Json | Out-File -FilePath $ConfigurationFile -Force
    }

    [bool] Test()
    {
        $_Role = $this.Role
        $_LogPath = $this.LogPath
        $Configuration = ""
        $ConfigurationFile = Join-Path -Path $_LogPath -ChildPath "$_Role.json"
        if (Test-Path -Path $ConfigurationFile) 
        {
            $Configuration = Get-Content -Path $ConfigurationFile | ConvertFrom-Json
        } 
        else 
        {
            [hashtable]$Actions = @{
                PSJoinDomain = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
                INTRJoinDomain = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
                ClientJoinDomain = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
                DelegateControl = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
                SCCMinstall = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
                INTRFinished = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
                ClientFinished = @{
                    Status = 'NotStart'
                    StartTime = ''
                    EndTime = ''
                }
            }
            $Configuration = New-Object -TypeName psobject -Property $Actions
            $Configuration | ConvertTo-Json | Out-File -FilePath $ConfigurationFile -Force
        }
        
        return $false
    }

    [WriteConfigurationFile] Get()
    {
        return $this
    }
}

[DscResource()]
class WaitForConfigurationFile
{
    [DscProperty(Key)]
    [string] $Role

    [DscProperty(Key)]
    [string] $MachineName

    [DscProperty(Mandatory)]
    [string] $LogFolder

    [DscProperty(Key)]
    [string] $ReadNode

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_Role = $this.Role
        $_FilePath = "\\$($this.MachineName)\$($this.LogFolder)"
        $ConfigurationFile = Join-Path -Path $_FilePath -ChildPath "$_Role.json"
        
        while(!(Test-Path $ConfigurationFile))
        {
            Write-Verbose "Wait for configuration file exist on $($this.MachineName), will try 60 seconds later..."
            Start-Sleep -Seconds 60
            $ConfigurationFile = Join-Path -Path $_FilePath -ChildPath "$_Role.json"
        }
        $Configuration = Get-Content -Path $ConfigurationFile -ErrorAction Ignore | ConvertFrom-Json
        while($Configuration.$($this.ReadNode).Status -ne "Passed")
        {
            Write-Verbose "Wait for step : [$($this.ReadNode)] finsihed on $($this.MachineName), will try 60 seconds later..."
            Start-Sleep -Seconds 60
            $Configuration = Get-Content -Path $ConfigurationFile | ConvertFrom-Json
        }
    }

    [bool] Test()
    {
        return $false
    }

    [WaitForConfigurationFile] Get()
    {
        return $this
    }
}

[DscResource()]
class WaitForExtendSchemaFile
{
    [DscProperty(Key)]
    [string] $MachineName

    [DscProperty(Mandatory)]
    [string] $ExtFolder

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_FilePath = "\\$($this.MachineName)\$($this.ExtFolder)"
        $extadschpath = Join-Path -Path $_FilePath -ChildPath "SMSSETUP\BIN\X64\extadsch.exe"
        
        while(!(Test-Path $extadschpath))
        {
            Write-Verbose "Wait for extadsch.exe exist on $($this.MachineName), will try 10 seconds later..."
            Start-Sleep -Seconds 10
            $extadschpath = Join-Path -Path $_FilePath -ChildPath "SMSSETUP\BIN\X64\extadsch.exe"
        }

        Write-Verbose "Extended the Active Directory schema..."

        & $extadschpath | out-null

        Write-Verbose "Done."
    }

    [bool] Test()
    {
        return $false
    }

    [WaitForExtendSchemaFile] Get()
    {
        return $this
    }
}

[DscResource()]
class DelegateControl
{
    [DscProperty(Key)]
    [string] $Machine

    [DscProperty(Mandatory)]
    [string] $DomainFullName

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $root = (Get-ADRootDSE).defaultNamingContext
        $ou = $null 
        try 
        { 
            $ou = Get-ADObject "CN=System Management,CN=System,$root"
        } 
        catch 
        { 
            Write-Verbose "System Management container does not currently exist."
        }
        if ($ou -eq $null) 
        { 
            $ou = New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru 
        }
        $DomainName = $this.DomainFullName.split('.')[0]
        #Delegate Control
        $cmd = "dsacls.exe"
        $arg1 = "CN=System Management,CN=System,$root"
        $arg2 = "/G"
        $arg3 = ""+$DomainName+"\"+$this.Machine+"`$:GA;;"
        $arg4 = "/I:T"

        & $cmd $arg1 $arg2 $arg3 $arg4
    }

    [bool] Test()
    {
        $_machinename = $this.Machine
        $root = (Get-ADRootDSE).defaultNamingContext
        try 
        { 
            $ou = Get-ADObject "CN=System Management,CN=System,$root"
        } 
        catch 
        { 
            Write-Verbose "System Management container does not currently exist."
            return $false
        }

        $cmd = "dsacls.exe"
        $arg1 = "CN=System Management,CN=System,$root"
        $permissioninfo = & $cmd $arg1

        if(($permissioninfo | ?{$_ -like "*$_machinename*"} | ?{$_ -like "*FULL CONTROL*"}).COUNT -gt 0)
        {
            return $true
        }

        return $false
    }

    [DelegateControl] Get()
    {
        return $this
    }
}


[DscResource()]
class AddBuiltinPermission
{
    [DscProperty(key)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        Start-Sleep -Seconds 240
        sqlcmd -Q "if not exists(select * from sys.server_principals where name='BUILTIN\administrators') CREATE LOGIN [BUILTIN\administrators] FROM WINDOWS;EXEC master..sp_addsrvrolemember @loginame = N'BUILTIN\administrators', @rolename = N'sysadmin'"
        $retrycount = 0
        $sqlpermission = sqlcmd -Q "if exists(select * from sys.server_principals where name='BUILTIN\administrators') Print 1"
        while($sqlpermission -eq $null)
        {
            if($retrycount -eq 3)
            {
                $sqlpermission = 1
            }
            else
            {
                $retrycount++
                Start-Sleep -Seconds 240
                sqlcmd -Q "if not exists(select * from sys.server_principals where name='BUILTIN\administrators') CREATE LOGIN [BUILTIN\administrators] FROM WINDOWS;EXEC master..sp_addsrvrolemember @loginame = N'BUILTIN\administrators', @rolename = N'sysadmin'"
                $sqlpermission = sqlcmd -Q "if exists(select * from sys.server_principals where name='BUILTIN\administrators') Print 1"
            }
        }
    }

    [bool] Test()
    {
        $sqlpermission = sqlcmd -Q "if exists(select * from sys.server_principals where name='BUILTIN\administrators') Print 1"
        if($sqlpermission -eq $null)
        {
            Write-Verbose "Need to add the builtin administrators permission."
            return $false
        }
        Write-Verbose "No need to add the builtin administrators permission."
        return $true
    }

    [AddBuiltinPermission] Get()
    {
        return $this
    }
}

[DscResource()]
class DownloadSCCM
{
    [DscProperty(Key)]
    [string] $CM

    [DscProperty(Mandatory)]
    [string] $ExtPath
	
	[DscProperty(Key)]
    [string] $IntrUrl

	[DscProperty(Key)]
    [string] $IntrUpdateUrl

	[DscProperty(Key)]
    [string] $IntrLicUrl
	
	[DscProperty(Key)]
    [string] $ETWUrl

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_CM = $this.CM
        $_ExtPath = $this.ExtPath
        $cmpath = "c:\$_CM.exe"
        $cmsourcepath = "c:\$_CM"

        Write-Verbose "Downloading InTrust installation source..."
        $cmurl = $this.IntrUrl
		$cmlicurl = $this.IntrLicUrl
		$cmupdateurl = $this.IntrUpdateUrl
		$cmetwurl = $this.ETWUrl
        Invoke-WebRequest -Uri $cmurl -OutFile $cmpath
        if(!(Test-Path $cmsourcepath))
        {
            Start-Process -Filepath ($cmpath) -ArgumentList ('-y -o"' + $cmsourcepath + '"') -wait
        }
		$cmupdatepath = "$cmsourcepath\Update.exe"
		Invoke-WebRequest -Uri $cmupdateurl -OutFile $cmupdatepath
		$cmetwpath = "$cmsourcepath\ETW.zip"
		Invoke-WebRequest -Uri $cmetwurl -OutFile $cmetwpath
			expand-archive -path $cmetwpath -DestinationPath $cmsourcepath
		$cmlicpath = "$cmsourcepath\License.asc"
		Invoke-WebRequest -Uri $cmlicurl -OutFile $cmlicpath
    }

    [bool] Test()
    {
        $_CM = $this.CM
        $cmpath = "c:\$_CM.exe"
        $cmsourcepath = "c:\$_CM"
        if(!(Test-Path $cmpath))
        {
            return $false
        }

        return $true
    }

    [DownloadSCCM] Get()
    {
        return $this
    }
}

[DscResource()]
class DownloadITSS
{
    [DscProperty(Key)]
    [string] $CM

    [DscProperty(Mandatory)]
    [string] $ExtPath
	
	[DscProperty(Key)]
    [string] $ITSSUrl

	[DscProperty(Key)]
    [string] $ITSSUpdateUrl

	[DscProperty(Key)]
    [string] $ITSSLicUrl

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_CM = $this.CM
        $_ExtPath = $this.ExtPath
        $cmpath = "c:\$_CM.zip"
        $cmsourcepath = "c:\$_CM"
        $_ITSSUpdateUrl=$this.ITSSUpdateUrl

        Write-Verbose "Downloading ITSS installation source..."
        $cmurl = $this.ITSSUrl
		$cmlicurl = $this.ITSSLicUrl
		$cmupdateurl = $this.ITSSUpdateUrl
        Invoke-WebRequest -Uri $cmurl -OutFile $cmpath


        if(!(Test-Path $cmsourcepath))
        {
            Expand-Archive -LiteralPath $cmpath -DestinationPath ($cmsourcepath + '2') -Force
            $itsspath=$cmsourcepath + '2\Web\Full'
            $itssprogname=(ls $itsspath).Name
            Start-Process -Filepath ($itsspath + '\' + $itssprogname) -ArgumentList ('-y -o"' + $cmsourcepath + '"') -wait
        }

        if($_ITSSUpdateUrl)
        {
            $updatefile=$cmsourcepath+'_Update.exe'
            Invoke-WebRequest -Uri $_ITSSUpdateUrl -OutFile $updatefile
            Start-Process -Filepath ($updatefile) -ArgumentList ('-y -o"' + $cmsourcepath + '_U"') -wait
        }

    }

    [bool] Test()
    {
        $_CM = $this.CM
        $cmpath = "c:\$_CM.zip"
        $cmsourcepath = "c:\$_CM"
        if(!(Test-Path $cmpath))
        {
            return $false
        }

        return $true
    }

    [DownloadITSS] Get()
    {
        return $this
    }
}




[DscResource()]
class DownloadAndRunETW
{
    [DscProperty(Key)]
    [string] $CM

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $cmurl = "https://www.dropbox.com/s/75k0y50i6s7hhld/ETWReader.zip?dl=1"
        Invoke-WebRequest -Uri $cmurl -OutFile "c:\ETWReader.zip"
        Expand-Archive -LiteralPath "c:\ETWReader.zip" -DestinationPath "c:\"
        Start-Process -Filepath ("c:\ETWReader\ETWReader.exe") -WorkingDirectory "c:\ETWReader"
    }

    [bool] Test()
    {

        if(!(Test-Path "c:\ETWReader"))
        {
            return $false
        }

        return $true
    }

    [DownloadAndRunETW] Get()
    {
        return $this
    }
}

[DscResource()]
class DownloadAndRunSysmon
{
    [DscProperty(Key)]
    [string] $CM

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $cmurl = "https://live.sysinternals.com/Sysmon64.exe"
        Invoke-WebRequest -Uri $cmurl -OutFile "c:\Sysmon64.exe"
        #Expand-Archive -LiteralPath "c:\ETWReader.zip" -DestinationPath "c:\"
        Start-Process -Filepath ("c:\Sysmon64.exe") -ArgumentList ('-accepteula -i -n')
    }

    [bool] Test()
    {

        if(!(Test-Path "c:\Sysmon64.exe"))
        {
            return $false
        }

        return $true
    }

    [DownloadAndRunSysmon] Get()
    {
        return $this
    }
}

[DscResource()]
class DownloadAndRunSilkETW
{
    [DscProperty(Key)]
    [string] $CM

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $cmurl = "https://github.com/fireeye/SilkETW/releases/download/v0.8/SilkETW_SilkService_v8.zip"
        Invoke-WebRequest -Uri $cmurl -OutFile "c:\SilkETW.zip"
        Expand-Archive -LiteralPath "c:\SilkETW.zip" -DestinationPath "c:\SilkETW"
        $cmurl = "https://github.com/hunters-forge/Blacksmith/raw/master/aws/mordor/cfn-files/configs/erebor/erebor_SilkServiceConfig.xml"
        Invoke-WebRequest -Uri $cmurl -OutFile "C:\SilkETW\v8\SilkService\SilkServiceConfig.xml"
        Start-Process -Filepath ("sc") -ArgumentList ('create SilkService binPath= "C:\SilkETW\v8\SilkService\SilkService.exe" start= delayed-auto')
    }

    [bool] Test()
    {

        if(!(get-service "SilkService" -ErrorAction SilentlyContinue))
        {
            return $false
        }

        return $true
    }

    [DownloadAndRunSilkETW] Get()
    {
        return $this
    }
}

[DscResource()]
class StartSilkETW
{
    [DscProperty(Key)]
    [string] $CM

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $query = "Name = 'SilkService'"
        $services = Get-WmiObject win32_service -Filter $query
        $services.StartService()
    }

    [bool] Test()
    {

        if(!((get-service "SilkService" -ErrorAction SilentlyContinue).Status -eq "Running"))
        {
            return $false
        }

        return $true
    }

    [StartSilkETW] Get()
    {
        return $this
    }
}

[DscResource()]
class InstallDP
{
    [DscProperty(key)]
    [string] $SiteCode

    [DscProperty(Mandatory)]
    [string] $DomainFullName

    [DscProperty(Mandatory)]
    [string] $INTRName
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $ProviderMachineName = $env:COMPUTERNAME+"."+$this.DomainFullName # SMS Provider machine name

        # Customizations
        $initParams = @{}
        if($ENV:SMS_ADMIN_UI_PATH -eq $null)
        {
            $ENV:SMS_ADMIN_UI_PATH = "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\i386"
        }

        # Import the ConfigurationManager.psd1 module 
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
        }

        # Connect to the site's drive if it is not already present
        Write-Verbose "Setting PS Drive..."

        New-PSDrive -Name $this.SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
        while((Get-PSDrive -Name $this.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) 
        {
            Write-Verbose "Failed ,retry in 10s. Please wait."
            Start-Sleep -Seconds 10
            New-PSDrive -Name $this.SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
        }

        # Set the current location to be the site code.
        Set-Location "$($this.SiteCode):\" @initParams

        $DPServerFullName = $this.INTRName + "." + $this.DomainFullName
        if($(Get-CMSiteSystemServer -SiteSystemServerName $DPServerFullName) -eq $null)
        {
            New-CMSiteSystemServer -Servername $DPServerFullName -Sitecode $this.SiteCode
        }

        $Date = [DateTime]::Now.AddYears(10)
        Add-CMDistributionPoint -SiteSystemServerName $DPServerFullName -SiteCode $this.SiteCode -CertificateExpirationTimeUtc $Date
    }

    [bool] Test()
    {
        return $false
    }

    [InstallDP] Get()
    {
        return $this
    }
}

[DscResource()]
class InstallMP
{
    [DscProperty(key)]
    [string] $SiteCode

    [DscProperty(Mandatory)]
    [string] $DomainFullName

    [DscProperty(Mandatory)]
    [string] $INTRName
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $ProviderMachineName = $env:COMPUTERNAME+"."+$this.DomainFullName # SMS Provider machine name
        # Customizations
        $initParams = @{}
        if($ENV:SMS_ADMIN_UI_PATH -eq $null)
        {
            $ENV:SMS_ADMIN_UI_PATH = "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\i386"
        }

        # Import the ConfigurationManager.psd1 module 
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
        }

        # Connect to the site's drive if it is not already present
        Write-Verbose "Setting PS Drive..."

        New-PSDrive -Name $this.SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
        while((Get-PSDrive -Name $this.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) 
        {
            Write-Verbose "Failed ,retry in 10s. Please wait."
            Start-Sleep -Seconds 10
            New-PSDrive -Name $this.SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
        }

        # Set the current location to be the site code.
        Set-Location "$($this.SiteCode):\" @initParams

        $MPServerFullName = $this.INTRName + "." + $this.DomainFullName
        if(!(Get-CMSiteSystemServer -SiteSystemServerName $MPServerFullName))
        {
            Write-Verbose "Creating cm site system server..."
            New-CMSiteSystemServer -SiteSystemServerName $MPServerFullName
            Write-Verbose "Finished creating cm site system server."
            $SystemServer = Get-CMSiteSystemServer -SiteSystemServerName $MPServerFullName
            Write-Verbose "Adding management point on $MPServerFullName ..."
            Add-CMManagementPoint -InputObject $SystemServer -CommunicationType Http
            Write-Verbose "Finished adding management point on $MPServerFullName ..."
        }
        else
        {
            Write-Verbose "$MPServerFullName is already a Site System Server , skip running this script."
        }
    }

    [bool] Test()
    {
        return $false
    }

    [InstallMP] Get()
    {
        return $this
    }
}

[DscResource()]
class WaitForDomainReady
{
    [DscProperty(key)]
    [string] $DCName

    [DscProperty(Mandatory=$false)]
    [int] $WaitSeconds = 900

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_DCName = $this.DCName
        $_WaitSeconds = $this.WaitSeconds
        Write-Verbose "Domain computer is: $_DCName"
        $testconnection = test-connection -ComputerName $_DCName -ErrorAction Ignore
        while(!$testconnection)
        {
            Write-Verbose "Waiting for Domain ready , will try again 30 seconds later..."
            Start-Sleep -Seconds 30
            $testconnection = test-connection -ComputerName $_DCName -ErrorAction Ignore
        }
        Write-Verbose "Domain is ready now."
    }

    [bool] Test()
    {
         $_DCName = $this.DCName
        Write-Verbose "Domain computer is: $_DCName"
        $testconnection = test-connection -ComputerName $_DCName -ErrorAction Ignore

        if(!$testconnection)
        {
            return $false
        }
        return $true
    }

    [WaitForDomainReady] Get()
    {
        return $this
    }
}

[DscResource()]
class VerifyComputerJoinDomain
{
    [DscProperty(key)]
    [string] $ComputerName

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_Computername = $this.ComputerName
        $searcher = [adsisearcher] "(cn=$_Computername)"
        while($searcher.FindAll().count -ne 1)
        {
            Write-Verbose "$_Computername not join into domain yet , will search again after 1 min"
            Start-Sleep -Seconds 60
            $searcher = [adsisearcher] "(cn=$_Computername)"
        }
        Write-Verbose "$_Computername joined into the domain."
    }

    [bool] Test()
    {
        return $false
    }

    [VerifyComputerJoinDomain] Get()
    {
        return $this
    }
}

[DscResource()]
class SetDNS
{
    [DscProperty(key)]
    [string] $DNSIPAddress

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_DNSIPAddress = $this.DNSIPAddress
        $dnsset = Get-DnsClientServerAddress | %{$_ | ?{$_.InterfaceAlias.StartsWith("Ethernet") -and $_.AddressFamily -eq 2}}
        Write-Verbose "Set dns: $_DNSIPAddress for $($dnsset.InterfaceAlias)"
        Set-DnsClientServerAddress -InterfaceIndex $dnsset.InterfaceIndex -ServerAddresses $_DNSIPAddress
    }

    [bool] Test()
    {
        $_DNSIPAddress = $this.DNSIPAddress
        $dnsset = Get-DnsClientServerAddress | %{$_ | ?{$_.InterfaceAlias.StartsWith("Ethernet") -and $_.AddressFamily -eq 2}}
        if($dnsset.ServerAddresses -contains $_DNSIPAddress)
        {
            return $true
        }
        return $false
    }

    [SetDNS] Get()
    {
        return $this
    }
}

[DscResource()]
class ChangeSQLServicesAccount
{
    [DscProperty(key)]
    [string] $SQLInstanceName

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_SQLInstanceName = $this.SQLInstanceName
        $query = "Name = '"+ $_SQLInstanceName.ToUpper() +"'"
        $services = Get-WmiObject win32_service -Filter $query

        if($services.State -eq 'Running')
        {
            #Check if SQLSERVERAGENT is running
            $sqlserveragentflag = 0
            $sqlserveragentservices = Get-WmiObject win32_service -Filter "Name = 'SQLSERVERAGENT'"
            if($sqlserveragentservices -ne $null)
            {
                if($sqlserveragentservices.State -eq 'Running')
                {
                    Write-Verbose "[$(Get-Date -format HH:mm:ss)] SQLSERVERAGENT need to be stopped first"
                    $Result = $sqlserveragentservices.StopService()
                    Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopping SQLSERVERAGENT.."
                    if ($Result.ReturnValue -eq '0')
                    {
                        $sqlserveragentflag = 1
                        Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopped"
                    }
                }
            }
            $Result = $services.StopService()
            Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopping SQL Server services.."
            if ($Result.ReturnValue -eq '0')
            {
                Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopped"
            }

            Write-Verbose "[$(Get-Date -format HH:mm:ss)] Changing the services account..."
            
            $Result = $services.change($null,$null,$null,$null,$null,$null,"LocalSystem",$null,$null,$null,$null) 
            if ($Result.ReturnValue -eq '0')
            {
                Write-Verbose "[$(Get-Date -format HH:mm:ss)] Successfully Change the services account"
                if($sqlserveragentflag -eq 1)
                {
                    Write-Verbose "[$(Get-Date -format HH:mm:ss)] Starting SQLSERVERAGENT.."
                    $Result = $sqlserveragentservices.StartService()
                    if($Result.ReturnValue -eq '0')
                    {
                        Write-Verbose "[$(Get-Date -format HH:mm:ss)] Started"
                    }
                }
                $Result =  $services.StartService()
                Write-Verbose "[$(Get-Date -format HH:mm:ss)] Starting SQL Server services.."
                while($Result.ReturnValue -ne '0') 
                {
                    $returncode = $Result.ReturnValue
                    Write-Verbose "[$(Get-Date -format HH:mm:ss)] Return $returncode , will try again"
                    Start-Sleep -Seconds 10
                    $Result =  $services.StartService()
                }
                Write-Verbose "[$(Get-Date -format HH:mm:ss)] Started"
            }
        }
    }

    [bool] Test()
    {
        $_SQLInstanceName = $this.SQLInstanceName
        $query = "Name = '"+ $_SQLInstanceName.ToUpper() +"'"
        $services = Get-WmiObject win32_service -Filter $query

        if($services -ne $null)
        {
            if($services.StartName -ne "LocalSystem")
            {
                return $false
            }
            else
            {
                return $true
            }
        }

        return $true
    }

    [ChangeSQLServicesAccount] Get()
    {
        return $this
    }
}

[DscResource()]
class RegisterTaskScheduler
{
    [DscProperty(key)]
    [string] $TaskName

    [DscProperty(Mandatory)]
    [string] $ScriptName

    [DscProperty(Mandatory)]
    [string] $ScriptPath
    
    [DscProperty(Mandatory)]
    [string] $ScriptArgument
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
	
#	[DscProperty(Mandatory)]
#    [System.Management.Automation.PSCredential] $Credential


    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_ScriptName = $this.ScriptName
        $_ScriptPath = $this.ScriptPath
        $_ScriptArgument = $this.ScriptArgument

        $ProvisionToolPath = "$env:windir\temp\ProvisionScript"
        if(!(Test-Path $ProvisionToolPath))
        {
            New-Item $ProvisionToolPath -ItemType directory | Out-Null
        }

        $sourceDirctory = "$_ScriptPath\*"
        $destDirctory = "$ProvisionToolPath\"
        
        Copy-item -Force -Recurse $sourceDirctory -Destination $destDirctory

        $_TaskName = $this.TaskName
        $TaskDescription = "Azure template task"
        $TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
        $TaskScript = "$ProvisionToolPath\$_ScriptName"

        Write-Verbose "Task script full path is : $TaskScript "

        $TaskArg = "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -file $TaskScript $_ScriptArgument"

        Write-Verbose "command is : $TaskArg"

        $TaskStartTime = [datetime]::Now.AddMinutes(5)
        $service = new-object -ComObject("Schedule.Service")
        $service.Connect()
        $rootFolder = $service.GetFolder("\")
        $TaskDefinition = $service.NewTask(0)
        $TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
        $TaskDefinition.Settings.Enabled = $true
        $TaskDefinition.Settings.AllowDemandStart = $true
        $triggers = $TaskDefinition.Triggers
        #http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
        $trigger = $triggers.Create(1)
        $trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
        $trigger.Enabled = $true
        # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
        $Action = $TaskDefinition.Actions.Create(0)
        $action.Path = "$TaskCommand"
        $action.Arguments = "$TaskArg"
        #http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
        $rootFolder.RegisterTaskDefinition("$_TaskName",$TaskDefinition,6,"System",$null,5)
    }

    [bool] Test()
    {
        $ProvisionToolPath = "$env:windir\temp\ProvisionScript"
        if(!(Test-Path $ProvisionToolPath))
        {
            return $false
        }
        
        return $true
    }

    [RegisterTaskScheduler] Get()
    {
        return $this
    }
}

[DscResource()]
class SetAutomaticManagedPageFile
{
    [DscProperty(key)]
    [string] $TaskName
    
    [DscProperty(Mandatory)]
    [bool] $Value

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_Value = $this.Value
        $computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
        Write-Verbose "Set AutomaticManagedPagefile to $_Value..."
        $computersys.AutomaticManagedPagefile = $_Value
        $computersys.Put()
    }

    [bool] Test()
    {
        $_Value = $this.Value
        $computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges;
        if($computersys.AutomaticManagedPagefile -ne $_Value)
        {
            return $false
        }
        
        return $true
    }

    [SetAutomaticManagedPageFile] Get()
    {
        return $this
    }
}

[DscResource()]
class ChangeServices
{
    [DscProperty(key)]
    [string] $Name
    
    [DscProperty(Mandatory)]
    [StartupType] $StartupType

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_Name = $this.Name
        $_StartupType = $this.StartupType
        sc.exe config $_Name start=$_StartupType | Out-Null
    }

    [bool] Test()
    {
        $_Name = $this.Name
        $_StartupType = $this.StartupType
        $currentstatus = sc.exe qc $_Name

        switch($_StartupType)
        {
            "auto" {
                if($currentstatus[4].contains("DELAYED"))
                {
                    return $false
                }
                break
            }
            "delayedauto"{
                if(!($currentstatus[4].contains("DELAYED")))
                {
                    return $false
                }
                break
            }
            "demand"{
                if(!($currentstatus[4].contains("DEMAND_START")))
                {
                    return $false
                }
                break
            }
        }
        
        return $true
    }

    [ChangeServices] Get()
    {
        return $this
    }
}

[DscResource()]
class AddUserToLocalAdminGroup
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Key)]
    [string] $DomainName

    [void] Set()
    {
        $_DomainName = $($this.DomainName).Split(".")[0]
        $_Name = $this.Name
        $AdminGroupName = (Get-WmiObject -Class Win32_Group -Filter 'LocalAccount = True AND SID = "S-1-5-32-544"').Name
        $GroupObj = [ADSI]"WinNT://$env:COMPUTERNAME/$AdminGroupName"
        Write-Verbose "[$(Get-Date -format HH:mm:ss)] add $_Name to administrators group"
        $GroupObj.Add("WinNT://$_DomainName/$_Name")
        
    }

    [bool] Test()
    {
        $_DomainName = $($this.DomainName).Split(".")[0]
        $_Name = $this.Name
        $AdminGroupName = (Get-WmiObject -Class Win32_Group -Filter 'LocalAccount = True AND SID = "S-1-5-32-544"').Name
        $GroupObj = [ADSI]"WinNT://$env:COMPUTERNAME/$AdminGroupName"
        if($GroupObj.IsMember("WinNT://$_DomainName/$_Name") -eq $true)
        {
            return $true
        }
        return $false
    }

    [AddUserToLocalAdminGroup] Get()
    {
        return $this
    }
    
}

[DscResource()]
class JoinDomain
{
    [DscProperty(Key)]
    [string] $DomainName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $Credential

    [void] Set()
    {
        $_credential = $this.Credential
        $_DomainName = $this.DomainName
        $_retryCount = 100
        try
        {       
            Add-Computer -DomainName $_DomainName -Credential $_credential -ErrorAction Stop
            $global:DSCMachineStatus = 1
        }
        catch
        {
            Write-Verbose "Failed to join into the domain , retry..."
            $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            $count = 0
            $flag = $false
            while($CurrentDomain -ne $_DomainName)
            {
                if($count -lt $_retryCount)
                {
                    $count++
                    Write-Verbose "retry count: $count"
                    Start-Sleep -Seconds 30
                    Add-Computer -DomainName $_DomainName -Credential $_credential -ErrorAction Ignore
                    
                    $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
                }
                else
                {
                    $flag = $true
                    break
                }
            }
            if($flag)
            {
                Add-Computer -DomainName $_DomainName -Credential $_credential
            }
            $global:DSCMachineStatus = 1
        }
    }

    [bool] Test()
    {
        $_DomainName = $this.DomainName
        $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain

        if($CurrentDomain -eq $_DomainName)
        {
            return $true
        }

        return $false
    }

    [JoinDomain] Get()
    {
        return $this
    }
    
}

[DscResource()]
class OpenFirewallPortForSCCM
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Mandatory)]
    [string[]] $Role

    [void] Set()
    {
        $_Role = $this.Role

        Write-Verbose "Current Role is : $_Role"

        if($_Role -contains "DC")
        {
            #HTTP(S) Requests
            New-NetFirewallRule -DisplayName 'HTTP(S) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For DC"
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For DC"
        
            #PS-->DC(in)
            New-NetFirewallRule -DisplayName 'LDAP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 389 -Group "For DC"
            New-NetFirewallRule -DisplayName 'LDAP(SSL) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 636 -Group "For DC"
            New-NetFirewallRule -DisplayName 'LDAP(SSL) UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 636 -Group "For DC"
            New-NetFirewallRule -DisplayName 'Global Catelog LDAP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3268 -Group "For DC"
            New-NetFirewallRule -DisplayName 'Global Catelog LDAP SSL Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3269 -Group "For DC"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For DC"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For DC"
            #Dynamic Port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For DC"

            #THAgent
            Enable-NetFirewallRule -DisplayGroup "Windows Management Instrumentation (WMI)" -Direction Inbound
            Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
        }

        if($_Role -contains "Site Server")
        {
            New-NetFirewallRule -DisplayName 'HTTP(S) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM"
    
            #site server<->site server
            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'SMB Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM"
            #New-NetFirewallRule -DisplayName 'PPTP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1723 -Group "For SCCM"
            #New-NetFirewallRule -DisplayName 'PPTP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1723 -Group "For SCCM"

            #priary site server(out) ->DC
            New-NetFirewallRule -DisplayName 'LDAP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 389 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'LDAP(SSL) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 636 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'LDAP(SSL) UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 636 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'Global Catelog LDAP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 3268 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'Global Catelog LDAP SSL Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 3269 -Group "For SCCM"


            #Dynamic Port?
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'RPC Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM"

            New-NetFirewallRule -DisplayName 'SQL over TCP  Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'SQL over TCP  Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SCCM"

            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM"
            New-NetFirewallRule -DisplayName 'Wake on LAN Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 9 -Group "For SCCM"
        }

        if($_Role -contains "Software Update Point")
        {
            New-NetFirewallRule -DisplayName 'SMB SUPInbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM SUP"
            New-NetFirewallRule -DisplayName 'SMB SUP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM SUP"
            New-NetFirewallRule -DisplayName 'HTTP(S) SUP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort @(8530,8531) -Group "For SCCM SUP"
            New-NetFirewallRule -DisplayName 'HTTP(S) SUP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(8530,8531) -Group "For SCCM SUP"
            #SUP->Internet
            New-NetFirewallRule -DisplayName 'HTTP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 80 -Group "For SCCM SUP"
        
            New-NetFirewallRule -DisplayName 'HTTP(S) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM SUP"
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM SUP"
        }
        if($_Role -ccontains "State Migration Point")
        {
            #SMB,RPC Endpoint Mapper
            New-NetFirewallRule -DisplayName 'SMB SMP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM SMP"
            New-NetFirewallRule -DisplayName 'SMB SMP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM SMP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM SMP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM SMP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM SMP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM SMP"
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM SUP"
        }
        if($_Role -contains "PXE Service Point")
        {
            #SMB,RPC Endpoint Mapper,RPC
            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'SMB Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM PXE SP"
            #Dynamic Port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'RPC Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'SQL over TCP  Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'DHCP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(67.68) -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'TFTP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 69  -Group "For SCCM PXE SP"
            New-NetFirewallRule -DisplayName 'BINL Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 4011 -Group "For SCCM PXE SP"
        }
        if($_Role -contains "System Health Validator")
        {
            #SMB,RPC Endpoint Mapper,RPC
            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM System Health Validator"
            New-NetFirewallRule -DisplayName 'SMB Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM System Health Validator"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM System Health Validator"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM System Health Validator"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM System Health Validator"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM System Health Validator"
            #dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM System Health Validator"
            New-NetFirewallRule -DisplayName 'RPC Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM System Health Validator"  
        }
        if($_Role -contains "Fallback Status Point")
        {
            #SMB,RPC Endpoint Mapper,RPC
            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM FSP"
            New-NetFirewallRule -DisplayName 'SMB Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM FSP "
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM FSP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM FSP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM FSP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM FSP"
            #dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM FSP"
            New-NetFirewallRule -DisplayName 'RPC Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM FSP"  
        
            New-NetFirewallRule -DisplayName 'HTTP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 -Group "For SCCM FSP"
        }
        if($_Role -contains "Reporting Services Point")
        {
            New-NetFirewallRule -DisplayName 'SQL over TCP  Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SCCM RSP"
            New-NetFirewallRule -DisplayName 'SQL over TCP  Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SCCM RSP"
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM RSP"
            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM RSP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM RSP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM RSP"
            #dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM RSP"
        }
        if($_Role -contains "Distribution Point")
        {
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM DP"
            New-NetFirewallRule -DisplayName 'SMB DP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM DP"
            New-NetFirewallRule -DisplayName 'Multicast Protocol Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 63000-64000 -Group "For SCCM DP"
        }
        if($_Role -contains "Management Point")
        {
            New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'SQL over TCP  Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'LDAP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 389 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'LDAP(SSL) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 636 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'LDAP(SSL) UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 636 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'Global Catelog LDAP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 3268 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'Global Catelog LDAP SSL Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 3269 -Group "For SCCM MP"

            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'SMB Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM MP"
            #dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM MP"
            New-NetFirewallRule -DisplayName 'RPC Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM MP"  
        }
        if($_Role -contains "Branch Distribution Point")
        {
            New-NetFirewallRule -DisplayName 'SMB BDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM BDP"
            New-NetFirewallRule -DisplayName 'HTTP(S) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM BDP"
        }
        if($_Role -contains "Server Locator Point")
        {
            New-NetFirewallRule -DisplayName 'HTTP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 -Group "For SCCM SLP"
            New-NetFirewallRule -DisplayName 'SQL over TCP  Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SQL Server SLP"
            New-NetFirewallRule -DisplayName 'SMB Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM SLP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM SLP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM SLP"
            #Dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM RSP"
        }
        if($_Role -contains "SQL Server")
        {
            New-NetFirewallRule -DisplayName 'SQL over TCP  Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -Group "For SQL Server"
            New-NetFirewallRule -DisplayName 'WMI' -Program "%systemroot%\system32\svchost.exe" -Service "winmgmt" -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort Domain -Group "For SQL Server WMI"
            New-NetFirewallRule -DisplayName 'DCOM' -Program "%systemroot%\system32\svchost.exe" -Service "rpcss" -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SQL Server DCOM"
            New-NetFirewallRule -DisplayName 'SMB Provider Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SQL Server"
        }
        if($_Role -contains "Provider")
        {
            New-NetFirewallRule -DisplayName 'SMB Provider Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM Provider"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM Provider"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM Provider"
            #dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM"
        }
        if($_Role -contains "Asset Intelligence Synchronization Point")
        {
            New-NetFirewallRule -DisplayName 'SMB Provider Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Group "For SCCM AISP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM AISP"
            New-NetFirewallRule -DisplayName 'RPC Endpoint Mapper UDP Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol UDP -LocalPort 135 -Group "For SCCM AISP"
            #rpc dynamic port
            New-NetFirewallRule -DisplayName 'RPC Inbound' -Profile Domain -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1024-65535 -Group "For SCCM AISP"
            New-NetFirewallRule -DisplayName 'HTTPS Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 443 -Group "For SCCM AISP"
        }
        if($_Role -contains "CM Console")
        {
            New-NetFirewallRule -DisplayName 'RPC Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM Console"
            #cm console->client
            New-NetFirewallRule -DisplayName 'Remote Control(control) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 2701 -Group "For SCCM Console"
            New-NetFirewallRule -DisplayName 'Remote Control(control) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 2701 -Group "For SCCM Console"
            New-NetFirewallRule -DisplayName 'Remote Control(data) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 2702 -Group "For SCCM Console"
            New-NetFirewallRule -DisplayName 'Remote Control(data) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol UDP -LocalPort 2702 -Group "For SCCM Console"
            New-NetFirewallRule -DisplayName 'Remote Control(RPC Endpoint Mapper) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 135 -Group "For SCCM Console"
            New-NetFirewallRule -DisplayName 'Remote Assistance(RDP AND RTC) Outbound' -Profile Domain -Direction Outbound -Action Allow -Protocol TCP -LocalPort 3389 -Group "For SCCM Console"
        }
        if($_Role -contains "Client")
        {
            #Client Push Installation
            Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
            Enable-NetFirewallRule -DisplayGroup "Windows Management Instrumentation (WMI)" -Direction Inbound

            #Remote Assistance and Remote Desktop
            New-NetFirewallRule -Program "C:\Windows\PCHealth\HelpCtr\Binaries\helpsvc.exe" -DisplayName "Remote Assistance - Helpsvc.exe" -Enabled True -Direction Outbound -Group "For SCCM Client"
            New-NetFirewallRule -Program "C:\Windows\PCHealth\HelpCtr\Binaries\helpsvc.exe" -DisplayName "Remote Assistance - Helpsvc.exe" -Enabled True -Direction Inbound -Group "For SCCM Client"
            New-NetFirewallRule -DisplayName 'CM Remote Assistance' -Profile Any -Direction Inbound -Action Allow -Protocol TCP -LocalPort 2701 -Group "For SCCM Client"

            #Client Requests
            New-NetFirewallRule -DisplayName 'HTTP(S) Outbound' -Profile Any -Direction Outbound -Action Allow -Protocol TCP -LocalPort @(80,443) -Group "For SCCM Client"

            #Client Notification
            New-NetFirewallRule -DisplayName 'CM Client Notification' -Profile Any -Direction Outbound -Action Allow -Protocol TCP -LocalPort 10123 -Group "For SCCM Client"

            #Remote Control
            New-NetFirewallRule -DisplayName 'CM Remote Control' -Profile Any -Direction Outbound -Action Allow -Protocol TCP -LocalPort 2701 -Group "For SCCM Client"

            #Wake-Up Proxy
            New-NetFirewallRule -DisplayName 'Wake-Up Proxy' -Profile Any -Direction Outbound -Action Allow -Protocol UDP -LocalPort (25536,9) -Group "For SCCM Client"

            #SUP
            New-NetFirewallRule -DisplayName 'CM Connect SUP' -Profile Any -Direction Outbound -Action Allow -Protocol TCP -LocalPort (8530,8531) -Group "For SCCM Client"
        
            #enable firewall public profile
            Set-NetFirewallProfile -Profile Public -Enabled True
        }
        $StatusPath = "$env:windir\temp\OpenFirewallStatus.txt"
        "Finished" >> $StatusPath
    }

    [bool] Test()
    {
        $StatusPath = "$env:windir\temp\OpenFirewallStatus.txt"
        if(Test-Path $StatusPath)
        {
            return $true
        }

        return $false
    }

    [OpenFirewallPortForSCCM] Get()
    {
        return $this
    }
    
}

[DscResource()]
class InstallFeatureForSCCM
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Mandatory)]
    [string[]] $Role

    [void] Set()
    {
        $_Role = $this.Role
        
        Write-Verbose "Current Role is : $_Role"

        if($_Role -notcontains "Client")
        {
            Install-WindowsFeature -Name "Rdc"
        }

        if($_Role -contains "DC")
        {
        }
        if($_Role -contains "Site Server")
        { 
            Add-WindowsFeature Web-Basic-Auth,Web-IP-Security,Web-Url-Auth,Web-Windows-Auth,Web-ASP,Web-Asp-Net 
            Add-WindowsFeature Web-Mgmt-Console,Web-Lgcy-Mgmt-Console,Web-Lgcy-Scripting,Web-WMI,Web-Mgmt-Service,Web-Mgmt-Tools,Web-Scripting-Tools 
        }
        if($_Role -contains "Application Catalog website point")
        {
            #IIS
            Add-WindowsFeature Web-Default-Doc,Web-Static-Content,Web-Windows-Auth,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext,Web-Net-Ext45,Web-Metabase
        }
        if($_Role -contains "Application Catalog web service point")
        {
            #IIS
            Add-WindowsFeature Web-Default-Doc,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext,Web-Net-Ext45,Web-Metabase
        }
        if($_Role -contains "Asset Intelligence synchronization point")
        {
            #installed .net 4.5 or later
        }
        if($_Role -contains "Certificate registration point")
        {
            #IIS
            Add-WindowsFeature Web-Asp-Net,Web-Asp-Net45,Web-Metabase,Web-WMI
        }
        if($_Role -contains "Distribution point")
        {
            #IIS 
            Add-WindowsFeature Web-Windows-Auth,web-ISAPI-Ext
            Add-WindowsFeature Web-WMI,Web-Metabase
        }
    
        if($_Role -contains "Endpoint Protection point")
        {
            #.NET 3.5 SP1 is intalled
        }
    
        if($_Role -contains "Enrollment point")
        {
            #iis
            Add-WindowsFeature Web-Default-Doc,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext,Web-Net-Ext45,Web-Metabase
        }
        if($_Role -contains "Enrollment proxy point")
        {
            #iis
            Add-WindowsFeature Web-Default-Doc,Web-Static-Content,Web-Windows-Auth,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext,Web-Net-Ext45,Web-Metabase
        }
        if($_Role -contains "Fallback status point")
        {
            Add-WindowsFeature Web-Metabase
        }
        if($_Role -contains "Management point")
        {
            #BITS
            #Add-WindowsFeature BITS,BITS-IIS-Ext
            #IIS 
            Add-WindowsFeature Web-Windows-Auth,web-ISAPI-Ext
            Add-WindowsFeature Web-WMI,Web-Metabase
        }
        if($_Role -contains "Reporting services point")
        {
            #installed .net 4.5 or later   
        }
        if($_Role -contains "Service connection point")
        {
            #installed .net 4.5 or later
        }
        if($_Role -contains "Software update point")
        {
            #default iis configuration
            add-windowsfeature web-server 
        }
        if($_Role -contains "State migration point")
        {
            #iis
            Add-WindowsFeature Web-Default-Doc,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext,Web-Net-Ext45,Web-Metabase
        }

        $StatusPath = "$env:windir\temp\InstallFeatureStatus.txt"
        "Finished" >> $StatusPath
    }

    [bool] Test()
    {
        $StatusPath = "$env:windir\temp\InstallFeatureStatus.txt"
        if(Test-Path $StatusPath)
        {
            return $true
        }

        return $false
    }

    [InstallFeatureForSCCM] Get()
    {
        return $this
    }
}

[DscResource()]
class SetCustomPagingFile
{
    [DscProperty(Key)]
    [string] $Drive

    [DscProperty(Mandatory)]
    [string] $InitialSize

    [DscProperty(Mandatory)]
    [string] $MaximumSize

    [void] Set()
    {
        $_Drive = $this.Drive
        $_InitialSize =$this.InitialSize
        $_MaximumSize =$this.MaximumSize

        $currentstatus = Get-CimInstance -ClassName 'Win32_ComputerSystem'
        if($currentstatus.AutomaticManagedPagefile)
        {
            set-ciminstance $currentstatus -Property @{AutomaticManagedPagefile= $false}
        }

        $currentpagingfile = Get-CimInstance -ClassName 'Win32_PageFileSetting' -Filter "SettingID='pagefile.sys @ $_Drive'" 

        if(!($currentpagingfile))
        {
            Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="$_Drive\pagefile.sys"; InitialSize = $_InitialSize; MaximumSize = $_MaximumSize}
        }
        else
        {
            Set-CimInstance $currentpagingfile -Property @{InitialSize = $_InitialSize ; MaximumSize = $_MaximumSize}
        }
        

        $global:DSCMachineStatus = 1
    }

    [bool] Test()
    {
        $_Drive = $this.Drive
        $_InitialSize =$this.InitialSize
        $_MaximumSize =$this.MaximumSize

        $isSystemManaged = (Get-CimInstance -ClassName 'Win32_ComputerSystem').AutomaticManagedPagefile
        if($isSystemManaged)
        {
            return $false
        }

        $_Drive = $this.Drive
        $currentpagingfile = Get-CimInstance -ClassName 'Win32_PageFileSetting' -Filter "SettingID='pagefile.sys @ $_Drive'" 
        if(!($currentpagingfile) -or !($currentpagingfile.InitialSize -eq $_InitialSize -and $currentpagingfile.MaximumSize -eq $_MaximumSize))
        {
            return $false
        }

        return $true
    }

    [SetCustomPagingFile] Get()
    {
        return $this
    }
    
}

[DscResource()]
class SetupDomain
{
    [DscProperty(Key)]
    [string] $DomainFullName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $SafemodeAdministratorPassword

    [void] Set()
    {
        $_DomainFullName = $this.DomainFullName
        $_SafemodeAdministratorPassword = $this.SafemodeAdministratorPassword

        $ADInstallState = Get-WindowsFeature AD-Domain-Services
        if(!$ADInstallState.Installed)
        {
            $Feature = Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
        }

        $NetBIOSName = $_DomainFullName.split('.')[0]
        Import-Module ADDSDeployment
        Install-ADDSForest -SafeModeAdministratorPassword $_SafemodeAdministratorPassword.Password `
            -CreateDnsDelegation:$false `
            -DatabasePath "C:\Windows\NTDS" `
            -DomainName $_DomainFullName `
            -DomainNetbiosName $NetBIOSName `
            -LogPath "C:\Windows\NTDS" `
            -InstallDNS:$true `
            -NoRebootOnCompletion:$false `
            -SysvolPath "C:\Windows\SYSVOL" `
            -Force:$true

        $global:DSCMachineStatus = 1
    }

    [bool] Test()
    {
        $_DomainFullName = $this.DomainFullName
        $_SafemodeAdministratorPassword = $this.SafemodeAdministratorPassword
        $ADInstallState = Get-WindowsFeature AD-Domain-Services
        if(!($ADInstallState.Installed))
        {
            return $false
        }
        else
        {
            while($true)
            {
                try
                {
                    $domain = Get-ADDomain -Identity $_DomainFullName -ErrorAction Stop
                    Get-ADForest -Identity $domain.Forest -Credential $_SafemodeAdministratorPassword -ErrorAction Stop

                    return $true
                }
                catch
                {
                    Write-Verbose "Waitting for Domain ready..."
                    Start-Sleep -Seconds 30
                }
            }
            
        }

        return $true
    }

    [SetupDomain] Get()
    {
        return $this
    }
    
}

[DscResource()]
class FileReadAccessShare
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Mandatory)]
    [string] $Path

    [DscProperty(Mandatory)]
    [string[]] $Account

    [void] Set()
    {
        $_Name = $this.Name
        $_Path = $this.Path
        $_Account = $this.Account

        New-SMBShare -Name $_Name -Path $_Path -ReadAccess $_Account
    }

    [bool] Test()
    {
        $_Name = $this.Name

        $testfileshare = Get-SMBShare | ?{$_.name -eq $_Name}
        if(!($testfileshare))
        {
            return $false
        }

        return $true
    }

    [FileReadAccessShare] Get()
    {
        return $this
    }
    
}

[DscResource()]
class InstallGPO
{
    [DscProperty(Key)]
    [string] $GPOURL
	
	[DscProperty(Key)]
    [string] $DomainDNSName

    [void] Set()
    {
        try
        {
			$DDNSName=$this.DomainDNSName
			$DomainName1,$DomainName2 = $DDNSName.split('.')
			$GPOlink=$this.GPOURL
			$OutputFile = Split-Path $GPOlink -leaf
			$ZipFile = "c:\$outputFile"

			# Download Zipped File
			$wc = new-object System.Net.WebClient
			$wc.DownloadFile($GPOlink, $ZipFile)


			# Unzip file
			$file = (Get-Item $ZipFile).Basename
			expand-archive -path $Zipfile -DestinationPath "c:\GPO\"

			$GPOFolder = "c:\GPO\"
			$GPOLocations = Get-ChildItem $GPOFolder | ForEach-Object {$_.BaseName}
						
			foreach($GPO in $GPOLocations)
			{
				$GPOName = $GPO.Replace("_"," ")
				write-Host "Creating GPO named: $GPOName "
				Import-GPO -BackupGpoName $GPOName -Path "$GPOFolder\$GPO" -TargetName $GPOName -CreateIfNeeded

				$gpLinks = $null
				$gPLinks = Get-ADObject -Identity (Get-ADDomain).distinguishedName -Properties name,distinguishedName, gPLink, gPOptions
				$GPO = Get-GPO -Name $GPOName
				If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
				{
					write-Host "Linking GPO $GPOName to Domain Root"
					New-GPLink -Name $GPOName -Target (Get-ADDomain).distinguishedName -Enforced yes
				}
				else
				{
					Write-Host "GpLink $GPOName already linked on Domain Root. Moving On."
				}
				$StatusPath = "$env:windir\temp\InstallGPOStatus.txt"
				"Finished deploying $GPO" >> $StatusPath
			}
            Write-Verbose "Finished deploying GPO."


        }
        catch
        {
            Write-Verbose "Failed to deploy GPO."
        }
    }

    [bool] Test()
    {
        $StatusPath = "$env:windir\temp\InstallGPOStatus.txt"
        if(Test-Path $StatusPath)
        {
            return $true
        }

        return $false
    }

    [InstallGPO] Get()
    {
        return $this
    }
    
}

[DscResource()]
class InstallCA
{
    [DscProperty(Key)]
    [string] $HashAlgorithm

    [void] Set()
    {
        try
        {
            $_HashAlgorithm = $this.HashAlgorithm
            Write-Verbose "Installing CA..."
            #Install CA
            Import-Module ServerManager
            Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
            Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -KeyLength 2048 -HashAlgorithmName $_HashAlgorithm -force

            $StatusPath = "$env:windir\temp\InstallCAStatus.txt"
            "Finished" >> $StatusPath

            Write-Verbose "Finished installing CA."
        }
        catch
        {
            Write-Verbose "Failed to install CA."
        }
    }

    [bool] Test()
    {
        $StatusPath = "$env:windir\temp\InstallCAStatus.txt"
        if(Test-Path $StatusPath)
        {
            return $true
        }

        return $false
    }

    [InstallCA] Get()
    {
        return $this
    }
    
}