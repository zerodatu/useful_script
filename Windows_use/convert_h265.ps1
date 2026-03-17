$Ext = "mkv"
$Suffix = "_h265"

Get-ChildItem -Path . -Recurse -File -Filter "*.$Ext" | ForEach-Object {
    $inputFile = $_.FullName

    if ($_.BaseName -like "*$Suffix") {
        Write-Host "Skip already converted: $inputFile"
        return
    }

    $outputFile = Join-Path $_.DirectoryName ($_.BaseName + $Suffix + ".mp4")

    if (Test-Path $outputFile) {
        Write-Host "Skip already exists: $outputFile"
        return
    }

    Write-Host "Processing: $inputFile"

    & ffmpeg `
        -nostdin `
        -y `
        -i $inputFile `
        -map 0:v:0 `
        -map 0:a? `
        -c:v libx265 `
        -crf 23 `
        -preset medium `
        -c:a aac `
        -b:a 192k `
        $outputFile

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully converted: $outputFile"
    }
    else {
        Write-Host "Error converting: $inputFile"
    }
}