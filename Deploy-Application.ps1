<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'NonInteractive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $true,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Microsoft'
	[string]$appName = 'Skype Meetings App'
	[string]$appVersion = '16.2.0.511'
	[string]$appArch = 'x86'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.1'
	[string]$appScriptDate = '08/05/2020'
	[string]$appScriptAuthor = 'IT Department'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.1'
	[string]$deployAppScriptDate = '28/03/2020'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		Show-InstallationWelcome -CloseApps 'iexplore=Internet Explorer,Skype Meetings App' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>

		# Installation folder
		$SkypeMeetingsPath = "$envProgramFilesX86\Microsoft\SkypeForBusinessPlugin\$appVersion"
		# Note. If you change this path make sure you also change the $PluginBasePath in the uninstall section


		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## <Perform Installation tasks here>

		If (Test-Path -Path "$dirSupportFiles\7za.exe" -PathType Leaf) {
			Write-Log -Message "Installing Skype Meetings App" -Source 'Execute-Process' -LogType 'CMTrace'
			$Params = '{0} "{1}" {2}"{3}" {4}' -f 'x', "$dirFiles\SkypeMeetingsApp.7z", '-o', "$SkypeMeetingsPath", '-y'
			Execute-Process -Path "$dirSupportFiles\7za.exe" -Parameters "$Params" -CreateNoWindow -ContinueOnError $false
		}

		If (([Version]$envOSVersion).Major -eq '10') {
			Write-Log -Message "Deleting files that aren't required for Windows 10" -Source 'Remove-File' -LogType 'CMTrace'
			Remove-File -Path "$SkypeMeetingsPath\api-ms-win-*.dll","$SkypeMeetingsPath\ucrtbase.dll" -ContinueOnError $true
		}

		If ($is64Bit) {

			# Add registry keys only if the Skype Meetings App EXE exists
			If (Test-Path -Path "$SkypeMeetingsPath\Skype Meetings App.exe" -PathType Leaf) {

				$LaunchPerms_FE2EC208 = 0x01,0x00,0x04,0x80,0x74,0x00,0x00,0x00, +
					0x84,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x14,0x00,0x00,0x00,0x02,0x00,0x60,0x00,0x04,0x00,0x00,0x00, +
					0x00,0x00,0x14,0x00,0x1f,0x00,0x00,0x00,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x05,0x12,0x00,0x00,0x00, +
					0x00,0x00,0x18,0x00,0x1f,0x00,0x00,0x00,0x01,0x02,0x00,0x00,0x00,0x00,0x00,0x05,0x20,0x00,0x00,0x00, +
					0x20,0x02,0x00,0x00,0x00,0x00,0x18,0x00,0x0b,0x00,0x00,0x00,0x01,0x02,0x00,0x00,0x00,0x00,0x00,0x0f, +
					0x02,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x14,0x00,0x1f,0x00,0x00,0x00,0x01,0x01,0x00,0x00, +
					0x00,0x00,0x00,0x05,0x04,0x00,0x00,0x00,0x01,0x02,0x00,0x00,0x00,0x00,0x00,0x05,0x20,0x00,0x00,0x00, +
					0x20,0x02,0x00,0x00,0x01,0x02,0x00,0x00,0x00,0x00,0x00,0x05,0x20,0x00,0x00,0x00,0x20,0x02,0x00,0x00

				Write-Log -Message "Creating Skype Meetings App registry keys" -Source 'Set-RegistryKey' -LogType 'CMTrace'

				# HKLM\Software
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{AEBC497A-8937-4C44-8B8F-FDF4EF81E631}' -Name 'AppName' -Value 'GatewayVersion-x64.exe' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{AEBC497A-8937-4C44-8B8F-FDF4EF81E631}' -Name 'AppPath' -Value "$SkypeMeetingsPath" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{AEBC497A-8937-4C44-8B8F-FDF4EF81E631}' -Name 'Policy' -Value 3 -Type DWord

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{C48E95B3-4931-4E6B-A600-CD53B16E3511}' -Name 'AppName' -Value 'PluginHost.exe' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{C48E95B3-4931-4E6B-A600-CD53B16E3511}' -Name 'AppPath' -Value "$SkypeMeetingsPath" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{C48E95B3-4931-4E6B-A600-CD53B16E3511}' -Name 'Policy' -Value 3 -Type DWord

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{CB7F3505-43FF-4ECE-B60F-A164A832AE46}' -Name 'AppName' -Value 'GatewayVersion.exe' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{CB7F3505-43FF-4ECE-B60F-A164A832AE46}' -Name 'AppPath' -Value "$SkypeMeetingsPath" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{CB7F3505-43FF-4ECE-B60F-A164A832AE46}' -Name 'Policy' -Value 3 -Type DWord

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_GPU_RENDERING' -Name 'Skype Meetings App.exe' -Value 1 -Type DWord
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_MAXCONNECTIONSPER1_0SERVER' -Name 'Skype Meetings App.exe' -Value 10 -Type DWord
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_MAXCONNECTIONSPERSERVER' -Name 'Skype Meetings App.exe' -Value 10 -Type DWord

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\ProtocolExecute\sfb' -Name 'WarnOnOpen' -Value 0 -Type DWord

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\LWAPlugin\15.8' -Name 'CodeMajorVersion' -Value '16.2' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\LWAPlugin\15.8' -Name 'CodeMinorVersion' -Value '0.511' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2' -Name 'GetVersionValue' -Value '16.2@0.511' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2' -Name 'LAUNCHSTATUS' -Value '1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2' -Name 'CurrentVersion' -Value '16.2.0.511' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2' -Name 'TraceLevel' -Value 7 -Type DWord

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.ccsctp.net' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.lync.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.microsoft.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.microsoftonline.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.office.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.office365.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.officeppe.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.onedrive.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.onmicrosoft.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.outlook.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.sharepoint.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.skype.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.skype.net' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.vdomain.com' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin\16.2\AllowedDomains' -Name '*.yammer.com' -Value '' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Ext\Stats\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\iexplore' -Name 'Flags' -Value 4 -Type DWord
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Ext\Stats\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\iexplore\AllowedDomains\*' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Ext\Stats\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\iexplore' -Name 'Flags' -Value 4 -Type DWord
				Set-RegistryKey -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Ext\Stats\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\iexplore\AllowedDomains\*' -Name '(Default)' -Value '' -Type String

				# HKLM\Software\Classes
				Set-RegistryKey -Key 'HKLM\Software\Classes\AppID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Name '(Default)' -Value 'Skype for Business Web App Version Plug-in' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\AppID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Name 'LaunchPermission' -Value $LaunchPerms_FE2EC208 -Type Binary
				Set-RegistryKey -Key 'HKLM\Software\Classes\AppID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\GatewayVersion.exe' -Name 'AppId' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\AppID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\GatewayVersion-x64.exe' -Name 'AppId' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Control' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Implemented Categories\{59FB2056-D625-48D0-A944-1A85B5AB2640}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Implemented Categories\{7DD95801-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Implemented Categories\{7DD95802-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\InprocServer32' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayActiveX-x64.dll" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\InprocServer32' -Name 'ThreadingModel' -Value 'Apartment' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\MiscStatus' -Name '(Default)' -Value '0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\MiscStatus\1' -Name '(Default)' -Value '131473' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\ProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx.1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Programmable' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\TypeLib' -Name '(Default)' -Value '{0433A8C7-4371-4CB0-97F0-D5BE7F9F7187}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Version' -Name '(Default)' -Value '1.0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\VersionIndependentProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Control' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Implemented Categories\{59FB2056-D625-48D0-A944-1A85B5AB2640}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Implemented Categories\{7DD95801-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Implemented Categories\{7DD95802-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\LocalServer32' -Name '(Default)' -Value "$SkypeMeetingsPath\PluginHost.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\LocalServer32' -Name 'ServerExecutable' -Value "$SkypeMeetingsPath\PluginHost.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\MiscStatus' -Name '(Default)' -Value '0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\MiscStatus\1' -Name '(Default)' -Value '131473' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\ProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.ComponentFx.1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Programmable' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\TypeLib' -Name '(Default)' -Value '{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Version' -Name '(Default)' -Value '1.0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\VersionIndependentProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.ComponentFx' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Name '(Default)' -Value 'Skype for Business Web App Version Plug-in' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Name 'AppID' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Control' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Implemented Categories\{59FB2056-D625-48D0-A944-1A85B5AB2640}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Implemented Categories\{7DD95801-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Implemented Categories\{7DD95802-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\LocalServer32' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayVersion-x64.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\LocalServer32' -Name 'ServerExecutable' -Value "$SkypeMeetingsPath\GatewayVersion-x64.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\ProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.VersionQuery.1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Programmable' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\TypeLib' -Name '(Default)' -Value '{7FEEA833-A3B2-4623-A077-F56E9F9688A8}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Version' -Name '(Default)' -Value '1.0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\VersionIndependentProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.VersionQuery' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx\CLSID' -Name '(Default)' -Value '{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx\CurVer' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.ComponentFx.1' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx.1' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx.1\CLSID' -Name '(Default)' -Value '{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx\CLSID' -Name '(Default)' -Value '{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx\CurVer' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx.1' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx.1' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx.1\CLSID' -Name '(Default)' -Value '{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery' -Name '(Default)' -Value 'Skype for Business Web App Version Plug-in' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery\CLSID' -Name '(Default)' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery\CurVer' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.VersionQuery.1' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery.1' -Name '(Default)' -Value 'Skype for Business Web App Version Plug-in' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery.1\CLSID' -Name '(Default)' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\MIME\Database\Content Type\application/x-skypeforbusiness-plugin-16.2' -Name 'CLSID' -Value '{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\MIME\Database\Content Type\application/x-skypeforbusiness-version-16.2' -Name 'CLSID' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\sfb' -Name '(Default)' -Value 'URL:sfb' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\sfb' -Name 'URL Protocol' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\sfb\shell\open\command' -Name '(Default)' -Value "$SkypeMeetingsPath\Skype Meetings App.exe %1" -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{0433A8C7-4371-4CB0-97F0-D5BE7F9F7187}\1.0' -Name '(Default)' -Value 'InProcFrameworkLib' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{0433A8C7-4371-4CB0-97F0-D5BE7F9F7187}\1.0\0\win32' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayActiveX.dll" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{0433A8C7-4371-4CB0-97F0-D5BE7F9F7187}\1.0\0\win64' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayActiveX-x64.dll" -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}\1.0' -Name '(Default)' -Value 'FrameworkLib' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}\1.0\0\win32' -Name '(Default)' -Value "$SkypeMeetingsPath\PluginHost.exe" -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{7FEEA833-A3B2-4623-A077-F56E9F9688A8}\1.0' -Name '(Default)' -Value 'VersionCheckerLib' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{7FEEA833-A3B2-4623-A077-F56E9F9688A8}\1.0\0\win32' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayVersion.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{7FEEA833-A3B2-4623-A077-F56E9F9688A8}\1.0\0\win64' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayVersion-x64.exe" -Type String

				# HKLM\Software\Classes\WOW6432Node
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Control' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Implemented Categories\{59FB2056-D625-48D0-A944-1A85B5AB2640}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Implemented Categories\{7DD95801-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Implemented Categories\{7DD95802-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\InprocServer32' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayActiveX.dll" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\InprocServer32' -Name 'ThreadingModel' -Value 'Apartment' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\MiscStatus' -Name '(Default)' -Value '0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\MiscStatus\1' -Name '(Default)' -Value '131473' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\ProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx.1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Programmable' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\TypeLib' -Name '(Default)' -Value '{0433A8C7-4371-4CB0-97F0-D5BE7F9F7187}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\Version' -Name '(Default)' -Value '1.0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}\VersionIndependentProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}' -Name '(Default)' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Control' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Implemented Categories\{59FB2056-D625-48D0-A944-1A85B5AB2640}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Implemented Categories\{7DD95801-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Implemented Categories\{7DD95802-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\LocalServer32' -Name '(Default)' -Value "$SkypeMeetingsPath\PluginHost.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\LocalServer32' -Name 'ServerExecutable' -Value "$SkypeMeetingsPath\PluginHost.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\MiscStatus' -Name '(Default)' -Value '0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\MiscStatus\1' -Name '(Default)' -Value '131473' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\ProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.ComponentFx.1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Programmable' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\TypeLib' -Name '(Default)' -Value '{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\Version' -Name '(Default)' -Value '1.0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}\VersionIndependentProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.ComponentFx' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Name '(Default)' -Value 'Skype for Business Web App Version Plug-in' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Name 'AppID' -Value '{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Control' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Implemented Categories\{59FB2056-D625-48D0-A944-1A85B5AB2640}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Implemented Categories\{7DD95801-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Implemented Categories\{7DD95802-9882-11CF-9FA9-00AA006C42C4}' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\LocalServer32' -Name '(Default)' -Value "$SkypeMeetingsPath\GatewayVersion.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\LocalServer32' -Name 'ServerExecutable' -Value "$SkypeMeetingsPath\GatewayVersion.exe" -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\ProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.VersionQuery.1' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Programmable' -Name '(Default)' -Value '' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\TypeLib' -Name '(Default)' -Value '{7FEEA833-A3B2-4623-A077-F56E9F9688A8}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\Version' -Name '(Default)' -Value '1.0' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}\VersionIndependentProgID' -Name '(Default)' -Value 'Microsoft.SkypeForBusinessPlugin16.2.VersionQuery' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{98A06566-A85A-4928-9AD4-456C0FDFD3CB}' -Name '(Default)' -Value 'IVersionQuery' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{98A06566-A85A-4928-9AD4-456C0FDFD3CB}\ProxyStubClsid32' -Name '(Default)' -Value '{00020424-0000-0000-C000-000000000046}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{98A06566-A85A-4928-9AD4-456C0FDFD3CB}\TypeLib' -Name '(Default)' -Value '{7FEEA833-A3B2-4623-A077-F56E9F9688A8}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{98A06566-A85A-4928-9AD4-456C0FDFD3CB}\TypeLib' -Name 'Version' -Value '1.0' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{B9407B52-54D5-4390-A8FD-98DC43C23519}' -Name '(Default)' -Value 'IComponentFx' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{B9407B52-54D5-4390-A8FD-98DC43C23519}\ProxyStubClsid32' -Name '(Default)' -Value '{00020424-0000-0000-C000-000000000046}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{B9407B52-54D5-4390-A8FD-98DC43C23519}\TypeLib' -Name '(Default)' -Value '{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{B9407B52-54D5-4390-A8FD-98DC43C23519}\TypeLib' -Name 'Version' -Value '1.0' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BC5D29F5-2089-443B-9CEA-B8BC6490E5D6}' -Name '(Default)' -Value 'IPluginHost' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BC5D29F5-2089-443B-9CEA-B8BC6490E5D6}\ProxyStubClsid32' -Name '(Default)' -Value '{00020424-0000-0000-C000-000000000046}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BC5D29F5-2089-443B-9CEA-B8BC6490E5D6}\TypeLib' -Name '(Default)' -Value '{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BC5D29F5-2089-443B-9CEA-B8BC6490E5D6}\TypeLib' -Name 'Version' -Value '1.0' -Type String

				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BED8D1B1-7789-47B5-BB4C-692DA72CECFE}' -Name '(Default)' -Value 'IPluginHost' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BED8D1B1-7789-47B5-BB4C-692DA72CECFE}\ProxyStubClsid32' -Name '(Default)' -Value '{00020424-0000-0000-C000-000000000046}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BED8D1B1-7789-47B5-BB4C-692DA72CECFE}\TypeLib' -Name '(Default)' -Value '{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}' -Type String
				Set-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BED8D1B1-7789-47B5-BB4C-692DA72CECFE}\TypeLib' -Name 'Version' -Value '1.0' -Type String

				<#
				# Firefox ≥ 52 does not support NPAPI plugins so there isn't any point creating the following registry keys
				Set-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2' -Name 'Path' -Value "$SkypeMeetingsPath\npGatewayNpapi-x64.dll" -Type String
				Set-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2' -Name 'Description' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2' -Name 'ProductName' -Value 'Skype Meetings App' -Type String
				Set-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2' -Name 'Vendor' -Value 'Microsoft Corporation' -Type String
				Set-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2' -Name 'Version' -Value "$appVersion" -Type String
				Set-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2\MimeTypes\application/x-skypeforbusiness-plugin-16.2' -Name '(Default)' -Value '' -Type String
				#>

			}
		}


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		$FwParams = @{
			'Description' = 'Skype Meetings App'
			'Action'      = 'Allow'
			'Direction'   = 'Inbound'
			'Enabled'     = 'True'
		}

		$NewFwParams1 = @{
			'DisplayName' = 'Skype Meetings App'
			'Program'     = "$SkypeMeetingsPath\Skype Meetings App.exe"
			'Profile'     = 'Domain,Private'
		}

		$NewFwParams2 = @{
			'DisplayName' = 'Skype Meetings App'
			'Program'     = "$SkypeMeetingsPath\PluginHost.exe"
			'Profile'     = 'Domain,Private'
		}

		If ((Get-NetFirewallRule @FwParams -PolicyStore 'PersistentStore' -ErrorAction SilentlyContinue).Count -eq 0) {
			'TCP','UDP' | ForEach {
				Write-Log -Message "Creating Windows Defender Firewall Rules" -Source 'New-NetFirewallRule' -LogType 'CMTrace'
				New-NetFirewallRule @FwParams @NewFwParams1 -Protocol $_
				New-NetFirewallRule @FwParams @NewFwParams2 -Protocol $_
			}
		}

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'Installation complete' -ButtonRightText 'OK' -Icon Information -NoWait }


	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		Show-InstallationWelcome -CloseApps 'iexplore=Internet Explorer,Skype Meetings App' -CloseAppsCountdown 60
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		# <Perform Uninstallation tasks here>

		$PluginBasePath = "$envProgramFilesX86\Microsoft\SkypeForBusinessPlugin"

		If (Test-Path -Path "$PluginBasePath" -PathType Container) {
			Write-Log -Message "Deleting Skype Meetings App folder" -Source 'Remove-Folder' -LogType 'CMTrace'
			Remove-Folder -Path "$PluginBasePath" -ContinueOnError $false
		}

		# Delete parent folder if it is also empty
		If (!(Test-Path -Path "$envProgramFilesX86\Microsoft\*")) {
			Remove-Folder -Path "$envProgramFilesX86\Microsoft" -ContinueOnError $true
		}

		Write-Log -Message "Deleting Skype Meetings App registry keys" -Source 'Remove-RegistryKey' -LogType 'CMTrace'
		#
		Remove-RegistryKey -Key 'HKLM\Software\Classes\AppID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx.1' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.ComponentFx' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx.1' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.InProcComponentFx' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery.1' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\Microsoft.SkypeForBusinessPlugin16.2.VersionQuery' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\MIME\Database\Content Type\application/x-skypeforbusiness-plugin-16.2' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\MIME\Database\Content Type\application/x-skypeforbusiness-version-16.2' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\sfb' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{0433A8C7-4371-4CB0-97F0-D5BE7F9F7187}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{3BBC27D9-3AF6-48D8-B210-AED69B326EC7}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\TypeLib\{7FEEA833-A3B2-4623-A077-F56E9F9688A8}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{8035C13E-D5F7-4CF6-B78A-E493D9AA5418}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\CLSID\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{98A06566-A85A-4928-9AD4-456C0FDFD3CB}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{B9407B52-54D5-4390-A8FD-98DC43C23519}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BC5D29F5-2089-443B-9CEA-B8BC6490E5D6}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Classes\WOW6432Node\Interface\{BED8D1B1-7789-47B5-BB4C-692DA72CECFE}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{AEBC497A-8937-4C44-8B8F-FDF4EF81E631}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{C48E95B3-4931-4E6B-A600-CD53B16E3511}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{CB7F3505-43FF-4ECE-B60F-A164A832AE46}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_GPU_RENDERING' -Name 'Skype Meetings App.exe'
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_MAXCONNECTIONSPER1_0SERVER' -Name 'Skype Meetings App.exe'
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_MAXCONNECTIONSPERSERVER' -Name 'Skype Meetings App.exe'
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Internet Explorer\ProtocolExecute\sfb' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\LWAPlugin\15.8' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\SkypeForBusinessPlugin' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Ext\Stats\{3E3AD4BD-346A-460A-80E8-90699B75C00B}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Ext\Stats\{FE2EC208-BECF-4E83-8BF4-E35DBA4EB6A1}' -Recurse $true
		Remove-RegistryKey -Key 'HKLM\Software\MozillaPlugins\SkypeForBusinessPlugin64-16.2' -Recurse $true
		#


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>
		Write-Log -Message "Deleting Windows Firewall Rules" -Source 'Remove-NetFirewallRule' -LogType 'CMTrace'
		Remove-NetFirewallRule -DisplayName "Skype Meetings App" -PolicyStore PersistentStore


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		# <Perform Repair tasks here>



		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
