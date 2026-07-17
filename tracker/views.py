import requests
import humanize
import os
import shutil
import logging
import threading
import folium
from datetime import datetime
from .constants import InternalURLs,IndexersURLs
from django.http import JsonResponse
import json
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages, auth
from django.http import HttpResponse
from tracker.models import MagnetLink, Movies, Games, Contact, DatabaseVersion
from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
from .search_utils import movie_search
from django.utils.safestring import mark_safe
from django.conf import settings
from django.contrib import messages

# ---------------------------------------------------------------------------
# Async export state
# ---------------------------------------------------------------------------
EXPORT_STATE_FILE = '/logs/export_state.json'
COMPLETED_DIR = '/Completed'
EXPORT_DIR = '/mnt/datassd/Nouveautes'

_export_thread: threading.Thread = None
_export_lock = threading.Lock()


def _read_export_state():
    """Return the export state dict if a transfer is running, else None."""
    with _export_lock:
        thread_alive = _export_thread is not None and _export_thread.is_alive()
    if not thread_alive:
        try:
            os.remove(EXPORT_STATE_FILE)
        except OSError:
            pass
        return None
    try:
        with open(EXPORT_STATE_FILE) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _write_export_state(state):
    try:
        with open(EXPORT_STATE_FILE, 'w') as f:
            json.dump(state, f)
    except OSError:
        pass


def _do_export(state):
    """Background thread: move files one by one, remove from Transmission, clean up."""
    try:
        for file_info in state['files']:
            file_info['status'] = 'moving'
            _write_export_state(state)
            try:
                shutil.move(file_info['src'], file_info['dst'])
                file_info['status'] = 'done'
            except Exception as exc:
                file_info['status'] = f'error: {exc}'
            _write_export_state(state)

        done_ids = [f['id'] for f in state['files'] if f['status'] == 'done']
        if done_ids:
            try:
                _transmission_request('torrent-remove', {'ids': done_ids, 'delete-local-data': False})
            except Exception:
                pass
    finally:
        try:
            os.remove(EXPORT_STATE_FILE)
        except OSError:
            pass

def index(request):
    return render(request, "tracker/index.html")

# Helper Function for Validating Input Length
def validate_input_length(value, min_length, max_length):
    return min_length <= len(value) <= max_length

# Search Torrents View
def searchTorrents(request):
    context = {}
    keywords = request.GET["keywords"].lower()
    selected_sites = request.GET.getlist("sites")
    category = request.GET.get("category", "0")
    torrents_data = movie_search(keywords, selected_sites, category)
    context["torrents"] = torrents_data
    context["keywords"] = keywords
    context["no_footer"] = True
    return render(request, "tracker/searchResults.html", context)


VPN_NODES_JSON = '/vpnconfig/vpn-nodes.json'
# Host→container path mappings for volumes mounted in the transmissionvpn container
_VPN_MOUNT_MAPPINGS = [
    ('/home/services/vpn/config/', '/config/'),
    ('/home/services/vpn/etc-protonvpn/', '/etc/openvpn/protonvpn/'),
]


def _load_vpn_nodes():
    """Return sorted list of VPN node dicts from the JSON file, or [] on any error."""
    try:
        with open(VPN_NODES_JSON) as f:
            nodes = json.load(f)
        return sorted(nodes, key=lambda n: n.get('Index', 0))
    except Exception:
        return []


def site_options(request):
    container_running = False
    try:
        import docker as docker_sdk
        client = docker_sdk.from_env()
        container = client.containers.get('transmissionvpn')
        container_running = container.status == 'running'
    except Exception:
        pass

    vpn_nodes = _load_vpn_nodes()

    return render(request, "tracker/site_options.html", {
        'vpn_nodes': vpn_nodes,
        'container_running': container_running,
    })

def test_fonts(request):
    context = {}
    context["use_all_fonts"] = True
    context["no_footer"] = True
    return render(request, "tracker/test_fonts.html", context)



