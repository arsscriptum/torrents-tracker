



# Function to load SQLite database
function Load-SQLiteDatabase {
    param (
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

# Function to insert a URI record into the SQLite database, including the Version
function Insert-UriIntoDatabase {
    param (
        [System.Data.SQLite.SQLiteConnection]$Connection,
        [PSCustomObject]$UriObject,
        [int]$Version
    )

    $dateAdded = [DateTime]::Now

    $query = @"
    INSERT INTO magnet_links (DateAdded, AbsolutePath, AbsoluteUri, Authority, Host, Port, Scheme, Version)
    VALUES (@DateAdded, @AbsolutePath, @AbsoluteUri, @Authority, @Host, @Port, @Scheme, @Version);
"@

    $command = $Connection.CreateCommand()
    $command.CommandText = $query

    # Add parameters to prevent SQL injection
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@DateAdded", $dateAdded))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@AbsolutePath", $UriObject.AbsolutePath))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@AbsoluteUri", $UriObject.AbsoluteUri))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Authority", $UriObject.Authority))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Host", $UriObject.Host))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Port", $UriObject.Port))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Scheme", $UriObject.Scheme))
    $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Version", $Version))

    # Execute the insert command
    $command.ExecuteNonQuery() | Out-Null

    Write-Host "Inserted URI: $($UriObject.AbsoluteUri) with Version: $Version into the database." -ForegroundColor DarkCyan
}

# Function to read URIs from a text file and insert them into the SQLite DB, including the Version
function Add-UriLinksAndInsert {
    param (
        [string]$LinkFile,
        [string]$DatabaseFile,
        [int]$Version
    )

    Write-Host "Processing file $LinkFile and inserting into the database with version $Version..." -ForegroundColor DarkYellow

    # Load SQLite connection
    $connection = Load-SQLiteDatabase -DatabasePath $DatabaseFile

    if ($connection) {
        # Use Get-UriInfoFromFile to read URIs from the file
        $uriArray = Get-UriInfoFromFile -FilePath $LinkFile

        Write-Host "Inserting $(($uriArray).Count) URIs from file $LinkFile..." -ForegroundColor DarkYellow

        # Iterate over each URI object and insert into the database with the specified version
        foreach ($uri in $uriArray) {
            Insert-UriIntoDatabase -Connection $connection -UriObject $uri -Version $Version
        }

        # Close the SQLite connection
        $connection.Close()
        Write-Host "Successfully inserted all URI records into the database with version $Version." -ForegroundColor DarkYellow
    }
    else {
        Write-Error "Failed to open SQLite database."
    }
}

# Function to read URIs from two text files and insert them into the SQLite DB, each with different version numbers
function Add-MagnetLinksToDb {
    param (
        [string]$DatabaseFile
    )

    Write-Host "Starting to add magnet links to the SQLite database at $DatabaseFile..." -ForegroundColor DarkRed

    # Load SQLite assembly
    $PsScriptsPath = Join-Path "$RootPath" "scripts\ps"
    $SQLiteDll = Join-Path "$PsScriptsPath" "System.Data.SQLite.dll"
    $InteropDll = Join-Path "$PsScriptsPath" "SQLite.Interop.dll"

    Add-Type -Path $SQLiteDll
    Add-Type -Path $InteropDll

    Write-Host "Successfully loaded SQLite assemblies." -ForegroundColor DarkRed

    # Define the file containing the magnet links
    $LinkFile = Join-Path "$PsScriptsPath" "links.txt"
    $LinkFile_v2 = Join-Path "$PsScriptsPath" "links_v2.txt"


    Write-Host "Adding links from $LinkFile with version 1..." -ForegroundColor DarkRed
    Add-UriLinksAndInsert -LinkFile $LinkFile -DatabaseFile $DatabaseFile -Version 1

    Write-Host "Adding links from $LinkFile_v2 with version 2..." -ForegroundColor DarkRed
    Add-UriLinksAndInsert -LinkFile $LinkFile_v2 -DatabaseFile $DatabaseFile -Version 2

    Write-Host "All magnet links successfully added to the SQLite database." -ForegroundColor DarkRed
}

$RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path

# Define the path to the SQLite database
$DatabasePath = Join-Path "$RootPath" "db"
$DatabaseFile = Join-Path "$DatabasePath" "db.sqlite3"
$DateStr = ((Get-date).GetDateTimeFormats()[21]).Replace(':',"-")
$DatabaseFileBackup = Join-Path "$DatabasePath" ("db_bak_" + $DateStr + ".sqlite3")

Copy-Item $DatabaseFile $DatabaseFileBackup -Verbose
Add-MagnetLinksToDb -DatabaseFile $DatabaseFile
