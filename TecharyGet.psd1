@{
    # Script module file associated with this manifest
    RootModule        = 'TecharyGet.psm1'

    # Version of this module
    ModuleVersion     = '1.0'

    # ID used to uniquely identify this module
    GUID              = '8d777e7e-fd28-4e34-bf9d-0c325bb81a76'

    # Author of this module
    Author            = 'Adam Sweetapple'

    # Company or vendor of this module
    CompanyName       = 'Techary'

    # Copyright
    Copyright         = '(c) 2025 Techary. All rights reserved.'

    # Description of the module
    Description       = 'A PowerShell module for managing app installations and uninstalls using Winget, MSI, EXE, ZIP, and MSIX sources. Supports custom logic and Intune deployment.'

    # Minimum version of PowerShell required
    PowerShellVersion = '5.1'

    # Functions to export
    FunctionsToExport = "Install-TecharyApp","Uninstall-TecharyApp","Help-TecharyApp","Get-TecharyAppList"

    # Cmdlets to export
    CmdletsToExport   = @()

    # Variables to export
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport   = @()

    # Private data to pass to PowerShell
    PrivateData       = @{

        PSData = @{
            Tags = @('winget', 'installer', 'automation', 'techary', 'uninstall', 'intune')
            ProjectUri = 'https://github.com/Techary/TecharyGet'
        }
    }
}
