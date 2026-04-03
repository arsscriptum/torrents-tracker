#┌────────────────────────────────────────────────────────────────────────────────┐
#│                                                                                │
#│   Get-TrackersFromDatabase.ps1                                                       │
#│   Get Pirate Bay Categories                                                    │
#│                                                                                │
#┼────────────────────────────────────────────────────────────────────────────────┼
#│   Guillaumep  <guillaumeplante.qc@gmail.com                                    │
#└────────────────────────────────────────────────────────────────────────────────┘

param (
     [Parameter(Position = 0,Mandatory=$false)]
    [ValidateRange(1,5)]
    [int]$Ver=4
)

$CommonPath = (Resolve-Path "$PSScriptRoot\common.ps1").Path
. "$CommonPath"

$DbEnginePath = Get-DbEnginePath 
. "$DbEnginePath"



# Function to fetch and return rows as PSCustomObjects from the SQLite database
function Get-TrackersFromDatabase {
    param (
        [Parameter(Position = 0,Mandatory=$false)]
        [ValidateRange(1,5)]
        [int]$Version=4
    )

    
    $dbPath = Get-DbPath
    $ScriptsPath = Get-ScriptsPath
    $sqlDbPath = Join-Path "$dbPath" "db.latest.sqlite3"
    $assPath = Join-Path "$ScriptsPath" "System.Data.SQLite.dll"

    try {
        $db = [SQLiteDatabase]::new($sqlDbPath, "$assPath")
        $db.Create()
        # Query to fetch rows based on the provided version
        $query = "SELECT id, DateAdded, AbsolutePath, AbsoluteUri, Authority, Host, Port, Scheme, Version FROM magnet_links WHERE Version = $Version ORDER BY DateAdded;"

        # Create SQLite command
        $command = $db.NewCommand($query)

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
}


Get-TrackersFromDatabase $Ver