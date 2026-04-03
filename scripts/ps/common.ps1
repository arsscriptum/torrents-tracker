

function Get-RootPath {
    return (Resolve-Path "$PSScriptRoot\..\..").Path
}

function Get-ScriptsPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "scripts\ps"
}


function Get-DbPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "db"
}

function Add-SqlLiteTypes {
    $assemblyPath = Join-Path -Path (Get-ScriptsPath) -ChildPath"System.Data.SQLite.dll"
    try{
        Add-Type -Path "$assemblyPath" -ErrorAction Stop
        Write-Host "SQLite assembly $assembly loaded successfully."
    }catch{
        Write-Warning "Failed to load SQLite assembly $assembly : $_"
    }
}


function Get-DbEnginePath {
    $path = Get-ScriptsPath  
    $dbengine = Join-Path $path "DatabaseEngine.ps1"
    $dbengine
}