def about(request):
    context = {
        "external_ip": "",
        "site_version": '',
        "ip_info": {},
        "current_db_version": "Unknown",
        "latest_db_version": "Unknown",
        "new_version_available": False  # Flag for new version message
    }

    # Get the latest version number
    latest_version = (
        MagnetLink.objects.exclude(Version__isnull=True)
        .order_by('-Version')
        .values_list('Version', flat=True)
        .first()
    )

    # Retrieve all trackers for that version
    trackers = MagnetLink.objects.filter(Version=latest_version).values_list("AbsoluteUri", flat=True)


    # Fetch the current database version from the local database
    latest_local_version = DatabaseVersion.objects.order_by('-updated_on').first()
               
    if latest_local_version:
        context["current_db_version"] = latest_local_version.version_number

    # Fetch the latest database version from the URL
    db_version_url = InternalURLs.DB_VERSION_URL
    try:
        response = requests.get(db_version_url)
        response.raise_for_status()
        # Get the latest database version from the response
        context["latest_db_version"] = response.text.strip()
    except requests.RequestException as e:
        context["latest_db_version"] = f"Error fetching version: {e}"

    # Compare versions and set the flag if they differ
    if context["current_db_version"] != context["latest_db_version"]:
        context["new_version_available"] = True

    # Fetch the external IP and IP information
    ip_service_url = InternalURLs.IPINFO_API_URL + "?format=json"
    ip_info_service_url = InternalURLs.IPINFO_URL
   
    site_version = "1.0.1a"

    try:
        # Fetch the external IP
        response = requests.get(ip_service_url)
        response.raise_for_status()
        ip_address = response.json().get('ip', 'Unavailable')

        # Fetch IP address information from ipinfo.io
        ip_info_response = requests.get(f"{ip_info_service_url}{ip_address}/json")
        ip_info_response.raise_for_status()
        ip_info = ip_info_response.json()
        
        # Generate map using IP's latitude and longitude
        latitude, longitude = map(float, ip_info["loc"].split(","))
        folium_map = folium.Map(location=[latitude, longitude], zoom_start=4)
        folium.Marker([latitude, longitude], tooltip="Your IP Location").add_to(folium_map)
        
        # Render the map to HTML and pass it to the template
        map_html = folium_map._repr_html_()  # Generate map HTML
        context["map_html"] = mark_safe(map_html)  # Mark safe for HTML rendering

    except requests.RequestException:
        ip_address = "Unable to retrieve IP"
        ip_info = {"error": "Unable to retrieve IP info"}

    # Update the context with IP address and info
    context["trackers"] = trackers
    context["latest_version"] = latest_version
    context["external_ip"] = ip_address
    context["site_version"] = site_version
    context["ip_info"] = ip_info  # Pass all IP info to the context

    return render(request, 'tracker/about.html', context)




def footer_page(request):
    return render(request, "tracker/footer.html")


# Privacy Policy View
def privacy_policy(request):
    return render(request, "tracker/privacy.html", {'no_footer': False})

def contact_us(request):
    context = {"submission": False, "errors": []}
    return render(request, "tracker/contact.html", context)


def site_version(request):
    site_version = "1.0.1a"
    return render(request, 'tracker/version.html', {'external_ip': site_version})



# Movies View
def movies(request):
    context = {"search_flag": False}
    keywords = request.GET.get("keywords", "")

    if keywords:
        context["search_flag"] = True
        context["search_keywords"] = keywords
        movies_queryset = Movies.objects.filter(title__icontains=keywords)
        paginator = Paginator(movies_queryset, 15)
    else:
        movies_queryset = Movies.objects.all()
        paginator = Paginator(movies_queryset, 20)

    movies_count = movies_queryset.count()
    # Default to page 1 if not provided
    page_number = request.GET.get("page", 1)

    try:
        paged_movies = paginator.page(page_number)
    except PageNotAnInteger:
        paged_movies = paginator.page(1)
    except EmptyPage:
        paged_movies = paginator.page(paginator.num_pages)

    context["all_movies_length"] = movies_count
    context["all_movies"] = paged_movies
    context["no_footer"] = True
    return render(request, "tracker/category/movies.html", context)


# Single Movie View
def movies_local_db(request, movie_id):
    movie = get_object_or_404(Movies, pk=movie_id)
    context = {"movie": movie}
    context["no_footer"] = True
    return render(request, "tracker/category/movies_local_db.html", context)


# Games View
def games(request):
    context = {"search_flag": False}
    keywords = request.GET.get("keywords", "")

    if keywords:
        context["search_flag"] = True
        context["search_keywords"] = keywords
        games_queryset = Games.objects.filter(title__icontains=keywords)
    else:
        games_queryset = Games.objects.all()

    games_count = games_queryset.count()
    paginator = Paginator(games_queryset, 6)
    page_number = request.GET.get("page", 1)

    try:
        paged_games = paginator.page(page_number)
    except PageNotAnInteger:
        paged_games = paginator.page(1)
    except EmptyPage:
        paged_games = paginator.page(paginator.num_pages)

    context["all_games_length"] = games_count
    context["all_games"] = paged_games
    context["no_footer"] = True
    return render(request, "tracker/category/games.html", context)


