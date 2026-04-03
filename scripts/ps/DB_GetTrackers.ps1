
param (
    [Parameter(Mandatory=$false,Position=0)]
    [ValidateRange(1,5)]
    [int]$Version=2
)


# Function to load SQLite database
function Import-SQLiteDatabase {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$DatabasePath
    )

    Write-Host "Attempting to open SQLite database at $DatabasePath..." -ForegroundColor DarkCyan

    # SQLite connection string
    $connectionString = "Data Source=$DatabasePath;Version=3;"

    # Create SQLite connection
    $connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList $connectionString
    $connection.Open()

    Write-Host "Successfully connected to SQLite database." -ForegroundColor DarkCyan

    return $connection
}

# Function to fetch and return rows as PSCustomObjects from the SQLite database
function Get-DbTrackers {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$DatabasePath,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,5)]
        [int]$Version=2
    )

    $dbconnection = Import-SQLiteDatabase -DatabasePath $DatabasePath

    try {
        # Query to fetch rows based on the provided version
        $query = "SELECT id, DateAdded, AbsolutePath, AbsoluteUri, Authority, Host, Port, Scheme, Version FROM magnet_links WHERE Version = $Version ORDER BY DateAdded;"

        # Create SQLite command
        $command = $dbconnection.CreateCommand()
        $command.CommandText = $query

        # Execute the query and fetch results
        $reader = $command.ExecuteReader()
        $results = @()

        while ($reader.Read()) {
            # Create a PSCustomObject for each row
            $results += [PSCustomObject]@{
                id           = $reader["id"]
                DateAdded    = $reader["DateAdded"]
                AbsolutePath = $reader["AbsolutePath"]
                AbsoluteUri  = $reader["AbsoluteUri"]
                Authority    = $reader["Authority"]
                Host         = $reader["Host"]
                Port         = $reader["Port"]
                Scheme       = $reader["Scheme"]
                Version      = $reader["Version"]
            }
        }

        $reader.Close()
        return $results
    }
    catch {
        Write-Error "Failed to retrieve data from the SQLite database: $_"
    }
    finally {
        $dbconnection.Close()
    }
}


$RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path

# Define the path to the SQLite database
$DatabasePath = Join-Path "$RootPath" "db"
$DatabaseFile = Join-Path "$DatabasePath" "db.latest.sqlite3"
$PsScriptsPath = Join-Path "$RootPath" "scripts\ps"
$SQLiteDll = Join-Path "$PsScriptsPath" "System.Data.SQLite.dll"

Add-Type -Path $SQLiteDll

Get-DbTrackers -DatabasePath $DatabaseFile -Version $Version

