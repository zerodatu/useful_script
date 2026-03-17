@echo off
setlocal EnableDelayedExpansion

REM 変換対象の拡張子
set "EXT=mkv"

REM 出力ファイル名に付ける接尾辞
set "SUFFIX=_h265"

REM カレントディレクトリ以下を再帰的に走査
for /r %%F in (*.%EXT%) do (

    REM すでに _h265 が付いたファイルは再処理しない
    echo %%~nF | findstr /i /c:"%SUFFIX%" >nul
    if not errorlevel 1 (
        echo Skip already converted: %%F
    ) else (

        REM 出力ファイル名を生成
        set "OUTPUT=%%~dpF%%~nF%SUFFIX%%%~xF"

        REM 既に出力ファイルが存在するならスキップ
        if exist "!OUTPUT!" (
            echo Skip already exists: !OUTPUT!
        ) else (
            echo Processing: %%F

            ffmpeg -nostdin -i "%%F" ^
                -c:v libx265 ^
                -crf 23 ^
                -preset medium ^
                -c:a copy ^
                "!OUTPUT!"

            if errorlevel 1 (
                echo Error converting: %%F
            ) else (
                echo Successfully converted: !OUTPUT!
            )
        )
    )
)

endlocal
pause