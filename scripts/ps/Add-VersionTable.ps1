

function Add-VersionTable {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VersionNumber,

        [Parameter(Mandatory=$true)]
        [string]$ScriptName
    )

    try {
        # Load the SQLite assembly using Add-SqlLiteTypes function
        Add-SqlLiteTypes

        # Create and open the SQLite connection
        $databasePath = Join-Path -Path (Get-DbPath) -ChildPath "db.sqlite3"
        $connectionString = "Data Source=$databasePath;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()

        try {
            # SQL command to create the schema_version table if it doesn't exist
            $createTableSql = @"
CREATE TABLE IF NOT EXISTS schema_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version_number TEXT NOT NULL,
    applied_at TEXT DEFAULT CURRENT_TIMESTAMP,
    script_name TEXT
);
"@
            # Execute the SQL command to create the table
            $command = $connection.CreateCommand()
            $command.CommandText = $createTableSql
            $command.ExecuteNonQuery()

            # SQL command to insert the version number and script name into the schema_version table
            $insertSql = @"
INSERT INTO schema_version (version_number, script_name)
VALUES ('$VersionNumber', '$ScriptName');
"@
            # Execute the SQL command to insert the version information
            $command.CommandText = $insertSql
            $command.ExecuteNonQuery()

            Write-Host "Version '$VersionNumber' added successfully with script name '$ScriptName'."
        }
        catch {
            Write-Error "An error occurred while adding the version table: $_"
            throw "Error executing SQL commands. Please verify the database connection and SQL syntax."
        }
        finally {
            # Close the connection
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
            $connection.Dispose()
        }
    }
    catch {
        Write-Error "An error occurred in Add-VersionTable: $_"
        throw "Error in Add-VersionTable function."
    }
}

# Example usage:
# Add-VersionTable -VersionNumber "1.0.0" -ScriptName "Initial Schema Creation"


function Add-VersionToSchema {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VersionNumber,

        [Parameter(Mandatory=$true)]
        [string]$ScriptName
    )

    try {
        # Load the SQLite assembly using Add-SqlLiteTypes function
        Add-SqlLiteTypes

        # Create and open the SQLite connection
        $databasePath = Join-Path -Path (Get-DbPath) -ChildPath "db.sqlite3"
        $connectionString = "Data Source=$databasePath;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()

        try {
            # SQL command to create the schema_version table if it doesn't exist
            $createTableSql = @"
CREATE TABLE IF NOT EXISTS schema_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version_number TEXT NOT NULL,
    applied_at TEXT DEFAULT CURRENT_TIMESTAMP,
    script_name TEXT
);
"@
            # Execute the SQL command to create the table
            $command = $connection.CreateCommand()
            $command.CommandText = $createTableSql
            $command.ExecuteNonQuery()

            # SQL command to insert the version number and script name into the schema_version table
            $insertSql = @"
INSERT INTO schema_version (version_number, script_name)
VALUES (@version, @scriptName);
"@
            # Execute the SQL command to insert the version information
            $command.CommandText = $insertSql
            $command.Parameters.Add((New-Object Data.SQLite.SQLiteParameter("@version", $VersionNumber)))
            $command.Parameters.Add((New-Object Data.SQLite.SQLiteParameter("@scriptName", $ScriptName)))
            $command.ExecuteNonQuery()

            Write-Host "Version '$VersionNumber' added successfully with script name '$ScriptName'."
        }
        catch {
            Write-Error "An error occurred while adding the version information to the schema_version table: $_"
            throw "Error executing SQL commands. Please verify the database connection and SQL syntax."
        }
        finally {
            # Close the connection
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
            $connection.Dispose()
        }
    }
    catch {
        Write-Error "An error occurred in Add-VersionToSchema: $_"
        throw "Error in Add-VersionToSchema function."
    }
}

# Example usage:
# Add-VersionToSchema -VersionNumber "2.1.0" -ScriptName "First Release"
