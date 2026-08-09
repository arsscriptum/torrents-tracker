using TorrentsController.Forms;

namespace TorrentsController;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new AppContext());
    }
}

sealed class AppContext : ApplicationContext
{
    public AppContext()
    {
        var splash = new SplashForm();
        splash.Closed += OnSplashClosed;
        splash.Show();
    }

    private void OnSplashClosed(object? sender, EventArgs e)
    {
        var main = new MainForm();
        main.FormClosed += (_, _) => ExitThread();
        main.Show();
    }
}
