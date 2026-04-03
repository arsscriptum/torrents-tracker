#┌────────────────────────────────────────────────────────────────────────────────┐
#│                                                                                │
#│   Get-PBayCategories.ps1                                                       │
#│   Get Pirate Bay Categories                                                    │
#│                                                                                │
#┼────────────────────────────────────────────────────────────────────────────────┼
#│   Guillaumep  <guillaumeplante.qc@gmail.com                                    │
#└────────────────────────────────────────────────────────────────────────────────┘

# Function to get the main category from the first digit
function Get-MainCategory {
    param (
        [string]$id
    )

    # Extract the first digit to determine the main category
    $mainCategoryId = $id.Substring(0, 1)

    switch ($mainCategoryId) {
        0 { return 'undefined' }
        1 { return 'Audio' }
        2 { return 'Video' }
        3 { return 'Applications' }
        4 { return 'Games' }
        5 { return 'Porn' }
        6 { return 'Other' }
        default { return 'Invalid Main Category' }
    }
}

# Function to get the subcategory from the full 3 digit id
function Get-SubCategory {
    param (
        [string]$id
    )

    # Extract the full 3 digit id to determine the subcategory
    switch ($id) {
        101 { return 'Music' }
        102 { return 'Audio Books' }
        103 { return 'Sound clips' }
        104 { return 'FLAC' }
        199 { return 'Other (Audio)' }
        201 { return 'Movies' }
        202 { return 'Movies DVDR' }
        203 { return 'Music videos' }
        204 { return 'Movie Clips' }
        205 { return 'TV-Shows' }
        206 { return 'Handheld' }
        207 { return 'HD Movies' }
        208 { return 'HD TV-Shows' }
        209 { return '3D' }
        210 { return 'CAM/TS' }
        211 { return 'UHD/4k Movies' }
        212 { return 'UHD/4k TV-Shows' }
        299 { return 'Other (Video)' }
        301 { return 'Windows' }
        302 { return 'Mac/Apple' }
        303 { return 'UNIX' }
        304 { return 'Handheld' }
        305 { return 'IOS (iPad/iPhone)' }
        306 { return 'Android' }
        399 { return 'Other OS' }
        401 { return 'PC' }
        402 { return 'Mac/Apple' }
        403 { return 'PSx' }
        404 { return 'XBOX360' }
        405 { return 'Wii' }
        406 { return 'Handheld' }
        407 { return 'IOS (iPad/iPhone)' }
        408 { return 'Android' }
        499 { return 'Other (Games)' }
        501 { return 'Movies' }
        502 { return 'Movies DVDR' }
        503 { return 'Pictures' }
        504 { return 'Games' }
        505 { return 'HD Movies' }
        506 { return 'Movie Clips' }
        507 { return 'UHD/4k Movies' }
        599 { return 'Other (Porn)' }
        601 { return 'E-books' }
        602 { return 'Comics' }
        603 { return 'Pictures' }
        604 { return 'Covers' }
        605 { return 'Physibles' }
        699 { return 'Other (Other)' }
        default { return 'Invalid Subcategory' }
    }
}


# Function to get all main categories
function Get-AllMainCategories {
    # Define an array with all main categories
    $mainCategories = @(
        'undefined',
        'Audio',
        'Video',
        'Applications',
        'Games',
        'Porn',
        'Other'
    )
    return $mainCategories
}

# Function to get all subcategories
function Get-AllSubCategories {
    # Define an array with all subcategories
    $subCategories = @(
        'Music',
        'Audio Books',
        'Sound clips',
        'FLAC',
        'Other (Audio)',
        'Movies',
        'Movies DVDR',
        'Music videos',
        'Movie Clips',
        'TV-Shows',
        'Handheld',
        'HD Movies',
        'HD TV-Shows',
        '3D',
        'CAM/TS',
        'UHD/4k Movies',
        'UHD/4k TV-Shows',
        'Other (Video)',
        'Windows',
        'Mac/Apple',
        'UNIX',
        'Handheld',
        'IOS (iPad/iPhone)',
        'Android',
        'Other OS',
        'PC',
        'PSx',
        'XBOX360',
        'Wii',
        'Other (Games)',
        'Movies',
        'Movies DVDR',
        'Pictures',
        'Games',
        'HD Movies',
        'Movie Clips',
        'UHD/4k Movies',
        'Other (Porn)',
        'E-books',
        'Comics',
        'Pictures',
        'Covers',
        'Physibles',
        'Other (Other)'
    )
    return $subCategories
}


# Get all main categories
$mainCategories = Get-AllMainCategories
$mainCategories  # Output: array of main categories

# Get all subcategories
$subCategories = Get-AllSubCategories
$subCategories  # Output: array of subcategories


# Get the main category
Get-MainCategory -id "201"   # Output: Video

# Get the subcategory
Get-SubCategory -id "201"    # Output: Movies
