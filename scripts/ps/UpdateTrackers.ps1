#┌────────────────────────────────────────────────────────────────────────────────┐
#│                                                                                │
#│   UpdateTrackers.ps1                                                           │
#│                                                                                │
#┼────────────────────────────────────────────────────────────────────────────────┼
#└────────────────────────────────────────────────────────────────────────────────┘


$CommonPath = (Resolve-Path "$PSScriptRoot\common.ps1").Path
. "$CommonPath"

$DbEnginePath = Get-DbEnginePath 
. "$DbEnginePath"



$Script:RootPath = ""  
$Script:Initialized = $False
$Script:DatabasePath = ""  
$Script:DatabaseFile = ""  
$Script:PsScriptsPath = ""  
$Script:SQLiteDll = ""  


function Get-RootPath {
    return (Resolve-Path "$PSScriptRoot\..\..").Path
}

function Get-ScriptsPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "scripts\ps"
}

function Get-DbPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "db"
}




function Get-LatestTrackers
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet('all','udp','http','https','ws','wss')]
        [string]$Type='udp'
    )

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    
    try {
        $Url = 'https://cable.ayra.ch/tracker/list.php?prot={0}&opt=json' -f $Type
        $res = iwr -Uri $Url
        if($res.StatusCode -ne 200){throw "failed $($res.StatusDescription)"}
        [System.Collections.Generic.List[string]]$Trackers = $res.Content | ConvertFrom-Json
        if($Format){
            ForEach($tracker in $Trackers){
                $l = '`t"{0}",' -f $tracker
                Write-Output $l
            }
        }else{
            $Trackers
        }
    }catch {

        Show-ExceptionDetails $_
    }
}


function Invoke-RequestPBayTrackers { 
    [CmdletBinding(SupportsShouldProcess)]
    param()

    try{

        $CurrentProgressPref = $ProgressPreference
        $ProgressPreference  = 'SilentlyContinue'

        [string]$BaseUri = "https://thepiratebay.org/static/main.js"
        [string]$TmpFileName = (New-Guid).Guid
        [string]$TmpFilePath = "{0}\{1}{2}" -f "$ENV:Temp", "$TmpFileName", ".dat"

        $Res = Invoke-WebRequest -Uri "$BaseUri" -OutFile "$TmpFilePath" -PassThru
        $ProgressPreference = $CurrentProgressPref

        [string]$content = Get-content -Path "$TmpFilePath" -Raw

        $i = $content.IndexOf('function print_trackers()')
        $i1 = $content.IndexOf('{',$i)
        $i2 = $content.IndexOf('}',$i1) + 1

        $function_code = $content.Substring($i, $i2 - $i)

        $Tag1 = "'udp://"
        $Tag1Len = $Tag1.Length
        $Tag2 = "'"

        [system.collections.arraylist]$indexes = [system.collections.arraylist]::new()
        $code_len = $function_code.Length
        $startindex = 0
        while($startindex -lt $code_len){
            $startindex = $function_code.IndexOf($Tag1,$startindex + 1)
            if($startindex -eq -1){
                break;
            }
            [void]$indexes.Add($startindex)
        }
        
        function GetSubStringTracker([int]$startindex){
            $j = $function_code.IndexOf($Tag1,$startindex) + 1
            $j1 = $function_code.IndexOf($Tag2,$j) 
            $local_tracker = $function_code.Substring($j, $j1 - $j )
            return $local_tracker
        }

        [system.collections.arraylist]$trackers = [system.collections.arraylist]::new()
        ForEach($id in $indexes){
            $t = GetSubStringTracker($id)
            [void]$trackers.Add($t)
        }

        $trackers

    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 


 
function Get-TrackersLastVersion {
    param (
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,5)]
        [int]$Version=2
    )

    try {

    
        $dbPath = Get-DbPath
        $ScriptsPath = Get-ScriptsPath
        $sqlDbPath = Join-Path "$dbPath" "db.latest.sqlite3"
        $assPath = Join-Path "$ScriptsPath" "System.Data.SQLite.dll"


        [System.Data.SQLite.SQLiteConnection]$conn = (Import-SQLiteDatabase -DatabasePath $Script:DatabaseFile) -as [System.Data.SQLite.SQLiteConnection]

        # Query to fetch the highest version number
        $query = "SELECT MAX(Version) AS LastVersion FROM magnet_links;"

        # Create SQLite command
        $command = ([System.Data.SQLite.SQLiteConnection]$conn -as [System.Data.SQLite.SQLiteConnection]).CreateCommand()
        $command.CommandText = $query

        # Execute the query and fetch the result
        $reader = $command.ExecuteReader()
        $lastVersion = $null

        if ($reader.Read()) {
            $lastVersion = $reader["LastVersion"]
        }

        $reader.Close()
        return $lastVersion
    }
    catch {
        Write-Error "Failed to retrieve the last version from the SQLite database: $_"
    }

}


function Out-Box{
    Write-Host "┏━━━━━━━━━━━━━━━━━━┓" -f DarkMagenta
    Write-Host "┃" -NoNewLine -f DarkMagenta
    Write-Host "  UPDATE TRACKERS" -NoNewLine -f DarkRed
    Write-Host " ┃" -f DarkMagenta
    Write-Host "┗━━━━━━━━━━━━━━━━━━┛" -f DarkMagenta
}



