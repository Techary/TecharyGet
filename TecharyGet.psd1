@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'TecharyGet.psm1'

    # Version number of this module.
    ModuleVersion = '2.2'

    # ID used to uniquely identify this module
    GUID = 'e9c840c8-3c3e-4246-8178-52372d807654'

    # Author of this module
    Author = 'Adam Sweetapple'

    # Company or vendor of this module
    CompanyName = 'Techary'

    # Copyright statement for this module
    Copyright = '(c) 2026 Techary. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'A PowerShell module for managing app installations and uninstalls using Winget Repo, MSI, EXE, ZIP, and MSIX sources. Supports custom logic and Intune deployment.'

    # Functions to export from this module, for best performance, do not use wildcards.
    FunctionsToExport = @(
        # -- Core Installation --
        'Install-TecharyApp',
        'Uninstall-TecharyApp',
        'Test-TecharyApp',       # The new Detection Logic
        
        # -- Specific Installers --
        'Install-NableAgent',  # The custom RMM installer
        'Get-GitHubInstaller', # Useful for manual manifest checking

        # -- Intune Packaging Tools --
        'New-IntunePackage',   # The CLI Packager (with Detect/Uninstall generation)
        'New-IntunePackageUI', # The GUI Packager
        'Show-IntunePackager', # The Wrapper for the MS Utility

        # -- Utilities --
        'Write-PackagerLog'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = @()

    # List of all modules packaged with this module
    # NestedModules = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Intune', 'PackageManagement', 'Install', 'Uninstall', 'Winget', 'RMM', 'Automation')
            
            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''
        }
    }

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Minimum version of the Common Language Runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()
}



