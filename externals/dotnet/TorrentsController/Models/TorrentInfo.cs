using System.Text.Json.Serialization;

namespace TorrentsController.Models;

public class TorrentInfo
{
    [JsonPropertyName("id")]      public int    Id       { get; set; }
    [JsonPropertyName("name")]    public string Name     { get; set; } = "";
    [JsonPropertyName("status")]  public string Status   { get; set; } = "";
    [JsonPropertyName("progress")]public double Progress { get; set; }
    [JsonPropertyName("done")]    public bool   Done     { get; set; }
    [JsonPropertyName("exporting")]public bool  Exporting{ get; set; }
    [JsonPropertyName("down")]    public string Down     { get; set; } = "";
    [JsonPropertyName("up")]      public string Up       { get; set; } = "";
    [JsonPropertyName("size")]    public string Size     { get; set; } = "";
    [JsonPropertyName("peers")]   public int    Peers    { get; set; }
    [JsonPropertyName("eta")]     public string Eta      { get; set; } = "";
    [JsonPropertyName("error")]   public string Error    { get; set; } = "";
}

public class TorrentListResponse
{
    [JsonPropertyName("success")]  public bool              Success  { get; set; }
    [JsonPropertyName("torrents")] public List<TorrentInfo>? Torrents { get; set; }
    [JsonPropertyName("error")]    public string?           Error    { get; set; }
}

public class TransferFile
{
    [JsonPropertyName("name")]       public string Name      { get; set; } = "";
    [JsonPropertyName("size_bytes")] public long   SizeBytes { get; set; }
    [JsonPropertyName("status")]     public string Status    { get; set; } = "";
}

public class TransferStatusResponse
{
    [JsonPropertyName("active")]     public bool              Active    { get; set; }
    [JsonPropertyName("started_at")] public string?           StartedAt { get; set; }
    [JsonPropertyName("files")]      public List<TransferFile>? Files   { get; set; }
}
