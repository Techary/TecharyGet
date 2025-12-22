$ProgressPreference = 'SilentlyContinue'

$script:TecharyApps = @{
#region Adobe Reader
"adobereader" = @{
        DisplayName     = "Adobe Reader"
        RepoPath        = "a/Adobe/Acrobat/Reader/64-bit"
        YamlFile        = "Adobe.Acrobat.Reader.64-bit.installer.yaml"
        PatternX64      = 'InstallerUrl:\s*(\S*AcroRdrDCx64\S*\.exe)'
        PatternARM64    = 'InstallerUrl:\s*(\S*AcroRdrDCx64\S*\.exe)'
        InstallerType   = "exe"
        ExeInstallArgs  = "-sfx_nu /sAll /rs /msi"
        IsWinget        = $true
        WingetID        = "Adobe.Acrobat.Reader.64-bit"
    }
#endregion

#region Adobe Creative Cloud
"adobecc" = @{
        DisplayName     = "Adobe Creative Cloud"
        RepoPath        = "a/Adobe/CreativeCloud"
        YamlFile        = "Adobe.CreativeCloud.installer.yaml"
        PatternX64      = 'InstallerUrl:\s*(https://prod-rel-ffc-ccm\.oobesaas\.adobe\.com/adobe-ffc-external/core/v1/wam/download\?sapCode=KCCC&wamFeature=nuj-live)'
        PatternARM64    = 'InstallerUrl:\s*(https://prod-rel-ffc-ccm\.oobesaas\.adobe\.com/adobe-ffc-external/core/v1/wam/download\?sapCode=KCCC&wamFeature=nuj-live)'
        InstallerType   = "exe"
        ExeInstallArgs  = "--mode=stub"
        IsWinget        = $true
        WingetID        = "Adobe.CreativeCloud"
    }
#endregion

#region Microsoft PowerToys
"powertoys" = @{
    DisplayName     = "PowerToys"
    RepoPath        = "m/Microsoft/PowerToys"
    YamlFile        = "Microsoft.PowerToys.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/PowerToysSetup-\S*-x64\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/PowerToysSetup-\S*-arm64\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/quiet /norestart"
    IsWinget        = $true
    WingetID        = "Microsoft.PowerToys"
}
#endregion

#region Mozilla Firefox
"firefox" = @{
    DisplayName     = "Firefox"
    RepoPath        = "m/Mozilla/Firefox/en-GB"
    YamlFile        = "Mozilla.Firefox.en-GB.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/win64/en-GB/Firefox%20Setup%20\S+\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/win64-aarch64/en-GB/Firefox%20Setup%20\S+\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/S /PreventRebootRequired=true"
    IsWinget        = $true
    WingetID        = "Adobe.CreativeCloud"
}
#endregion

#region Slack
"slack" = @{
        DisplayName     = "Slack"
        RepoPath        = "s/SlackTechnologies/Slack"
        YamlFile        = "SlackTechnologies.Slack.installer.yaml"
        PatternX64      = 'InstallerUrl:\s*(\S*/x64/\S*/slack-standalone-\S+\.msi)'
        PatternARM64    = 'InstallerUrl:\s*(\S*/x64/\S*/slack-standalone-\S+\.msi)'
        InstallerType   = "msi"
        ExeInstallArgs  = "/S /PreventRebootRequired=true"
        IsWinget        = $true
        WingetID        = "SlackTechnologies.Slack"
    }
#endregion

#region Winget Auto Update
"wingetautoupdate" = @{
        DisplayName     = "Winget Auto Update"
        RepoPath        = "r/Romanitho/Winget-AutoUpdate"
        YamlFile        = "Romanitho.Winget-AutoUpdate.installer.yaml"
        PatternX64      = 'InstallerUrl:\s*(\S*/WAU\.msi)'
        PatternARM64    = 'InstallerUrl:\s*(\S*/WAU\.msi)'
        InstallerType   = "msi"
        ExeInstallArgs  = "/S /PreventRebootRequired=true"
        IsWinget        = $true
        WingetID        = "Romanitho.Winget-AutoUpdate"
    }
#endregion

#region RingCentral
"ringcentral" = @{
        DisplayName     = "RingCentral"
        RepoPath        = "r/RingCentral/RingCentral"
        YamlFile        = "RingCentral.RingCentral.installer.yaml"
        PatternX64      = 'InstallerUrl:https:\/\/app\.ringcentral\.com\/download\/RingCentral-[\d.]+-x64\.msi'
        PatternARM64    = 'InstallerUrl:https:\/\/app\.ringcentral\.com\/download\/RingCentral-[\d.]+-arm64\.msi'
        InstallerType   = "msi"
        IsWinget        = $true
        WingetID        = "RingCentral.RingCentral"
    }
#endregion

#region Microsoft Visual Studio Code
"vscode" = @{
    DisplayName     = "Microsoft Visual Studio Code"
    RepoPath        = "m/Microsoft/VisualStudioCode"
    YamlFile        = "Microsoft.VisualStudioCode.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*VSCodeSetup\S*x64\S*\.(exe|msi))'
    PatternARM64    = 'InstallerUrl:\s*(\S*VSCodeSetup\S*arm64\S*\.(exe|msi))'
    InstallerType   = "exe"
    ExeInstallArgs  = "/VERYSILENT /MERGETASKS=!runcode"
    IsWinget        = $true
    WingetID        = "Microsoft.VisualStudioCode"
}
#endregion

#region Jabra Direct
"jabradirect" = @{
    DisplayName     = "Jabra Direct"
    RepoPath        = "j/Jabra/Direct"
    YamlFile        = "Jabra.Direct.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/JabraDirectSetup\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/JabraDirectSetup\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/install /quiet /norestart"
    IsWinget        = $true
    WingetID        = "Jabra.Direct"
}
#endregion

#region Bitwarden
"bitwarden" = @{
    DisplayName     = "Bitwarden"
    RepoPath        = "b/Bitwarden/Bitwarden"
    YamlFile        = "Bitwarden.Bitwarden.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Bitwarden-Installer-\S+\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Bitwarden-Installer-\S+\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/allusers /S"
    IsWinget        = $true
    WingetID        = "Bitwarden.Bitwarden"
}
#endregion

#region Git
"git" = @{
    DisplayName     = "Git"
    RepoPath        = "g/Git/Git"
    YamlFile        = "Git.Git.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Git-\d+\.\d+\.\d+(-windows-\d+)?-64-bit\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Git-\d+\.\d+\.\d+(-windows-\d+)?-arm64\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
    IsWinget        = $true
    WingetID        = "Git.Git"
}
#endregion

#region 7zip
"7zip" = @{
    DisplayName     = "7zip"
    RepoPath        = "7/7zip/7zip"
    YamlFile        = "7zip.7zip.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/7z\d+-x64\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/7z\d+-arm64\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/S"
    IsWinget        = $true
    WingetID        = "7zip.7zip"
}
#endregion

#region Dell Command
"dellcommand" = @{
    DisplayName     = "Dell Command"
    RepoPath        = "d/Dell/CommandUpdate"
    YamlFile        = "Dell.CommandUpdate.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Dell-Command-Update-Application\S*WIN64\S*\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Dell-Command-Update-Application\S*WIN64\S*\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/passthrough /S /V/quiet /V/norestart"
    IsWinget        = $true
    WingetID        = "Dell.CommandUpdate"
}
#endregion

#region Microsoft Power Automate
"powerautomate" = @{
    DisplayName     = "Microsoft Power Automate Desktop"
    RepoPath        = "m/Microsoft/PowerAutomateDesktop"
    YamlFile        = "Microsoft.PowerAutomateDesktop.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Setup\.Microsoft\.PowerAutomate\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Setup\.Microsoft\.PowerAutomate\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "-Silent -ACCEPTEULA"
    IsWinget        = $true
    WingetID        = "Microsoft.PowerAutomateDesktop"
}
#endregion

#region Microsoft PowerBi
"powerbi" = @{
    DisplayName     = "Microsoft Power BI"
    RepoPath        = "m/Microsoft/PowerBI"
    YamlFile        = "Microsoft.PowerBI.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/PBIDesktopSetup-\d{4}-\d{2}_x64\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/PBIDesktopSetup-\d{4}-\d{2}_x64\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "-silent ACCEPT_EULA=1"
    IsWinget        = $true
    WingetID        = "Microsoft.PowerBI"
}
#endregion

#region Java Runtime Environment
"java" = @{
    DisplayName     = "Java Runtime Environment"
    RepoPath        = "o/Oracle/JavaRuntimeEnvironment"
    YamlFile        = "Oracle.JavaRuntimeEnvironment.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(https://javadl\.oracle\.com/webapps/download/AutoDL\?BundleId=\d+_[a-fA-F0-9]+)'
    PatternARM64    = 'InstallerUrl:\s*(https://javadl\.oracle\.com/webapps/download/AutoDL\?BundleId=\d+_[a-fA-F0-9]+)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/s REBOOT=0"
    IsWinget        = $true
    WingetID        = "Oracle.JavaRuntimeEnvironment"
}
#endregion

#region ReMarkable
"remarkable" = @{
    DisplayName     = "ReMarkable Companion App"
    RepoPath        = "r/reMarkable/reMarkableCompanionApp"
    YamlFile        = "reMarkable.reMarkableCompanionApp.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/reMarkable-\S*-win64\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/reMarkable-\S*-win64\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "install --confirm-command --default-answer --accept-licenses"
    IsWinget        = $true
    WingetID        = "reMarkable.reMarkableCompanionApp"
}
#endregion

#region Logi Options
"logioptions" = @{
    DisplayName     = "Logi Options Plus"
    RepoPath        = "l/Logitech/OptionsPlus"
    YamlFile        = "Logitech.OptionsPlus.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/logioptionsplus_installer\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/logioptionsplus_installer\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/quiet /analytics no"
    IsWinget        = $true
    WingetID        = "Logitech.OptionsPlus"
}
#endregion

#region Sublime Text
"sublimetext" = @{
    DisplayName     = "Sublime Text"
    RepoPath        = "s/SublimeHQ/SublimeText/4"
    YamlFile        = "SublimeHQ.SublimeText.4.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/sublime_text_build_\d+_x64_setup\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/sublime_text_build_\d+_x64_setup\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/VERYSILENT /NORESTART"
    IsWinget        = $true
    WingetID        = "SublimeHQ.SublimeText.4"
}
#endregion

#region PuTTy
"putty" = @{
    DisplayName     = "PuTTy"
    RepoPath        = "p/PuTTY/PuTTY"
    YamlFile        = "PuTTY.PuTTY.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/putty-64bit-\d+\.\d+-installer\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/putty-arm64-\d+\.\d+-installer\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "PuTTY.PuTTY"
}
#endregion

#region Cisco Webex
"webex" = @{
    DisplayName     = "Cisco Webex"
    RepoPath        = "c/Cisco/Webex"
    YamlFile        = "Cisco.Webex.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Webex\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Webex\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "Cisco.Webex"
}
#endregion

#region Microsoft Edge
"edge" = @{
    DisplayName     = "Microsoft Edge"
    RepoPath        = "m/Microsoft/Edge"
    YamlFile        = "Microsoft.Edge.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/MicrosoftEdgeEnterpriseX64\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/MicrosoftEdgeEnterpriseARM64\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "Microsoft.Edge"
}
#endregion

#region PDF24
"pdf24" = @{
    DisplayName     = "PDF24 Creator"
    RepoPath        = "g/geeksoftwareGmbH/PDF24Creator"
    YamlFile        = "geeksoftwareGmbH.PDF24Creator.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/pdf24-creator-\d+\.\d+\.\d+-x64\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/pdf24-creator-\d+\.\d+\.\d+-arm64\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "geeksoftwareGmbH.PDF24Creator"
}
#endregion

#region 8x8 Work
"8x8work" = @{
    DisplayName     = "8x8 Work"
    RepoPath        = "8/8x8/Work"
    YamlFile        = "8x8.Work.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S+)'
    PatternARM64    = 'InstallerUrl:\s*(\S+)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "8x8.Work"
}
#endregion

#region Powershell 7
"powershell7" = @{
    DisplayName     = "Powershell 7"
    RepoPath        = "m/Microsoft/PowerShell"
    YamlFile        = "Microsoft.PowerShell.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/PowerShell-\d+\.\d+\.\d+-win-x64\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/PowerShell-\d+\.\d+\.\d+-win-arm64\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "Microsoft.PowerShell"
}
#endregion

#region Wireshark
"wireshark" = @{
    DisplayName     = "Wireshark"
    RepoPath        = "w/WiresharkFoundation/Wireshark"
    YamlFile        = "WiresharkFoundation.Wireshark.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Wireshark-\S*-x64\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Wireshark-\S*-x64\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "WiresharkFoundation.Wireshark"
}
#endregion

#region Zoom
"zoom" = @{
    DisplayName     = "Zoom"
    RepoPath        = "z/Zoom/Zoom"
    YamlFile        = "Zoom.Zoom.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/ZoomInstallerFull\.msi\?archType=x64)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/ZoomInstallerFull\.msi\?archType=winarm64)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "Zoom.Zoom"
}
#endregion

#region GitHub Desktop
"githubdesktop" = @{
    DisplayName     = "GitHub Desktop"
    RepoPath        = "g/GitHub/GitHubDesktop"
    YamlFile        = "GitHub.GitHubDesktop.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S+.*64.*\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S+.*arm64.*\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "GitHub.GitHubDesktop"
}
#endregion

#region VLC Media Player
"vlc" = @{
    DisplayName     = "VLC Media Player"
    RepoPath        = "v/VideoLAN/VLC"
    YamlFile        = "VideoLAN.VLC.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/vlc-\d+\.\d+\.\d+-win64\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/vlc-\d+\.\d+\.\d+-win64\.exe)'
    InstallerType   = "exe"
    IsWinget        = $true
    ExeInstallArgs  = "/S"
    WingetID        = "VideoLAN.VLC"
}
#endregion

#region NodeJS
"nodejs" = @{
    DisplayName     = "NodeJS"
    RepoPath        = "o/OpenJS/NodeJS"
    YamlFile        = "OpenJS.NodeJS.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/node-v\S*-x64\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/node-v\S*-arm64\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "OpenJS.NodeJS"
}
#endregion

#region Google Chrome
"chrome" = @{
    DisplayName     = "Google Chrome"
    RepoPath        = "g/Google/Chrome"
    YamlFile        = "Google.Chrome.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S+.*64.*\.msi)'
    PatternARM64    = 'InstallerUrl:\s*(\S+.*arm64.*\.msi)'
    InstallerType   = "msi"
    IsWinget        = $true
    WingetID        = "Google.Chrome"
}
#endregion

#region Display Link
"displaylink" = @{
    DisplayName     = "Display Link"
    RepoPath        = "d/DisplayLink/GraphicsDriver"
    YamlFile        = "DisplayLink.GraphicsDriver.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S+)'
    PatternARM64    = 'InstallerUrl:\s*(\S+)'
    InstallerType   = "zip"
    IsWinget        = $true
    WingetID        = "DisplayLink.GraphicsDriver"
}
#endregion







##########################
##########################
#region NOT WINGET APPS ##
##########################
##########################
##########################
##########################
##########################
#region Windows App
"windowsapp" = @{
    DisplayName     = "Windows App"
    IsWinget        = $false
    DownloadUrl     = "https://go.microsoft.com/fwlink/?linkid=2262633"
    InstallerType   = "msix"
}
#endregion

#region MyDPD
"mydpd" = @{
    DisplayName     = "MyDPD Customer"
    IsWinget        = $false
    DownloadUrl     = "https://apis.my.dpd.co.uk/apps/download/public"
    InstallerType   = "exe"
    ExeInstallArgs  = "--Silent"
}
#endregion

#region Royal Mail Print Assist
"royalmail" = @{
    DisplayName     = "Royal Mail Print Assist"
    IsWinget        = $false
    DownloadUrl     = "http://app.printnode.com/download/client/royalmail/windows"
    InstallerType   = "exe"
    ExeInstallArgs  = "/VERYSILENT /SUPPRESSMSGBOXES"
}
#endregion

#region Crosschex
"crosschex" = @{
    DisplayName     = "Crosschex"
    IsWinget        = $false
    DownloadUrl     = "https://www.anviz.com/file/download/5539/CrossChex_Standard_4.3.16.exe"
    InstallerType   = "exe"
    ExeInstallArgs  = "/exenoui ALLUSERS=1 /qn"
}
#endregion

#region Coreldraw
"coreldraw" = @{
    DisplayName     = "Coreldraw"
    IsWinget        = $false
    DownloadUrl     = "https://www.corel.com/akdlm/6763/downloads/free/trials/GraphicsSuite/2019/R5tgO2Wx1/getdl/CorelDRAWGraphicsSuite2019Installer_AM.exe"
    InstallerType   = "exe"
    ExeInstallArgs  = "/qn"
}
#endregion

#region N-Able RMM Agent
# How to Install
#Install-TecharyApp -AppName "nable" -Parameters @{
# CustomerID    = "123456" This can be found in N-Central under Administration > Customers, there you will see the Access Code column
# Token         = "abcdefg" Token is got under Actions > Add/Import Devices > Get Registration Token
# CustomerName  = '\"Company Name From N-Central\"' #This has to be formatted like this with the name of their customer in nable
#  ServerAddress = "Refer to Confluence guide for the server address"
# }

"nable" = @{
    DisplayName   = "N-Able RMM Agent"
    IsWinget      = $false
    InstallerType = "exe"
    ExeInstallArgs  = "/qn /v"
}
#endregion


}
