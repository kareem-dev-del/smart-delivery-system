param(
    [string]$Device = "ZY22LSD2VD"
)

$ErrorActionPreference = "Continue"

$stages = [ordered]@{
    "Launching"       = 5
    "Checking"        = 10
    "Downloading"     = 20
    "Preparing"       = 30
    "Compiling"       = 55
    "Assembling"      = 80
    "Installing"      = 95
    "Finished"        = 100
}

$currentProgress = 0
$currentStage = "Starting"
$startTime = Get-Date

function Show-Progress {
    param(
        [int]$Percent,
        [string]$Stage
    )

    $elapsed = (Get-Date) - $startTime
    $time = "{0:hh\:mm\:ss}" -f $elapsed

    Write-Progress `
        -Activity "Flutter Build" `
        -Status "$Percent% | $Stage | Elapsed: $time" `
        -PercentComplete $Percent
}

Show-Progress 0 "Starting Flutter..."

# Start Flutter and capture its output
flutter run -d $Device --verbose 2>&1 | ForEach-Object {

    $line = $_.ToString()

    # Keep Flutter's normal output visible
    Write-Host $line

    # Detect stages
    if ($line -match "Launching .* in debug mode") {
        $currentStage = "Launching"
        $currentProgress = 5
    }
    elseif ($line -match "Checking the license") {
        $currentStage = "Checking Android SDK licenses"
        $currentProgress = 10
    }
    elseif ($line -match "Preparing.*Install") {
        $currentStage = "Downloading / Installing Android component"
        $currentProgress = 20
    }
    elseif ($line -match "Downloading") {
        $currentStage = "Downloading dependencies"
        $currentProgress = 25
    }
    elseif ($line -match "Running Gradle task") {
        $currentStage = "Running Gradle build"
        $currentProgress = 35
    }
    elseif ($line -match "assembleDebug") {
        $currentStage = "Gradle: assembleDebug"
        $currentProgress = 50
    }
    elseif ($line -match "Compiling") {
        $currentStage = "Compiling"
        $currentProgress = 60
    }
    elseif ($line -match "Built .*\.apk") {
        $currentStage = "APK built"
        $currentProgress = 85
    }
    elseif ($line -match "Installing") {
        $currentStage = "Installing APK on device"
        $currentProgress = 95
    }
    elseif ($line -match "Syncing files") {
        $currentStage = "Syncing files to device"
        $currentProgress = 98
    }
    elseif ($line -match "Application finished") {
        $currentStage = "Finished"
        $currentProgress = 100
    }

    Show-Progress $currentProgress $currentStage
}

Write-Progress `
    -Activity "Flutter Build" `
    -Completed `
    -Status "Finished"
```
