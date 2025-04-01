# 8x8 Work Installer Script
try {
    # Define the base URL for the MSI files
    $baseUrl = "https://work-desktop-assets.8x8.com/prod-publish/ga"
    
    # Define the latest version manually or dynamically fetch it if possible
    $latestVersion = "v8.20.2-12"  # Replace this with dynamic fetching logic if available

    # Construct the download URLs
    $latestUrlX64 = "$baseUrl/work-64-msi-$latestVersion.msi"
    $latestUrlARM64 = "$baseUrl/work-arm64-msi-$latestVersion.msi"

    Invoke-LogMessage "Constructed x64 URL: $latestUrlX64"
    Invoke-LogMessage "Constructed ARM64 URL: $latestUrlARM64"

    # Download installers
    if ($arch.CSDescription -eq "ARM processor family") {
        $Download.DownloadFile($latestUrlARM64, $filearm64)
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile($latestUrlX64, $filex64)
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
    }

    # Install 8x8 Work based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/quiet /norestart" -Wait
        Invoke-LogMessage "Successfully installed 8x8 Work for ARM64."
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/quiet /norestart" -Wait
        Invoke-LogMessage "Successfully installed 8x8 Work for x64."
    }
} catch {
    Invoke-LogMessage "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}