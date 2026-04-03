



function Search-PBay { 
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True,Position=0)]
        [String]$Request,
        [Parameter(Mandatory=$False)] 
        [String]$Category=0
    )

    try{

      [string]$BaseUri = "https://apibay.org/q.php"
      $ReqHeaders = @{
        "authority"="apibay.org"
        "method"="GET"
        "scheme"="https"
        "accept"="*/*"
        "accept-encoding"="gzip, deflate, br, zstd"
        "accept-language"="fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7"
        "origin"="https://thepiratebay.org"
        "priority"="u=0, i"
        "referer"="https://thepiratebay.org/"
      }

      $encodedRequest = [System.Web.HttpUtility]::UrlEncode($Request)

      [string]$Query = "{0}?q={1}&cat={2}" -f $BaseUri, $encodedRequest, $Category
      
      Write-Verbose "Query $Query"
   
      $ReqUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
      $Res = Invoke-WebRequest -UseBasicParsing -Uri "$Query" -Headers $ReqHeaders -UserAgent $ReqUserAgent

      $Status = $Res.StatusCode
      if($Status -ne 200) { throw "Error: $_" }

      $JsonResults = $Res.Content

      $JsonResults | ConvertFrom-Json

    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 


Search-PBay "Papillon" -Verbose