using System.Text.Json;
using TorrentsController.Models;

namespace TorrentsController.Services;

public sealed class TrackerApiClient : IDisposable
{
    private static readonly JsonSerializerOptions JsonOpts = new() { PropertyNameCaseInsensitive = true };
    private readonly HttpClient _http;
    private readonly string _base;

    public TrackerApiClient(string baseUrl)
    {
        _base = baseUrl.TrimEnd('/');
        _http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
    }

    public async Task<bool> IsReachableAsync()
    {
        try { return (await _http.GetAsync($"{_base}/transfer_status")).IsSuccessStatusCode; }
        catch { return false; }
    }

    public async Task<TorrentListResponse?> GetTorrentsAsync()
    {
        try
        {
            var json = await _http.GetStringAsync($"{_base}/torrent_list");
            return JsonSerializer.Deserialize<TorrentListResponse>(json, JsonOpts);
        }
        catch { return null; }
    }

    public async Task<TransferStatusResponse?> GetTransferStatusAsync()
    {
        try
        {
            var json = await _http.GetStringAsync($"{_base}/transfer_status");
            return JsonSerializer.Deserialize<TransferStatusResponse>(json, JsonOpts);
        }
        catch { return null; }
    }

    public void Dispose() => _http.Dispose();
}
