"""
torrents-tracker
a django application to search multiple torrents indexers easily and securely

constants.py

"""

class IndexersURLs:
    PIRATE_BAY_PROXY_API_URL = "https://pirate-proxy.dad/newapi/q.php"
    X1337_BASE_URL = "https://1337x.unblockit.download"
    PIRATE_BAY_API_URL = "https://apibay.org/q.php"

class InternalURLs:
    IPINFO_API_URL = "https://api.ipify.org"
    IPINFO_URL = "https://ipinfo.io/"
    DB_VERSION_URL = "https://raw.githubusercontent.com/arsscriptum/torrents-tracker-data/refs/heads/master/db.nfo"
    TMDB_API_URL = "https://api.themoviedb.org/3"
    TMDB_IMAGES_W50_URL = "https://image.tmdb.org/t/p/w500"
    TMDB_IMAGES_ORG_URL = "https://image.tmdb.org/t/p/original"


