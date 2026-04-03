# tracker/context_processors.py

def site_info(request):
    # Read the site version from version.nfo
    with open('version.nfo', 'r') as version_file:
        site_version = version_file.read().strip()

    # Read the revision and branch from build.nfo
    with open('build.nfo', 'r') as build_file:
        lines = build_file.readlines()
        branch = lines[0].strip()  
        revision = lines[1].strip()

    # Return the data in a context dictionary
    return {
        'site_version': site_version,
        'site_revision': revision,
        'site_branch': branch
    }
