mkdir c:\temp
cd c:\temp
Invoke-WebRequest -Uri https://github.com/tiwari247/intrust-arm/blob/main/DSC/WinRMOverHTTPS.zip?raw=true -OutFile .\WinRMOverHTTPS.zip
Expand-Archive -Path C:\temp\WinRMOverHTTPS.zip -DestinationPath C:\
cd C:\WinRMOverHTTPS\WinRMOverHTTPS
.\ConfigureWinRM.ps1 -HostName 10.0.0.4