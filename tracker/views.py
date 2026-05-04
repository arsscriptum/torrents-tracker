import requests
import humanize
import os
import logging
import folium
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


def site_options(request):
    vpn_configs = []
    current_vpn = ''
    container_running = False
    try:
        import docker as docker_sdk
        client = docker_sdk.from_env()
        container = client.containers.get('transmissionvpn')
        env_vars = {
            e.split('=')[0]: e.split('=', 1)[1]
            for e in container.attrs['Config']['Env'] if '=' in e
        }
        current_vpn = env_vars.get('OPENVPN_CONFIG', '')
        provider = env_vars.get('OPENVPN_PROVIDER', 'PROTONVPN').lower()
        container_running = container.status == 'running'
        if container_running:
            exit_code, output = container.exec_run(f'ls /etc/openvpn/{provider}/')
            if exit_code == 0:
                files = output.decode().strip().split('\n')
                vpn_configs = sorted(f.replace('.ovpn', '') for f in files if f.endswith('.ovpn'))
    except Exception:
        pass
    return render(request, "tracker/site_options.html", {
        'vpn_configs': vpn_configs,
        'current_vpn': current_vpn,
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

def _transmission_request(method, arguments):
    session_resp = requests.get(TRANSMISSION_URL)
    session_id = session_resp.headers.get('X-Transmission-Session-Id', '')
    headers = {'X-Transmission-Session-Id': session_id, 'Content-Type': 'application/json'}
    response = requests.post(TRANSMISSION_URL, json={'method': method, 'arguments': arguments}, headers=headers)
    return response.json()


def transfers(request):
    context = {'torrents': [], 'error': None, 'no_footer': True}
    try:
        result = _transmission_request('torrent-get', {
            'fields': [
                'id', 'name', 'status', 'percentDone', 'rateDownload',
                'rateUpload', 'peersConnected', 'sizeWhenDone', 'eta',
                'errorString', 'downloadDir'
            ]
        })
        if result.get('result') == 'success':
            torrents = []
            for t in result['arguments']['torrents']:
                done = t['percentDone'] == 1.0
                torrents.append({
                    'id':       t['id'],
                    'name':     t['name'],
                    'status':   TRANSMISSION_STATUS_MAP.get(t['status'], 'Unknown'),
                    'progress': round(t['percentDone'] * 100, 1),
                    'done':     done,
                    'down':     humanize.naturalsize(t['rateDownload']) + '/s',
                    'up':       humanize.naturalsize(t['rateUpload']) + '/s',
                    'size':     humanize.naturalsize(t['sizeWhenDone']),
                    'peers':    t['peersConnected'],
                    'eta':      humanize.naturaldelta(t['eta']) if t['eta'] > 0 else ('Done' if done else '∞'),
                    'error':    t.get('errorString', ''),
                })
            context['torrents'] = torrents
        else:
            context['error'] = result.get('result', 'Unknown error from Transmission')
    except Exception as e:
        context['error'] = str(e)
    return render(request, 'tracker/transfers.html', context)


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
    try:
        import shutil
        ids = json.loads(request.body).get('ids', [])
        if not ids:
            return JsonResponse({'success': False, 'message': 'No torrents selected.'})

        result = _transmission_request('torrent-get', {
            'ids': ids,
            'fields': ['id', 'name', 'percentDone', 'downloadDir']
        })
        if result.get('result') != 'success':
            return JsonResponse({'success': False, 'message': result.get('result')})

        export_dir = '/mnt/datassd/Nouveautes'
        exported, skipped, errors = [], [], []

        for t in result['arguments']['torrents']:
            if t['percentDone'] != 1.0:
                skipped.append(t['name'])
                continue
            src = os.path.join('/Completed', t['name'])
            dst = os.path.join(export_dir, t['name'])
            try:
                shutil.move(src, dst)
                _transmission_request('torrent-remove', {'ids': [t['id']], 'delete-local-data': False})
                exported.append(t['name'])
            except Exception as e:
                errors.append(f"{t['name']}: {e}")

        msg_parts = []
        if exported:
            msg_parts.append(f"Exported {len(exported)}: {', '.join(exported)}")
        if skipped:
            msg_parts.append(f"Skipped {len(skipped)} not yet complete: {', '.join(skipped)}")
        if errors:
            msg_parts.append(f"Errors: {'; '.join(errors)}")

        return JsonResponse({'success': not errors, 'message': ' | '.join(msg_parts) or 'Nothing to export.'})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)})


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


def manage_vpn(request):
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Invalid request method.'})

    try:
        data = json.loads(request.body)
        vpn_id = data.get('vpn_id', '').strip()

        if not vpn_id:
            return JsonResponse({'success': False, 'message': 'VPN ID not provided.'})

        import docker as docker_sdk
        client = docker_sdk.from_env()
        container = client.containers.get('transmissionvpn')

        # Determine provider and current active config from container env
        env_vars = {
            e.split('=')[0]: e.split('=', 1)[1]
            for e in container.attrs['Config']['Env'] if '=' in e
        }
        provider = env_vars.get('OPENVPN_PROVIDER', 'PROTONVPN').lower()
        current_config = env_vars.get('OPENVPN_CONFIG', '')

        config_dir = f'/etc/openvpn/{provider}'
        new_ovpn = f'{config_dir}/{vpn_id}.ovpn'
        active_ovpn = f'{config_dir}/{current_config}.ovpn'

        # Copy new config over the active one (skip if same file), then SIGHUP openvpn.
        # pkill -HUP openvpn returns 1 when no process matched — use || true so the
        # overall exit code reflects only whether the cp succeeded.
        if new_ovpn != active_ovpn:
            shell_cmd = f'cp {new_ovpn} {active_ovpn} && (pkill -HUP -x openvpn || true)'
        else:
            shell_cmd = 'pkill -HUP -x openvpn || true'
        exit_code, output = container.exec_run(['bash', '-c', shell_cmd])

        if exit_code == 0:
            return JsonResponse({'success': True, 'message': f'Switching VPN to {vpn_id}. Reconnecting...'})
        else:
            return JsonResponse({'success': False, 'message': output.decode(errors='replace')})

    except Exception as e:
        return JsonResponse({'success': False, 'message': 'Server error.', 'details': str(e)})
