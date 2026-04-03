#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Write-EnvFile.ps1                                                            ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)  


try{
    $RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    $EnvPath = Join-Path $RootPath '.env'
    $Overwriting = $False
    if ((Test-Path -Path $EnvPath)) {
        if($Force){
            Write-Warning "The file .env already exists, we overwrite (-Force)"
            $Overwriting = $True
        }else{
            Write-Error "The file .env already exists. Overwiter? use the -Force cmd line option"
            return
        }
    }

    $Mod = Import-Module "PowerShell.Module.Core" -Force -PassThru -DisableNameChecking -ErrorAction Ignore
    $Cmd = get-command 'Decrypt-String' -ErrorAction Ignore
    if(($Cmd -eq $Null) -and ($Mod -eq $Null)){
        throw "missing depoendencies"
    }

    $CodedData = "twvFkmy4rCq58yvs9DBzNubX2455MoSxGBoHdUAtU46Fk+qELDFf/btNsqh1RfHp/QY3Aw6RH82t/3oXsbczWWb1tzGsRcHb6a88SYZsd9Zq3mU1lBrAm0xmuMgOCXhXKVZFskTXrOxE0Gx81jBbZjYqK3T9KmHKDe1o0CfUni827lsnO2jbgaHjzykiQX2rwDA3paa3K6kysGVr+sWYuOfoER8ALYMbcTArEy7/IqTwFxaWbZSkIx0GWweMKJ3+2W3KEZrgpdAE7JLom8eGG/IvybfvsJCYCtxmtLRfLioLP5NeNaYbdlSNSlYpTW6TqRW4ul3yUVQLmOs4wb/4OJqJH3TWeNEmvlfTR5bz3soOlGbLXMJH1VocwNvpPhRI7a+QjT485ylxlnzsYwkBLHlHXhG6rXX7uMJCsk14WUI0EvIej/seClCQ5VlWrEF44PV5wCzCGcxJCiekHVlqGlpWcqhMVk8WYsxfmssYMrw4H+HpQMBiD4JeD/9+67siNq1RzWEuyPEUL1SAHCKjYT1PczQos6kn5Ow706TaDXxWLJlySpo3KvjgsbHAAn8guSzMQA4OBguJ0ibfnrZ60VyW1UQt0Uvy0Re33QX05tPhrM6j9CmMMaIO0YMxM+kzBkygpVDGXXTwTUqgasKEgQ2FT4srNjElMxqATFtdNQejl6lGafumtEIrEnUe/U/H4lskP9MKcaIWIHFvnL3n2dNgs7BOluDufP1gYP2xpFTDmgZgcxOl27aUkqVV4V5eKTjWXJTiLj6HPnZUmT4ywrGIQrtoMk7lDTgtt/kTin3a650L8rgEZEYRP/4fvb6FlZEvWsUceBJMxnY9n4zajkTqT7a7A6hgCMMfMe8WBf/6pozUvHL7h/SX5ti937moCIHRij024o23guolWmYuQDx2vi7bug7q615iVuYOCeqVon9c+/YDWY0QR2GL5BnPMJ6rnxYLsh1TYjMq7JdxNrWC6Uk3KIXwsgEYsmHfXhkSRQevns0B6fiCNsoSM+/OSfA20TOum8Gnt9poLMCJNp9m60W2kqIX7e1T2YjC4W8EbGZiA3uhCeJ3bG/oO3O+sIFdtqbLmeiF6yz3gWbQzLf2eYWWsghWn4XzYLQTV2QwkTWlJn955CnubzoNk3ZJR8ysXY8xWsr0L/JECFGg1v36QiiEFSNqy74snzJ66iDfeIRnPKzH6zdCd0+8zBYk0gSl9M8PGLD+VwQkXRKeN0zfcNlNXcSvdVI1qjnFtkoJHcMjIRK2m6jfTUvoRe7pstPZ1nnnGwLJ+saxZoFRxBEBqIuLs+rG8e/l56X/mc7VRCpcdfTjl/94X780NO0JLy/LmY8ju0VknyF8THwPq1gzzgiTDSjIoH/WIw3K6sHsbxk83pvWu4blRbK8t87IfWx2HwEvC+nWmNcSI8BnV82cqJ4YwFNCtgM+Z0QSM3jmhP9uwSYDgqq1NqOCWIVBATSpfONkQSdnMVyccj3UbuKBMcph/pXtuOW6+H3sFtHtPpqOiJ3eEHW49mrKyP/KYRJHJocwqaOJe8QgK6pE7bjen88dAu0uaXKey6o1uKK+UizW7wqdL5KRMq363FaLuiOGi3WgaszNjoNJ8mZH+lUgb6iVoR01DlYZ8vJ4k5IBCd3Ij9tyVxgTno9jTdrBErkSvcbG8zaZ2BSkVg+w8DxrD+m7UDX29GC5hUo2sVE="
    Write-Host "[File Decryption] " -f DarkRed -NoNewLine 
    Write-Host "Please Enter Password: " -f DarkYellow -NoNewLine 
    $Pass = Read-Host -Prompt "?" -MaskInput
    $Base64Decoded = Decrypt-String -EncryptedString $CodedData -Passphrase $Pass
    $EnvFileData = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Base64Decoded));
    if($Overwriting){
        
        Write-Host "[Write-EnvFile] " -f DarkRed -NoNewLine 
        Write-Host "Would Create `"$EnvPath`" with this data: `n" -f DarkYellow -NoNewLine 
        Write-Host "$EnvFileData`n" -f DarkCyan
        Write-Host "[Write-EnvFile] " -f DarkRed -NoNewLine 
        Write-Host "Confirm (y/N)" -f DarkYellow -NoNewLine 
        $confirm = Read-Host "?"
        if($($confirm.ToLower()) -ne 'y'){
            throw "failed to confirm."
        }
    }
    New-Item -Path $EnvPath -ItemType File -Force -Value $EnvFileData
}catch{
    Write-Error "$_"
}
    

