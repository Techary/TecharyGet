Try {
    $installerUrlX64 = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=ProPlus2024Retail&platform=x64&language=en-us&version=O16GA"
    $installerUrlARM64 = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=ProPlus2024Retail&platform=x64&language=en-us&version=O16GA"
    
    
    Invoke-LogMessage "Installer URL: $installerUrlX64"
    
    if (-not $installerUrlX64 -and -not $installerUrlARM64) {
    throw "Installer URLs not found in YAML."
    }
    
    if ($arch -eq "ARM processor family") {
    if (-not $installerUrlARM64) {
        throw "ARM64 installer URL not found in YAML."
    }
    try {
        Invoke-WebRequest -Uri $installerUrlarm64 -OutFile $filearm64
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } catch {
        Invoke-LogMessage "Error downloading ARM64 installer: $($_.Exception.Message)"
        throw
    }
    
    # Verify the file exists
    if (-not (Test-Path -Path $filearm64)) {
        throw "The ARM64 installer file does not exist at $filearm64. Download may have failed."
    }
    
    } else {
    if (-not $installerUrlX64) {
        throw "x64 installer URL not found in YAML."
    }
    try {
        Invoke-WebRequest -Uri $installerUrlX64 -OutFile $filex64
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
    } catch {
        Invoke-LogMessage "Error downloading x64 installer: $($_.Exception.Message)"
        throw
    }
    
    # Verify the file exists
    if (-not (Test-Path -Path $filex64)) {
        throw "The x64 installer file does not exist at $filex64. Download may have failed."
    }
    }
    
    # Start installation here
    if ($arch -like "*ARM*") {
    Invoke-LogMessage "Downloaded arm64 installer to $local:filearm64"
    $renamedFile = Join-Path -Path $local:folderPath -ChildPath "MSOffice2024_Installer_arm64.exe"
    Rename-Item -Path $local:filearm64 -NewName $renamedFile
    Invoke-LogMessage "Renamed installer to: $renamedFile"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
    Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
    Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
    Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
    $renamedFile = Join-Path -Path $local:folderPath -ChildPath "MSOffice2024_Installer_x64.exe"
    Rename-Item -Path $local:filex64 -NewName $renamedFile
    Invoke-LogMessage "Renamed installer to: $renamedFile"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
    Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
    Invoke-LogMessage "Removed installer: $renamedFile"
}
Invoke-LogMessage "Successfully installed Microsoft Office 2024."
} catch {
Invoke-LogMessage "Error installing Microsoft Office 2024: $($_.Exception.Message)"
}