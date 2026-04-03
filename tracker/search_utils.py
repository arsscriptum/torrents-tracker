from bs4 import BeautifulSoup
import cloudscraper
from .constants import IndexersURLs, InternalURLs
from django.db.models import Max
from tracker.models import MagnetLink
import logging
from datetime import datetime
import time
import asyncio
import aiohttp
import humanize
import urllib.parse
import sys
from urllib.parse import urlparse, parse_qs


import logging
import os
from pathlib import Path

# Load environment variables
LOG_PATH = os.getenv('TORTKR_LOG_PATH', '/var/log/diskusage_webapp')
LOG_FILE = os.getenv('TORTKR_LOG_FILE', 'search.log')

# Ensure the log directory exists
Path(LOG_PATH).mkdir(parents=True, exist_ok=True)

# Full log file path
log_file_path = os.path.join(LOG_PATH, LOG_FILE)

# Formatter for the log messages
formatter = logging.Formatter(
    "%(asctime)s - %(levelname)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
)

# File handler for outputting log messages to the log file
file_handler = logging.FileHandler(log_file_path, encoding="utf-8")
file_handler.setFormatter(formatter)


# Create a logger object
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Formatter for the log messages
formatter = logging.Formatter(
    "%(asctime)s - %(levelname)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
)


# Stream handler for outputting log messages to the console
stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setFormatter(formatter)

# Adding handlers to the logger
logger.addHandler(file_handler)
logger.addHandler(stream_handler)

## global variables
scraper = cloudscraper.create_scraper(browser="chrome")


def movie_search(keywords, selected_sites, category="0"):
    site_scrapers = {
        "pirate_bay": searchData_PBay,
        "1337x": searchData_1337x,
    }
    combined_results = []

    overall_start_time = time.time()
    logging.info('┏━━━━━━━━━━━━━━━━━━━┓')
    logging.info('┃  Starting Search  ┃')
    logging.info('┗━━━━━━━━━━━━━━━━━━━┛')



    # If no sites are selected, scrape from all sites
    if not selected_sites:
        selected_sites = site_scrapers.keys()

    for index, site_key in enumerate(selected_sites, start=1):
        if site_key in site_scrapers:
            scraper_function = site_scrapers[site_key]
            start_time = time.time()
        logging.info(f"[{index}] ➤ starting search using {site_key} ... ⌛ please wait ⌛")

        # Append results from each site to the combined_results list
        if site_key == "pirate_bay":
            combined_results.extend(scraper_function(keywords, index, category))
        else:
            combined_results.extend(scraper_function(keywords, index))

        end_time = time.time()
        time_taken = end_time - start_time
        logging.info(
            f"[{index}] ➤ search completed ✔ after ⋙ {time_taken:.2f} seconds 👍"
        )
        logging.info(f"Site #{index} - --------------------------------")

    overall_end_time = time.time()
    overall_time_taken = overall_end_time - overall_start_time
    logging.info(f" ✅ search session ended after {overall_time_taken:.2f} seconds")
    logging.info(f"Overall collected {len(combined_results)} torrents")
    logging.info('┏━━━━━━━━━━━━━━━━━━━┓')
    logging.info('┃   Ending Search   ┃')
    logging.info('┗━━━━━━━━━━━━━━━━━━━┛')


    return torrentSort(combined_results)


def torrentSort(torrents):
    return sorted(torrents, key=lambda x: int(x["seeds"]), reverse=True)


async def fetchMagnet(session, magnet_url, torrent):
    async with session.get(magnet_url) as response:
        if response.status == 200:
            magnet_content = await response.read()
            magnet_soup = BeautifulSoup(magnet_content, "html.parser")
            magnet_link = magnet_soup.find(
                "a", href=lambda href: href and "magnet:?" in href
            )
            if magnet_link:
                torrent["magnet"] = magnet_link.get("href")
            else:
                torrent["magnet"] = ""
        else:
            print(f"Error fetching magnet link for {torrent['title']}")