# Single Game View
def games_single(request, game_id):
    game = get_object_or_404(Games, pk=game_id)
    context = {"game": game}
    context["no_footer"] = True
    return render(request, "tracker/category/games_single.html", context)






def get_tmdb_headers(request):
    """
    Generate the headers required for TMDb API requests.
    If the TMDB_API_READ_TOKEN is missing, show a warning message.
    """
    tmdb_read_token = settings.TMDB_READ_TOKEN

    if not tmdb_read_token:
        # Add a warning message to be displayed in the UI
        messages.warning(
            request,
            "TMDB API Read Token is not set. Please configure it in your environment variables."
        )
        return None  # Return None to indicate that headers cannot be created

    headers = {
        "accept": "application/json",
        "Authorization": f"Bearer {tmdb_read_token}"
    }

    return headers



def get_movie_images(request, movie_id):
    url = InternalURLs.TMDB_API_URL + f"/movie/{movie_id}/images"
    headers = get_tmdb_headers(request)
    if headers is None:
        return render(request, "tracker/error.html")  # Redirect to an error page

    context = {"no_footer": True}
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        images_data = response.json()
        return images_data;
    except requests.RequestException as e:
        logging.error(f"Failed to fetch movie details: {e}")
        context["error"] = "Could not fetch movie details at this time."

def movies_info(request, movie_id):
    logging.info("#")
    logging.info("")

    headers = get_tmdb_headers(request)
    if headers is None:
        return render(request, "tracker/error.html")  # Redirect to an error page

    # Base URL for movie details
    movie_url = InternalURLs.TMDB_API_URL + f"/movie/{movie_id}?language=en-US"
    # URL for fetching trailers (videos)
    videos_url = InternalURLs.TMDB_API_URL + f"/movie/{movie_id}/videos?language=en-US"

    context = {"no_footer": True}
   
    try:
        # Fetch movie details
        response = requests.get(movie_url, headers=headers)
        response.raise_for_status()
        movie_data = response.json()

        # Fetch videos (trailers)
        videos_response = requests.get(videos_url, headers=headers)
        videos_response.raise_for_status()
        videos_data = videos_response.json()

        # Get the first YouTube trailer video ID, if available
        trailer_id = None
        for video in videos_data.get("results", []):
            if video.get("site") == "YouTube" and video.get("type") == "Trailer":
                trailer_id = video.get("key")
                break

        logging.info(movie_data)
        
        # Prepare movie details for the template
        context["movie"] = {
            "title": movie_data.get("title", "Unknown"),
            "image_url": InternalURLs.TMDB_IMAGES_W50_URL + f"{movie_data.get('backdrop_path', '')}",
            "release_date": movie_data.get("release_date", "Unknown"),
            "synopsis": movie_data.get("overview", "No synopsis available."),
            "genre": ", ".join([genre.get("name", "") for genre in movie_data.get("genres", [])]),
            "origin_country": ", ".join(movie_data.get("production_countries", [{}])[0].get("iso_3166_1", "Unknown")),
            "origin_language": movie_data.get("original_language", "Unknown").upper(),
            "vote_average": movie_data.get("vote_average", "N/A"),
            "trailer_id": trailer_id,
        }
    except requests.RequestException as e:
        logging.error(f"Failed to fetch movie details: {e}")
        context["error"] = "Could not fetch movie details at this time."

    return render(request, "tracker/category/info/movies_info.html", context)



def discover(request):
    context = {"search_flag": False}
    logging.info("#")
    TMDB_READ_TOKEN = os.getenv('TMDB_API_READ_TOKEN', '')
    url = InternalURLs.TMDB_API_URL + "/trending/movie/week?language=en-US"
    headers = get_tmdb_headers(request)
    if headers is None:
        return render(request, "tracker/error.html")  # Redirect to an error page

    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        movies_data = response.json().get('results', [])
 
        # Prepare the movie list for the template
        movies = [
            {
                "title": movie.get("title", "Unknown"),
                "image_url": InternalURLs.TMDB_IMAGES_W50_URL + f"{movie.get('poster_path', '')}",
                "release_date": movie.get("release_date", "Unknown"),
                "id": movie.get("id")
            }
            for movie in movies_data if movie.get("poster_path")
        ]

        context["all_movies"] = movies
        context["search_flag"] = True
        context["no_footer"] = True
    except requests.RequestException as e:
        logging.error(f"Failed to fetch movies from TMDb: {e}")
        context["error"] = "Could not fetch movies at this time."

    return render(request, "tracker/discover.html", context)


