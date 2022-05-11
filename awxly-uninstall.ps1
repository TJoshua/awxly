$currentDirectory = Get-Location
Get-ChildItem $currentDirectory -Filter "Awxly-*.metadata" |
ForEach-Object {
    $wslDistroName = [System.IO.Path]::GetFileNameWithoutExtension($_)

    Write-Host "Uninstalling $wslDistroName..."
    (wsl --unregister $wslDistroName) | Out-Null

    Remove-Item -Path $_
}