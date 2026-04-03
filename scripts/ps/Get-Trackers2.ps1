

#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Get-Trackers2.ps1                                                             ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝



function Get-Trackers
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

        ForEach($t in $Trackers){
            $u=[uri]$t
            $scheme=$u.Scheme
            $port=$u.Port
            $AbsoluteUri=$u.AbsoluteUri
            $authority=$u.Authority
            $sHost=$u.Host
            $absoluteuri=$u.AbsoluteUri
            $absolutepath=$u.PathAndQuery
            
        }
        
    }catch {

        Show-ExceptionDetails $_
    }
}