def popular(request):
    # Get the current page number from the request query parameters
    page_id = request.GET.get('page', 1)
    try:
        page_id = int(page_id)  # Ensure page_id is an integer
    except ValueError:
        page_id = 1

    context = {"search_flag": False}

    logging.info(f"👽 REQUEST: MOST POPULAR - PAGE ID {page_id}")

    # Fetch data from the TMDb API for the specified page
    url = InternalURLs.TMDB_API_URL + f"/movie/popular?language=en-US&page={page_id}"
    
    headers = get_tmdb_headers(request)
    if headers is None:
        return render(request, "tracker/error.html")  # Redirect to an error page

    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        response_data = response.json()
        movies_data = response_data.get('results', [])

        # Prepare the movie list for the paginator
        movies = [
            {
                "title": movie.get("title", "Unknown"),
                "image_url": InternalURLs.TMDB_IMAGES_W50_URL + f"{movie.get('poster_path', '')}",
                "release_date": movie.get("release_date", "Unknown"),
                "id": movie.get("id")
            }
            for movie in movies_data if movie.get("poster_path")
        ]

        # Use Django's Paginator to handle pagination
        paginator = Paginator(movies, 12)  # Show 5 movies per page
        current_page = paginator.get_page(page_id)

        context["all_movies"] = current_page
        context["search_flag"] = True
        context["no_footer"] = True
        context["total_pages"] = paginator.num_pages
        context["current_page"] = current_page.number

    except requests.RequestException as e:
        logging.error(f"Failed to fetch movies from TMDb: {e}")
        context["error"] = "Could not fetch movies at this time."

    return render(request, "tracker/popular.html", context)



TRANSMISSION_URL = 'http://localhost:9091/transmission/rpc'
TRANSMISSION_STATUS_MAP = {
    0: 'Stopped', 1: 'Check queue', 2: 'Checking',
    3: 'Download queue', 4: 'Downloading', 5: 'Seed queue', 6: 'Seeding'
}

_transmission_session_id = ''

def _prime_transmission_session():
    """Fetch and cache the Transmission session ID in a background thread at startup."""
    global _transmission_session_id
    try:
        r = requests.post(TRANSMISSION_URL,
                          json={'method': 'session-get', 'arguments': {}},
                          headers={'Content-Type': 'application/json', 'Connection': 'close'},
                          timeout=30)
        if r.status_code == 409:
            _transmission_session_id = r.headers.get('X-Transmission-Session-Id', '')
    except Exception:
        pass  # best-effort; first real request will retry

threading.Thread(target=_prime_transmission_session, daemon=True).start()


def _transmission_request(method, arguments):
    """POST to Transmission RPC, refreshing the session ID on 409."""
    global _transmission_session_id
    payload = {'method': method, 'arguments': arguments}
    # 'Connection: close' forces a fresh TCP connection every call — prevents
    # urllib3's pool from reusing a connection that Transmission already closed.
    headers = {'X-Transmission-Session-Id': _transmission_session_id,
               'Content-Type': 'application/json',
               'Connection': 'close'}
    response = requests.post(TRANSMISSION_URL, json=payload, headers=headers, timeout=20)
    if response.status_code == 409:
        _transmission_session_id = response.headers.get('X-Transmission-Session-Id', '')
        headers['X-Transmission-Session-Id'] = _transmission_session_id
        response = requests.post(TRANSMISSION_URL, json=payload, headers=headers, timeout=20)
    return response.json()


def transfers(request):
    """Render the page immediately; torrent data loads via AJAX."""
    state = _read_export_state()
    return render(request, 'tracker/transfers.html', {
        'no_footer':     True,
        'export_active': bool(state),
        'export_state':  state,
    })