function Add-TrackerInDatabase {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true, position=0, ValueFromPipeline = $true)]
        [PSCustomObject]$UriObject,
        [Parameter(Mandatory=$false)]
        [int]$Version=3
    )

    process{
        $dateAdded = [DateTime]::Now

        $query = @"
        INSERT INTO magnet_links (DateAdded, AbsolutePath, AbsoluteUri, Authority, Host, Port, Scheme, Version)
        VALUES (@DateAdded, @AbsolutePath, @AbsoluteUri, @Authority, @Host, @Port, @Scheme, @Version);
"@


        $db = [SQLiteDatabase]::new($sqlDbPath, "$assPath")
        $db.Create()

        $command = $ENV:trkDbConn.CreateCommand()
        $command.CommandText = $query

        $NewPort = $UriObject.Port
        if($NewPort -eq -1){
            $NewPort = 80
        }

         # Create SQLite command
        $command = $db.NewCommand($query)

        $command.CommandText = $query

        $absuri = $UriObject.AbsoluteUri.TrimEnd('/')
        # Add parameters to prevent SQL injection
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@DateAdded", $dateAdded))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@AbsolutePath", $UriObject.AbsolutePath))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@AbsoluteUri", $absuri))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Authority", $UriObject.Authority))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Host", $UriObject.Host))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Port", $NewPort))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Scheme", $UriObject.Scheme))
        $r = $command.Parameters.Add([System.Data.SQLite.SQLiteParameter]::new("@Version", $Version))

        # Execute the insert command
        $command.ExecuteNonQuery() | Out-Null

        Write-Host "Inserted URI: $($UriObject.AbsoluteUri) with Version: $Version into the database." -ForegroundColor DarkCyan
    }
}

function GetLastVersion {
    # Get the list of trackers from https://thepiratebay.org/static/main.js
    $Script:RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path

    # Define the path to the SQLite database
    $Script:DatabasePath = Join-Path "$RootPath" "db"
    $Script:DatabaseFile = Join-Path "$DatabasePath" "db.latest.sqlite3"
    $Script:PsScriptsPath = Join-Path "$RootPath" "scripts\ps"
    $Script:SQLiteDll = Join-Path "$PsScriptsPath" "System.Data.SQLite.dll"
    $ENV:trkDbConn = Import-SQLiteDatabase -DatabasePath $Script:DatabaseFile
    Add-Type -Path $SQLiteDll

    Add-SqlLiteTypes

    Out-Box

    Write-Host "⚡ Getting latest tracker version in DB..." -f DarkCyan
    $TrackersLastVersion = Get-TrackersLastVersion
    $TrackersLastVersion
}


function DoUpdate {
    # Get the list of trackers from https://thepiratebay.org/static/main.js
    $Script:RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path

    # Define the path to the SQLite database
    $Script:DatabasePath = Join-Path "$RootPath" "db"
    $Script:DatabaseFile = Join-Path "$DatabasePath" "db.latest.sqlite3"
    $Script:PsScriptsPath = Join-Path "$RootPath" "scripts\ps"
    $Script:SQLiteDll = Join-Path "$PsScriptsPath" "System.Data.SQLite.dll"

    Add-Type -Path $SQLiteDll

    Add-SqlLiteTypes

    Out-Box

    Write-Host "⚡ Getting latest tracker version in DB..." -f DarkCyan
    $TrackersLastVersion = Get-TrackersLastVersion



    [System.Collections.ArrayList]$DbTrackers = Get-DbTrackers -Version $TrackersLastVersion  
    $DbTrackersCount =  $DbTrackers.Count


    [System.Collections.ArrayList]$PBayTrackersLatest = Get-LatestTrackers
    [System.Collections.ArrayList]$PBayTrackersCurrent = $DbTrackers.AbsoluteUri

    Write-Host "============================================" -f DarkGray
    Write-Host "trackers currently in database, version $TrackersLastVersion" -f DarkCyan
    Write-Host "=============================================" -f DarkGray
    ForEach($tracker in $PBayTrackersCurrent){
        Write-Host "$tracker" -f DarkYellow
    }
    Write-Host "============================================" -f DarkGray
    Write-Host "         trackers currently online          " -f DarkCyan
    Write-Host "=============================================" -f DarkGray
    ForEach($tracker in $PBayTrackersLatest){
        Write-Host "$tracker" -f DarkRed
    }

    $Missing=0
    $Total=0
    Write-Host "⚡ Latest Trackers count $DbTrackersCount"
    ForEach($tracker in $PBayTrackersLatest){
        $IsIn = $PBayTrackersCurrent.Contains($tracker.TrimEnd('/'))
        if($IsIn){
            Write-Host "✔  Latest tracker $tracker is in the DB Already!" -f DarkGray
        }else{
            Write-Host "❌ [$Missing / $DbTrackersCount] missing tracker in db: $tracker" -f DarkGray
            $Missing++

        }
    }
    Write-Host "Missing $Missing trackers." -f Yellow
    Write-Host "⚜ Do you want to add new trackers to the database (y/N) ?" -f DarkRed -NoNewLine
    $a = Read-Host "?"
    if($a -ne 'y'){return}

    $NewVersion=$TrackersLastVersion+1
    Write-Host "⚡ NewVersion  $NewVersion"
    ForEach($tracker in $PBayTrackersLatest){
        [Uri]$u = $tracker.TrimEnd('/')
        Write-Host "$tracker adding $($u.AbsoluteUri)"
        $u | Add-TrackerInDatabase -Version $NewVersion
    }
}