async def searchDataAsync_1337x(keywords, torrents):
    async with aiohttp.ClientSession() as session:
        tasks = []
        for torrent in torrents:
            magnet_url = torrent["magnet"]
            if magnet_url:
                task = asyncio.create_task(fetchMagnet(session, magnet_url, torrent))
                tasks.append(task)

        # Limiting the number of parallel requests to 5 for now
        chunk_size = 5
        for i in range(0, len(tasks), chunk_size):
            await asyncio.gather(*tasks[i : i + chunk_size])


def searchData_1337x(keywords, index):
    torrents = []
    search_url = IndexersURLs.X1337_BASE_URL + "/search/" + keywords + "/1/"
    try:
        # Add timeout of 10 seconds
        response = scraper.get(search_url, timeout=10)
        parsed_url = urlparse(response.url)
        query_params = parse_qs(parsed_url.query)
        # {'status': ['200']}
        url_status_code = int(query_params.get("status", [401])[0])
        if url_status_code:
            url_status_code = int(url_status_code)
        if (
            response.status_code == 200
            and url_status_code is not None
            and url_status_code != 403
        ):
            logging.info(
                f"[{index}] ➤ Initial request to site {search_url} was successful"
            )
            soup = BeautifulSoup(response.content, "html.parser")
            rows = soup.find_all("tr")
            for row in rows:
                cols = row.find_all("td")
                if cols:
                    name_col = cols[0].find_all("a", href=True)
                    if len(name_col) >= 2 and name_col[1]["href"].startswith(
                        "/torrent/"
                    ):
                        name = name_col[1].text.strip()
                        href = IndexersURLs.X1337_BASE_URL + name_col[1]["href"]
                        seeds = cols[1].text
                        leeches = cols[2].text
                        size_element = cols[4].find(text=True, recursive=False).strip()
                        size = size_element if size_element else None
                        torrent = {
                            "title": name,
                            "magnet": href,
                            "seeds": seeds,
                            "peers": leeches,
                            "size": size,
                        }
                        torrents.append(torrent)

            # Call the asynchronous function
            asyncio.run(searchDataAsync_1337x(keywords, torrents))
            logging.info(f"[{index}] ➤ Collected {len(torrents)} torrents")
            return torrents
        else:
            if url_status_code:
                logging.error(f"Failed to search 1337x. Status code: {url_status_code}")
            else:
                logging.error(
                    f"Failed to search 1337x. Status code: {response.status_code}"
                )
            return []
    except cloudscraper.requests.exceptions.ConnectionError as e:
        logging.error(f"Connection error occurred: {str(e)}")
        return []



def get_active_trackers():
    """
    Retrieves the latest version of trackers using only AbsoluteUri.
    """
    latest_version = (
        MagnetLink.objects.exclude(Version__isnull=True)
        .order_by('-Version')
        .values_list('Version', flat=True)
        .first()
    )

    if not latest_version:
        logger.warning("No trackers found in the database.")
        return []  # Return empty list if no versions found

    # Retrieve only AbsoluteUri for the latest version
    trackers = MagnetLink.objects.filter(Version=latest_version).values_list('AbsoluteUri', flat=True)

    # Convert to a list of strings (if needed)
    trackers = [str(uri) for uri in trackers if uri]

    logger.info(f"Fetched {len(trackers)} trackers from the database (Version: {latest_version})")
    return trackers