def torrent_list(request):
    """AJAX endpoint — returns torrent data from Transmission as JSON."""
    state = _read_export_state()
    transferring_names = {f['name'] for f in state.get('files', [])} if state else set()
    try:
        result = _transmission_request('torrent-get', {
            'fields': [
                'id', 'name', 'status', 'percentDone', 'rateDownload',
                'rateUpload', 'peersConnected', 'sizeWhenDone', 'eta',
                'errorString', 'downloadDir'
            ]
        })
        if result.get('result') != 'success':
            return JsonResponse({'success': False, 'error': result.get('result', 'Unknown error')})

        torrents = []
        for t in result['arguments']['torrents']:
            done = t['percentDone'] == 1.0
            torrents.append({
                'id':        t['id'],
                'name':      t['name'],
                'status':    TRANSMISSION_STATUS_MAP.get(t['status'], 'Unknown'),
                'progress':  round(t['percentDone'] * 100, 1),
                'done':      done,
                'exporting': t['name'] in transferring_names,
                'down':      humanize.naturalsize(t['rateDownload']) + '/s',
                'up':        humanize.naturalsize(t['rateUpload']) + '/s',
                'size':      humanize.naturalsize(t['sizeWhenDone']),
                'peers':     t['peersConnected'],
                'eta':       humanize.naturaldelta(t['eta']) if t['eta'] > 0 else ('Done' if done else '∞'),
                'error':     t.get('errorString', ''),
            })
        return JsonResponse({'success': True, 'torrents': torrents})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})


def cancel_torrents(request):
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Invalid request method.'})
    try:
        ids = json.loads(request.body).get('ids', [])
        if not ids:
            return JsonResponse({'success': False, 'message': 'No torrents selected.'})
        result = _transmission_request('torrent-remove', {'ids': ids, 'delete-local-data': False})
        if result.get('result') == 'success':
            return JsonResponse({'success': True, 'message': f'Cancelled {len(ids)} torrent(s).'})
        return JsonResponse({'success': False, 'message': result.get('result')})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)})


def export_torrents(request):
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Invalid request method.'})

    global _export_thread

    with _export_lock:
        if _export_thread is not None and _export_thread.is_alive():
            return JsonResponse({'success': False, 'message': 'A transfer is already in progress. Wait for it to complete.'})

    try:
        ids = json.loads(request.body).get('ids', [])
        if not ids:
            return JsonResponse({'success': False, 'message': 'No torrents selected.'})

        result = _transmission_request('torrent-get', {
            'ids': ids,
            'fields': ['id', 'name', 'percentDone', 'sizeWhenDone', 'downloadDir']
        })
        if result.get('result') != 'success':
            return JsonResponse({'success': False, 'message': result.get('result')})

        all_torrents = result['arguments']['torrents']
        ready   = [t for t in all_torrents if t['percentDone'] == 1.0]
        skipped = [t['name'] for t in all_torrents if t['percentDone'] != 1.0]

        if not ready:
            return JsonResponse({'success': False, 'message': 'None of the selected torrents are complete yet.'})

        state = {
            'started_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'pid': os.getpid(),
            'files': [
                {
                    'id':         t['id'],
                    'name':       t['name'],
                    'size_bytes': t.get('sizeWhenDone', 0),
                    'src':        os.path.join(COMPLETED_DIR, t['name']),
                    'dst':        os.path.join(EXPORT_DIR, t['name']),
                    'status':     'queued',
                }
                for t in ready
            ],
        }
        _write_export_state(state)

        with _export_lock:
            _export_thread = threading.Thread(target=_do_export, args=(state,), daemon=True)
            _export_thread.start()

        msg = f'Transfer started: {len(ready)} file(s).'
        if skipped:
            msg += f' Skipped {len(skipped)} not yet complete: {", ".join(skipped)}'
        return JsonResponse({'success': True, 'message': msg})

    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)})


def transfer_status(request):
    state = _read_export_state()
    if state is None:
        return JsonResponse({'active': False})
    return JsonResponse({
        'active': True,
        'started_at': state.get('started_at'),
        'files': state.get('files', []),
    })


def add_torrent(request):
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Invalid request method.'})

    try:
        data = json.loads(request.body)
        magnet = data.get('magnet', '').strip()
        if not magnet:
            return JsonResponse({'success': False, 'message': 'No magnet link provided.'})

        transmission_url = 'http://localhost:9091/transmission/rpc'

        # Step 1: get session ID (Transmission returns 409 with X-Transmission-Session-Id)
        session_response = requests.get(transmission_url)
        session_id = session_response.headers.get('X-Transmission-Session-Id', '')

        # Step 2: add the torrent
        payload = {
            'method': 'torrent-add',
            'arguments': {'filename': magnet}
        }
        headers = {
            'X-Transmission-Session-Id': session_id,
            'Content-Type': 'application/json',
        }
        response = requests.post(transmission_url, json=payload, headers=headers)
        result = response.json()

        if result.get('result') == 'success':
            added = result.get('arguments', {})
            torrent_info = added.get('torrent-added') or added.get('torrent-duplicate')
            name = torrent_info.get('name', 'Unknown') if torrent_info else 'Unknown'
            return JsonResponse({'success': True, 'message': f'Added: {name}'})
        else:
            return JsonResponse({'success': False, 'message': result.get('result', 'Unknown error')})

    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)})


