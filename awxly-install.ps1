param
(
    [string]
    $storageDirectory = "",
    [string]
    $tempDirectory = "",
    [string]
    $tunnelPort = "5000"
)

$currentDirectory = Get-Location

if ([string]::IsNullOrWhiteSpace($storageDirectory))
{
    $storageDirectory = Join-Path $currentDirectory "storage"
}

if ([string]::IsNullOrWhiteSpace($tempDirectory))
{
    $tempDirectory = Join-Path $currentDirectory "temp"
}

# Ensure that the storage directory exists
try
{
    New-Item -Path $storageDirectory -ItemType Directory -Force | Out-Null
}
catch
{
    Write-Host "Fatal Error: Could not ensure that temporary directory exists."
    exit 1
}

# Ensure that the temporary directory exists
try
{
    New-Item -Path $tempDirectory -ItemType Directory -Force | Out-Null
}
catch
{
    Write-Host "Fatal Error: Could not ensure that temporary directory exists."
    exit 1
}

Write-Host "Using storage directory: $storageDirectory"
Write-Host "Using temporary directory: $tempDirectory"

# Download the latest-releases.yaml file as a string so we can determine which file to download
$baseAlpineUrl = "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64"
$webClient = New-Object System.Net.WebClient
$latestReleaseYaml = $webClient.DownloadString("$baseAlpineUrl/latest-releases.yaml");
# Search for the line that matches the target distribution
$alpineDistroName = "alpine-minirootfs"
$searchPattern = "flavor: $alpineDistroName`n  file: "
$patternIndex = $latestReleaseYaml.IndexOf($searchPattern);

if ($patternIndex -lt 0)
{
    Write-Host "Fatal Error: Could not determine the appropriate Alpine Linux release to download."
    exit 1
}

# Perform an additional search to find the ending index of the distribution name
$fileNameStartIndex = $patternIndex + $searchPattern.Length
$newlineIndex = $latestReleaseYaml.IndexOf("`n", $fileNameStartIndex)

if ($newlineIndex -lt 0)
{
    Write-Host "Fatal Error: Could not determine the appropriate Alpine Linux release to download."
    exit 1
}

# Determine the name of the file to download
$downloadFileName = $latestReleaseYaml.Substring($fileNameStartIndex, $newlineIndex - $fileNameStartIndex)
# Determine the path to download the file to
$downloadFilePath = "$tempDirectory\$downloadFileName"

# Only download the file if it does not exist in the temp directory
if (-not(Test-Path -PathType Leaf -Path $downloadFilePath))
{
    $downloadUrl = "$baseAlpineUrl/$downloadFileName"
    Write-Host "Downloading $downloadUrl..."

    try
    {
        $webClient.DownloadFile($downloadUrl, $downloadFilePath)
    }
    catch
    {
        Write-Host "Fatal Error: Failed to download the latest Alpine Linux release."
        exit 1
    }
}
else
{
    Write-Host "Latest Alpine Linux release already exists in temporary folder, skipping download..."
}

# Build a string containing the distribution release version number
$releaseVersion = $downloadFileName.Substring($alpineDistroName.Length + 1)
$releaseVersion = $releaseVersion.Substring(0, $releaseVersion.IndexOf("-"))

# Determine the name of our WSL distribution
$wslDistroName = "Awxly-$releaseVersion"

# Invoke WSL to output a list of installed distributions
$wslDistros = [System.Text.Encoding]::Unicode.GetString([System.Text.Encoding]::Default.GetBytes((wsl --list -q)))
# Find our distribution within the list returned from the WSL command
$wslDistroIndex = $wslDistros.IndexOf($wslDistroName)

# Check to see if the WSL distribution is already installed
if ($wslDistroIndex -ge 0)
{
    Write-Host "$wslDistroName is already installed."
    exit
}

# Determine the path we should use for the WSL distribution's storage
$distroStorageDirectory = Join-Path $storageDirectory $wslDistroName
$distroKubeStorageDirectory = Join-Path $distroStorageDirectory "k8s"

# Ensure that the distribution-specific storage directory exists
try
{
    New-Item -Path $distroStorageDirectory -ItemType Directory -Force | Out-Null
    New-Item -Path $distroKubeStorageDirectory -ItemType Directory -Force | Out-Null
}
catch
{
    Write-Host "Fatal Error: Could not ensure that the distribution storage directory exists."
    exit 1
}

# Convert the k8s storage path to one that linux can access
$distroKubeStorageDirectory = (wsl wslpath -a "'$distroKubeStorageDirectory'")

# Build a string with a path to the current working directory and distribution name as the file
$versionFilePath = Join-Path $currentDirectory "$wslDistroName.metadata"

# Create a file indicating the installed version (for uninstall to use as an indicator)
if (-not(Test-Path -PathType Leaf -Path $versionFilePath))
{
    Out-File -FilePath $versionFilePath
}

# Install the WSL distribution
Write-Host "Installing WSL distribution $wslDistroName..."
wsl --import $wslDistroName $distroStorageDirectory $downloadFilePath

# Copy wsl.conf to the distribution and restart it
$wslConfigPath = Join-Path $currentDirectory "wsl.conf"
$wslConfigPath = (wsl wslpath -a "'$wslConfigPath'")
wsl -d $wslDistroName /bin/ash -ilc "cp $wslConfigPath /etc/wsl.conf"
wsl --terminate $wslDistroName

# Install the bash shell
wsl -d $wslDistroName /bin/ash -ilc "apk update && apk add bash bash-doc bash-completion"
# Update the /etc/passwd file to use the bash shell for the root user
wsl -d $wslDistroName /bin/ash -ilc "sed -i 's#root:x:0:0:root:/root:/bin/ash#root:x:0:0:root:/root:/bin/bash#' /etc/passwd"

# Run the awxly install bash script
$awxlyInstallScriptPath = Join-Path $currentDirectory "awxly-install.sh"
$awxlyInstallScriptPath = (wsl wslpath -a "'$awxlyInstallScriptPath'")
wsl -d $wslDistroName /bin/bash -ilc "bash -il $awxlyInstallScriptPath '$distroKubeStorageDirectory' $tunnelPort" 2>&1 | %{ "$_" }