$QUALITY_JPG = 80
$PNG_MODE = "lossless"
$QUALITY_PNG = 90

$cwebp = "C:\webp\cwebp.exe"

if (!(Test-Path $cwebp)) {
    Write-Host "cwebp が見つかりません"
    exit
}

$files = Get-ChildItem -Recurse -Include *.jpg,*.jpeg,*.png

foreach ($file in $files) {

    $output = [System.IO.Path]::ChangeExtension($file.FullName, ".webp")

    if (Test-Path $output) {
        Write-Host "スキップ: $output"
        continue
    }

    Write-Host "変換: $($file.FullName) -> $output"

    $ext = $file.Extension.ToLower()

    $success = $false

    if ($ext -eq ".png") {

        if ($PNG_MODE -eq "lossless") {
            & $cwebp -lossless "$($file.FullName)" -o "$output"
        } else {
            & $cwebp -q $QUALITY_PNG "$($file.FullName)" -o "$output"
        }

        if (Test-Path $output) { $success = $true }

    } else {

        & $cwebp -q $QUALITY_JPG "$($file.FullName)" -o "$output"

        if (Test-Path $output) { $success = $true }

        if (!$success) {

            Write-Host "救済処理: RGB変換して再試行"

            $tmp = "$env:TEMP\tmp_webp.png"

            magick "$($file.FullName)" -colorspace sRGB $tmp

            & $cwebp -q $QUALITY_JPG $tmp -o "$output"

            if (Test-Path $output) { $success = $true }

            Remove-Item $tmp -ErrorAction Ignore
        }
    }

    if ($success) {
        Write-Host "成功: 元ファイル削除 $($file.FullName)"
        Remove-Item $file.FullName
    }
    else {
        Write-Host "失敗: $($file.FullName)"
    }
}

Write-Host "完了"