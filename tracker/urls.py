from django.urls import path, include
from . import views

urlpatterns = [
    path("", views.index, name="index"),
    path("searchTorrents", views.searchTorrents, name="searchTorrents"),
    path("about", views.about, name="about"),
    path("site_options", views.site_options, name="site_options"),
    path("privacy_policy", views.privacy_policy, name="privacy_policy"),
    path("contact_us", views.contact_us, name="contact_us"),
    path("test_fonts", views.test_fonts, name="test_fonts"),
    path("discover", views.discover, name="discover"),
    path("popular", views.popular, name="popular"),
    path("categories/movies", views.movies, name="movies"),
    path("categories/movies/<int:movie_id>", views.movies_local_db, name="movies_local_db"),
    path("categories/info/<int:movie_id>", views.movies_info, name="movies_info"),
    path("categories/games", views.games, name="games"),
    path("categories/games/<int:game_id>", views.games_single, name="games_single"),
    path("transfers", views.transfers, name="transfers"),
    path("torrent_list", views.torrent_list, name="torrent_list"),
    path("cancel_torrents", views.cancel_torrents, name="cancel_torrents"),
    path("export_torrents", views.export_torrents, name="export_torrents"),
    path("transfer_status", views.transfer_status, name="transfer_status"),
    path("manage_vpn", views.manage_vpn, name="manage_vpn"),
    path("vpn_config_load", views.vpn_config_load, name="vpn_config_load"),
    path("vpn_config_save", views.vpn_config_save, name="vpn_config_save"),
    path("add_torrent", views.add_torrent, name="add_torrent"),
]
