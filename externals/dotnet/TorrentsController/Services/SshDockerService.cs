using Renci.SshNet;

namespace TorrentsController.Services;

public sealed class SshDockerService
{
    private readonly AppSettings _cfg;

    public SshDockerService(AppSettings cfg) => _cfg = cfg;

    public Task<(bool Ok, string Output)> StartAsync()   => RunAsync($"cd {_cfg.ServicePath} && docker compose up -d 2>&1");
    public Task<(bool Ok, string Output)> StopAsync()    => RunAsync($"cd {_cfg.ServicePath} && docker compose down 2>&1");
    public Task<(bool Ok, string Output)> RebuildAsync() => RunAsync($"cd {_cfg.ServicePath} && docker compose build --no-cache 2>&1 && docker compose up -d 2>&1");
    public Task<(bool Ok, string Output)> StatusAsync()  => RunAsync($"cd {_cfg.ServicePath} && docker compose ps 2>&1");

    public Task<(bool Ok, string Output)> RunAsync(string command) => Task.Run(() =>
    {
        try
        {
            using var client = CreateClient();
            client.Connect();
            using var cmd = client.RunCommand(command);
            client.Disconnect();
            return (cmd.ExitStatus == 0, (cmd.Result + cmd.Error).Trim());
        }
        catch (Exception ex)
        {
            return (false, $"SSH error: {ex.Message}");
        }
    });

    private SshClient CreateClient()
    {
        AuthenticationMethod auth =
            !string.IsNullOrEmpty(_cfg.SshKeyFile) && File.Exists(_cfg.SshKeyFile)
                ? new PrivateKeyAuthenticationMethod(_cfg.SshUser, new PrivateKeyFile(_cfg.SshKeyFile))
                : new PasswordAuthenticationMethod(_cfg.SshUser, _cfg.SshPassword);

        return new SshClient(new ConnectionInfo(_cfg.ServerHost, _cfg.SshUser, auth));
    }
}
