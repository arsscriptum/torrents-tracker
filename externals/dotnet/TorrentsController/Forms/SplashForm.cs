using System.Reflection;

namespace TorrentsController.Forms;

public sealed class SplashForm : Form
{
    private readonly PictureBox _pic;
    private readonly System.Windows.Forms.Timer _timer;

    public SplashForm()
    {
        _pic = new PictureBox
        {
            Location  = new Point(140, 15),
            Size      = new Size(200, 200),
            SizeMode  = PictureBoxSizeMode.Zoom,
            BackColor = Color.Transparent,
        };

        var lblTitle = new Label
        {
            Text      = "TORRENT TRACKER",
            Font      = new Font("Consolas", 20, FontStyle.Bold),
            ForeColor = Color.FromArgb(210, 165, 20),
            BackColor = Color.Transparent,
            AutoSize  = false,
            TextAlign = ContentAlignment.MiddleCenter,
            Location  = new Point(0, 228),
            Size      = new Size(480, 46),
        };

        var lblSub = new Label
        {
            Text      = "Control Center  —  Initializing…",
            Font      = new Font("Consolas", 10),
            ForeColor = Color.FromArgb(140, 140, 140),
            BackColor = Color.Transparent,
            AutoSize  = false,
            TextAlign = ContentAlignment.MiddleCenter,
            Location  = new Point(0, 282),
            Size      = new Size(480, 30),
        };

        var lblVersion = new Label
        {
            Text      = "v1.0  ·  Hunt Down Media Files",
            Font      = new Font("Consolas", 8),
            ForeColor = Color.FromArgb(70, 70, 70),
            BackColor = Color.Transparent,
            AutoSize  = false,
            TextAlign = ContentAlignment.MiddleCenter,
            Location  = new Point(0, 322),
            Size      = new Size(480, 24),
        };

        SuspendLayout();
        FormBorderStyle = FormBorderStyle.None;
        StartPosition   = FormStartPosition.CenterScreen;
        Size            = new Size(480, 360);
        BackColor       = Color.FromArgb(18, 18, 18);
        TopMost         = true;
        ShowInTaskbar   = false;
        Controls.AddRange(new Control[] { _pic, lblTitle, lblSub, lblVersion });
        ResumeLayout();

        LoadSplashImage();

        _timer = new System.Windows.Forms.Timer { Interval = 2800 };
        _timer.Tick += (_, _) => { _timer.Stop(); Close(); };
        _timer.Start();
    }

    private void LoadSplashImage()
    {
        try
        {
            var asm = Assembly.GetExecutingAssembly();
            var name = asm.GetManifestResourceNames()
                          .FirstOrDefault(n => n.EndsWith("splash.jpg", StringComparison.OrdinalIgnoreCase));
            if (name is null) return;
            using var stream = asm.GetManifestResourceStream(name);
            if (stream is not null)
                _pic.Image = Image.FromStream(stream);
        }
        catch { }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _timer.Dispose();
            _pic.Image?.Dispose();
        }
        base.Dispose(disposing);
    }
}