def create_magnet_pirate_bay(info_hash, name):
    """
    Generates a magnet link for a torrent from The Pirate Bay.

    Pirate Bay uses custom JavaScript to generate magnet links for its torrents.
    This function replicates that functionality in Python, creating a magnet link
    that includes the necessary trackers.

    I get the trackers with the powershell script \scripts\ps/Get-PBayTrackers.ps1
    
    Parameters:
    info_hash (str): The information hash of the torrent.
    name (str): The name of the torrent.

    Returns:
    str: A magnet link for the given torrent.
    """

    #logging.info(' ⛔ create_magnet')
    """
    trackers_v1 = [
        "udp://tracker.tiny-vps.com:6969/announce",
        "udp://open.stealth.si:80/announce",
        "udp://tracker.bittor.pw:1337/announce",
        "udp://public.popcorn-tracker.org:6969/announce",
        "udp://tracker.dler.org:6969/announce",
        "udp://exodus.desync.com:6969",
        "udp://open.demonii.com:1337/announce",          
        "udp://tracker.coppersurfer.tk:6969/announce",
        "udp://tracker.openbittorrent.com:6969/announce",
        "udp://9.rarbg.to:2710/announce",
        "udp://9.rarbg.me:2780/announce",
        "udp://9.rarbg.to:2730/announce",
        "udp://tracker.opentrackr.org:1337",
        "http://p4p.arenabg.com:1337/announce",
        "udp://tracker.torrent.eu.org:451/announce",
    ]

    trackers_v2 = [
        "udp://tracker.opentrackr.org:1337",
        "udp://open.stealth.si:80/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://tracker.bittor.pw:1337/announce",
        "udp://public.popcorn-tracker.org:6969/announce",
        "udp://tracker.dler.org:6969/announce",
        "udp://exodus.desync.com:6969",
        "udp://open.demonii.com:1337/announce",
    ]
 
    # V3 
    trackers = [
        "http://34.94.76.146:80/announce",
        "http://34.94.76.146:2710/announce",
        "http://34.94.76.146:80/announce",
        "http://34.89.91.10:2710/announce",
        "http://34.94.76.146:80/announce",
        "http://34.94.76.146:2710/announce",
        "http://35.227.59.57:443/announce",
        "http://34.94.76.146:6969/announce",
        "http://34.89.91.10:2710/announce",
        "http://34.94.76.146:2710/announce",
        "http://35.227.59.57:80/announce.php",
        "http://34.94.76.146:6969/announce",
        "http://35.227.59.57:6960/announce",
        "http://35.227.59.57:80/announce",
        "http://35.227.59.57:6969/announce",
        "http://34.94.76.146:11450/announce",
        "http://34.94.76.146:2710/announce",
        "http://34.89.91.10:80/announce",
        "http://34.94.76.146:80/announce",
        "http://35.227.59.57:6969/announce",
        "http://34.89.91.10:6969/announce",
        "http://35.227.59.57:80/announce",
        "http://34.94.76.146:80/announce",
        "http://34.94.76.146:2710/announce",
        "http://34.94.76.146:80/announce",
        "http://34.94.76.146:2710/announce",
        "http://35.227.59.57:443/announce",
        "http://34.94.76.146:6969/announce",
        "http://34.89.91.10:2710/announce",
        "http://34.94.76.146:2710/announce",
        "http://35.227.59.57:80/announce.php",
        "http://34.94.76.146:6969/announce",
        "http://35.227.59.57:6969/announce",
        "http://34.94.76.146:11450/announce",
        "http://34.94.76.146:2710/announce"
    ]

    # V4
    trackers = [
       "udp://tracker.opentrackr.org:1337/announce",
        "udp://open.demonii.com:1337/announce",
        "udp://open.stealth.si:80/announce",
        "udp://exodus.desync.com:6969/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://tracker.dump.cl:6969/announce",
        "udp://tracker-udp.gbitt.info:80/announce",
        "udp://open.free-tracker.ga:6969/announce",
        "udp://ns-1.x-fins.com:6969/announce",
        "udp://explodie.org:6969/announce",
        "udp://tracker.qu.ax:6969/announce",
        "udp://tracker.ololosh.space:6969/announce",
        "udp://tracker.bittor.pw:1337/announce",
        "udp://opentracker.io:6969/announce",
        "udp://leet-tracker.moe:1337/announce",
        "udp://isk.richardsw.club:6969/announce",
        "udp://discord.heihachi.pw:6969/announce",
        "udp://bt.ktrackers.com:6666/announce",
        "udp://wepzone.net:6969/announce",
        "udp://ttk2.nbaonlineservice.com:6969/announce",
        "udp://tracker2.dler.org:80/announce",
        "udp://tracker1.myporn.club:9337/announce",
        "udp://tracker.tryhackx.org:6969/announce",
        "udp://tracker.torrust-demo.com:6969/announce",
        "udp://tracker.tiny-vps.com:6969/announce",
        "udp://tracker.skyts.net:6969/announce",
        "udp://tracker.gmi.gd:6969/announce",
        "udp://tracker.gigantino.net:6969/announce",
        "udp://tracker.filemail.com:6969/announce",
        "udp://tracker.dler.org:6969/announce",
        "udp://tracker.darkness.services:6969/announce",
        "udp://tracker.0x7c0.com:6969/announce",
        "udp://tr4ck3r.duckdns.org:6969/announce",
        "udp://t.overflow.biz:6969/announce",
        "udp://retracker.lanta.me:2710/announce",
        "udp://p4p.arenabg.com:1337/announce",
        "udp://p2p.publictracker.xyz:6969/announce",
        "udp://open.dstud.io:6969/announce",
        "udp://new-line.net:6969/announce",
        "udp://ismaarino.com:1234/announce",
        "udp://ipv4announce.sktorrent.eu:6969/announce",
        "udp://ipv4.rer.lol:2710/announce",
        "udp://evan.im:6969/announce",
        "udp://d40969.acod.regrucolo.ru:6969/announce",
        "udp://bittorrent-tracker.e-n-c-r-y-p-t.net:1337/announce",
        "udp://bandito.byterunner.io:6969/announce",
        "udp://6ahddutb1ucc3cp.ru:6969/announce",
        "udp://tracker.srv00.com:6969/announce",
        "udp://tracker.fnix.net:6969/announce",
        "udp://tracker.ddunlimited.net:6969/announce",
        "udp://concen.org:6969/announce"
    ]
   """
    
    trackers = get_active_trackers()

    tracker_str = "".join(
        ["&tr=" + urllib.parse.quote(str(tracker)) for tracker in trackers]
    )
    magnet_link = (
        f"magnet:?xt=urn:btih:{info_hash}&dn={urllib.parse.quote(name)}{tracker_str}"
    )
    logging.info(f"⛔ magnet_link: {magnet_link}")
    return magnet_link






def searchData_PBay(keywords, index, category="0"):
    torrents = []
    search_url = IndexersURLs.PIRATE_BAY_API_URL + "?q=" + keywords
    if category and category != "0":
        search_url += "&cat=" + str(category)
    logging.info(f"PIRATE_BAY: Request: {search_url}")
    response = scraper.get(search_url)
    logging.info(f"PIRATE_BAY: response: {response}")

    

    if response.status_code == 200:
        logging.info(
            f"Site #{index} - Initial request to site {search_url} was successful"
        )
        json_data = response.json()
        for item in json_data:
            name = item.get("name")
            info_hash = item.get("info_hash")
            seeders = item.get("seeders")
            leechers = item.get("leechers")
            # Converts bytes to human-readable format
            size = humanize.naturalsize(int(item.get("size")), binary=True)
            torrent = {
                "title": name,
                "seeds": seeders,
                "peers": leechers,
                "magnet": create_magnet_pirate_bay(info_hash, name),
                "size": size,
            }
            torrents.append(torrent)
        logging.info(f"Site #{index} - Collected {len(torrents)} torrents")
    else:
        logging.error(
            f"Site #{index} - Failed to scrape Pirate Bay. Status code: {response.status_code}"
        )

    return torrents
