using System.Text.Json;
using System.Text.Json.Serialization;

namespace TorrentsController;

public class AppSettings
{
    [JsonPropertyName("serverHost")]
    public string ServerHost { get; set; } = "192.168.1.100";

    [JsonPropertyName("trackerPort")]
    public int TrackerPort { get; set; } = 7070;

    [JsonPropertyName("transmissionPort")]
    public int TransmissionPort { get; set; } = 9091;

    [JsonPropertyName("sshUser")]
    public string SshUser { get; set; } = "gp";

    [JsonPropertyName("sshPassword")]
    public string SshPassword { get; set; } = "";

    [JsonPropertyName("sshKeyFile")]
    public string SshKeyFile { get; set; } = "";

    [JsonPropertyName("servicePath")]
    public string ServicePath { get; set; } = "/home/services/torrents-tracker";

    [JsonPropertyName("portainerUrl")]
    public string PortainerUrl { get; set; } = "";

    [JsonIgnore]
    public string TrackerBaseUrl => $"http://{ServerHost}:{TrackerPort}/tracker";

    [JsonIgnore]
    public string TransmissionRpcUrl => $"http://{ServerHost}:{TransmissionPort}/transmission/rpc";

    private static readonly string ConfigPath = Path.Combine(
        AppContext.BaseDirectory, "appsettings.json");

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(ConfigPath))
            {
                var json = File.ReadAllText(ConfigPath);
                return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            }
        }
        catch { }
        return new AppSettings();
    }

    public void Save()
    {
        try
        {
            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(ConfigPath, json);
        }
        catch { }
    }
}
