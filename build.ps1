$ErrorActionPreference = 'Stop'

$AppName = 'deepssh'
$DistDir = 'dist'

function Show-Usage {
    Write-Output 'Usage:'
    Write-Output '  .\build.ps1 fmt'
    Write-Output '  .\build.ps1 build [--debug|--profile|--release]'
    Write-Output '  .\build.ps1 package [--debug|--profile|--release]'
    Write-Output ''
    Write-Output 'Defaults:'
    Write-Output '  build   -> --debug'
    Write-Output '  package -> --release'
}

function Get-Mode {
    param(
        [string]$DefaultMode,
        [string[]]$ModeArgs
    )

    $mode = $DefaultMode
    foreach ($arg in $ModeArgs) {
        switch ($arg) {
            '--debug' { $mode = 'debug' }
            '--profile' { $mode = 'profile' }
            '--release' { $mode = 'release' }
            '-h' { Show-Usage; exit 0 }
            '--help' { Show-Usage; exit 0 }
            default {
                Write-Error "Unknown option: $arg"
                Show-Usage
                exit 1
            }
        }
    }
    return $mode
}

function Get-ArchName {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        return 'arm64'
    }
    return 'x64'
}

function Get-ModeDirName {
    param([string]$Mode)

    switch ($Mode) {
        'debug' { return 'Debug' }
        'profile' { return 'Profile' }
        'release' { return 'Release' }
        default { throw "Unsupported mode: $Mode" }
    }
}

function Invoke-Fmt {
    cargo fmt --manifest-path rust/Cargo.toml
    dart format lib test
    flutter_rust_bridge_codegen generate
    flutter analyze
}

function Invoke-Build {
    param([string]$Mode)

    flutter build windows "--$Mode"
}

function Invoke-Package {
    param([string]$Mode)

    Invoke-Build $Mode

    $arch = Get-ArchName
    $modeDir = Get-ModeDirName $Mode
    $source = Join-Path -Path 'build' -ChildPath "windows\$arch\runner\$modeDir"
    $target = Join-Path -Path $DistDir -ChildPath "$AppName-windows-$arch-$Mode"

    if (-not (Test-Path -Path $source -PathType Container)) {
        throw "Build output not found: $source"
    }

    if (Test-Path -Path $target) {
        Remove-Item -Path $target -Recurse -Force
    }

    New-Item -ItemType Directory -Path $target | Out-Null
    Copy-Item -Path (Join-Path -Path $source -ChildPath '*') -Destination $target -Recurse -Force
    Write-Output "Packaged: $target"
}

if ($args.Count -eq 0) {
    Show-Usage
    exit 1
}

$command = $args[0]
$commandArgs = @()
if ($args.Count -gt 1) {
    $commandArgs = $args[1..($args.Count - 1)]
}

switch ($command) {
    'fmt' {
        if ($commandArgs.Count -ne 0) {
            Write-Error 'fmt does not accept options.'
            Show-Usage
            exit 1
        }
        Invoke-Fmt
    }
    'build' {
        Invoke-Build (Get-Mode 'debug' $commandArgs)
    }
    'package' {
        Invoke-Package (Get-Mode 'release' $commandArgs)
    }
    '-h' { Show-Usage }
    '--help' { Show-Usage }
    default {
        Write-Error "Unknown command: $command"
        Show-Usage
        exit 1
    }
}
