function Generate-TestFontsHtml {
    param (
        [string]$FontsDirectory = "G:\torrents-tracker\www\static\fonts",
        [string]$OutputFile = "G:\torrents-tracker\www\templates\tracker\test_fonts.html"
    )

    # Check if the fonts directory exists
    if (-not (Test-Path -Path $FontsDirectory)) {
        Write-Error "The fonts directory '$FontsDirectory' does not exist."
        return
    }

    # Get all .ttf files in the fonts directory
    $ttfFiles = Get-ChildItem -Path $FontsDirectory -Filter "*.ttf"

    # Initialize an array to hold HTML lines
    $htmlLines = @()




    # Add the HTML template structure
    $htmlLines += "{% extends 'base.html' %}"
    $htmlLines += "{% block test_fonts %}"
    $htmlLines += '    <div class="container-fluid container__wrapper">'
    $htmlLines += '        <div class="container">'
    $htmlLines += '            <div class="site__wrapper">'
    $htmlLines += '                <div class="w-100 mt-3">'

    # Iterate through each font file to generate font testing divs
    foreach ($ttfFile in $ttfFiles) {
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($ttfFile.Name) -replace "[-_]", " "
        $htmlLines += "                    <div class='$fontName' style='font-family: `"$fontName`";'>"
        $htmlLines += "                        This text is using the font: $fontName. Most modern browsers, such as Chrome, Firefox, and Edge, have built-in developer tools that allow you to inspect and debug fonts."
        $htmlLines += "                    </div>"
    }

    # Close the HTML tags
    $htmlLines += '                </div>'
    $htmlLines += '            </div>'
    $htmlLines += '        </div>'
    $htmlLines += '    </div>'
    $htmlLines += '{% endblock %}'

    # Write the HTML lines to the output file
    Set-Content -Path $OutputFile -Value $htmlLines

    Write-Host "The test_fonts.html file has been generated at '$OutputFile'."
}

# Example usage:
Generate-TestFontsHtml
