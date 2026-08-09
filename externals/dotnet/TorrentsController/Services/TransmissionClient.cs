using System.Text;
using System.Text.Json;

namespace TorrentsController.Services;

public sealed class TransmissionClient : IDisposable
{
    private readonly HttpClient _http;
    private readonly string _url;
    private string _sessionId = "";

    public TransmissionClient(string url)
    {
        _url = url;
        _http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
    }

    public async Task<bool> IsReachableAsync()
    {
        try { await SendAsync("session-stats"); return true; }
        catch { return false; }
    }

    public Task PauseAllAsync()  => SendAsync("torrent-stop");
    public Task ResumeAllAsync() => SendAsync("torrent-start");

    private async Task SendAsync(string method, object? args = null)
    {
        for (int attempt = 0; attempt < 2; attempt++)
        {
            using var req = BuildRequest(method, args);
            var resp = await _http.SendAsync(req);

            if ((int)resp.StatusCode == 409)
            {
                if (resp.Headers.TryGetValues("X-Transmission-Session-Id", out var vals))
                    _sessionId = vals.First();
                continue;
            }
            return;
        }
    }

    private HttpRequestMessage BuildRequest(string method, object? args)
    {
        var body = JsonSerializer.Serialize(new { method, arguments = args ?? (object)new { } });
        var req = new HttpRequestMessage(HttpMethod.Post, _url)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        };
        if (!string.IsNullOrEmpty(_sessionId))
            req.Headers.Add("X-Transmission-Session-Id", _sessionId);
        return req;
    }

    public void Dispose() => _http.Dispose();
}