def _resolve_vpn_file_path(host_path):
    """Translate a vpn-nodes.json host FilePath to where it's accessible in this process."""
    if os.path.exists(host_path):
        return host_path
    # In Docker the host path /home/services/vpn/config/ is mounted at /vpnconfig/
    if host_path.startswith('/home/services/vpn/config/'):
        return '/vpnconfig/' + host_path[len('/home/services/vpn/config/'):]
    return host_path


def vpn_config_load(request):
    """AJAX GET: return raw text of a VPN config file by node index."""
    try:
        index = int(request.GET.get('index', -1))
        nodes = _load_vpn_nodes()
        node = next((n for n in nodes if n.get('Index') == index), None)
        if not node:
            return JsonResponse({'success': False, 'message': f'No VPN node with index {index}.'})
        path = _resolve_vpn_file_path(node.get('FilePath', ''))
        with open(path) as f:
            content = f.read()
        return JsonResponse({'success': True, 'content': content})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)})


def vpn_config_save(request):
    """AJAX POST: overwrite a VPN config file with new content."""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'POST required.'})
    try:
        data = json.loads(request.body)
        index = int(data.get('index', -1))
        content = data.get('content', '')
        nodes = _load_vpn_nodes()
        node = next((n for n in nodes if n.get('Index') == index), None)
        if not node:
            return JsonResponse({'success': False, 'message': f'No VPN node with index {index}.'})
        path = _resolve_vpn_file_path(node.get('FilePath', ''))
        with open(path, 'w') as f:
            f.write(content)
        label = f'{node.get("City", "")}, {node.get("Country", "")}'.strip(', ')
        return JsonResponse({'success': True, 'message': f'Saved: {label}'})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)})


def manage_vpn(request):
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Invalid request method.'})

    try:
        data = json.loads(request.body)
        raw_index = data.get('vpn_index')
        if raw_index is None:
            return JsonResponse({'success': False, 'message': 'vpn_index not provided.'})

        vpn_index = int(raw_index)
        nodes = _load_vpn_nodes()
        node = next((n for n in nodes if n.get('Index') == vpn_index), None)
        if not node:
            return JsonResponse({'success': False, 'message': f'No VPN node with index {vpn_index}.'})

        host_path = node.get('FilePath', '')
        container_src = None
        for host_prefix, container_prefix in _VPN_MOUNT_MAPPINGS:
            if host_path.startswith(host_prefix):
                container_src = container_prefix + host_path[len(host_prefix):]
                break
        if container_src is None:
            allowed = ', '.join(p for p, _ in _VPN_MOUNT_MAPPINGS)
            return JsonResponse({'success': False, 'message': f'FilePath must be under one of: {allowed}'})

        import docker as docker_sdk
        client = docker_sdk.from_env()
        container = client.containers.get('transmissionvpn')

        env_vars = {
            e.split('=')[0]: e.split('=', 1)[1]
            for e in container.attrs['Config']['Env'] if '=' in e
        }
        provider = env_vars.get('OPENVPN_PROVIDER', 'PROTONVPN').lower()
        current_config = env_vars.get('OPENVPN_CONFIG', '')
        active_ovpn = f'/etc/openvpn/{provider}/{current_config}.ovpn'

        # Copy new config over the active one, then SIGHUP openvpn.
        # pkill -HUP returns 1 when no process matched — use || true so the
        # overall exit code reflects only whether the cp succeeded.
        shell_cmd = f'cp {container_src} {active_ovpn} && (pkill -HUP -x openvpn || true)'
        exit_code, output = container.exec_run(['bash', '-c', shell_cmd])

        if exit_code == 0:
            label = f'{node.get("City", "")}, {node.get("Country", "")}'.strip(', ')
            return JsonResponse({'success': True, 'message': f'Switching VPN to {label}. Reconnecting...'})
        else:
            return JsonResponse({'success': False, 'message': output.decode(errors='replace')})

    except Exception as e:
        return JsonResponse({'success': False, 'message': 'Server error.', 'details': str(e)})
