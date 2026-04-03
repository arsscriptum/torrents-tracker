#┌────────────────────────────────────────────────────────────────────────────────┐
#│                                                                                │
#│   Get-PBayTrackers.ps1                                                       │
#│   Get Pirate Bay Categories                                                    │
#│                                                                                │
#┼────────────────────────────────────────────────────────────────────────────────┼
#│   Guillaumep  <guillaumeplante.qc@gmail.com                                    │
#└────────────────────────────────────────────────────────────────────────────────┘


# Get the list of trackers from https://thepiratebay.org/static/main.js

<#
    udp://tracker.opentrackr.org:1337
    udp://open.stealth.si:80/announce
    udp://tracker.torrent.eu.org:451/announce
    udp://tracker.bittor.pw:1337/announce
    udp://public.popcorn-tracker.org:6969/announce
    udp://tracker.dler.org:6969/announce
    udp://exodus.desync.com:6969
    udp://open.demonii.com:1337/announce
#>

function Get-PBayTrackers { 
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

Get-PBayTrackers