function Generate-LoadCss {
    param (
        [string]$FontsDirectory = "G:\torrents-tracker\www\static\fonts",
        [string]$OutputFile = "G:\torrents-tracker\www\static\load.css"
    )

    # Check if the fonts directory exists
    if (-not (Test-Path -Path $FontsDirectory)) {
        Write-Error "The fonts directory '$FontsDirectory' does not exist."
        return
    }

    # Get all .ttf files in the fonts directory
    $ttfFiles = Get-ChildItem -Path $FontsDirectory -Filter "*.ttf"

    # Initialize an array to hold CSS lines
    $cssLines = @()

    # Iterate through each font file to generate @font-face CSS rule
    foreach ($ttfFile in $ttfFiles) {
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($ttfFile.Name) -replace "[-_]", " "
        $fontUrl = "/static/fonts/$($ttfFile.Name)"

        $cssLines += "@font-face {"
        $cssLines += "  font-family: '$fontName';"
        $cssLines += "  font-style: normal;"
        $cssLines += "  font-weight: 200;"
        $cssLines += "  font-display: swap;"
        $cssLines += "  src: url('$fontUrl') format('truetype');"
        $cssLines += "}"
        $cssLines += ""
    }

    # Write the CSS lines to the output file
    Set-Content -Path $OutputFile -Value $cssLines

    Write-Host "The load.css file has been generated at '$OutputFile'."
}

# Example usage:
Generate-LoadCss
