using TorrentsController.Models;
using TorrentsController.Services;

namespace TorrentsController.Forms;

public sealed class MainForm : Form
{
    // ── Services ────────────────────────────────────────────────────────────
    private readonly AppSettings      _cfg;
    private readonly TrackerApiClient _tracker;
    private readonly SshDockerService _ssh;
    private readonly TransmissionClient _transmission;

    // ── Menu items ──────────────────────────────────────────────────────────
    private ToolStripMenuItem _miStart   = null!;
    private ToolStripMenuItem _miStop    = null!;
    private ToolStripMenuItem _miRebuild = null!;

    // ── Status bar ──────────────────────────────────────────────────────────
    private ToolStripStatusLabel _dotTracker = null!;
    private ToolStripStatusLabel _txtTracker = null!;
    private ToolStripStatusLabel _dotVpn     = null!;
    private ToolStripStatusLabel _txtVpn     = null!;
    private ToolStripStatusLabel _lblUpdated = null!;

    // ── Content ─────────────────────────────────────────────────────────────
    private RichTextBox  _rtbEvents   = null!;
    private ListView     _lvFiles     = null!;
    private DataGridView _dgvTorrents = null!;
    private TabControl   _tabs        = null!;

    // ── Tray ────────────────────────────────────────────────────────────────
    private NotifyIcon       _tray     = null!;
    private ContextMenuStrip _trayMenu = null!;

    // ── State ───────────────────────────────────────────────────────────────
    private System.Windows.Forms.Timer _pollTimer = null!;
    private DateTime? _pauseUntil;
    private bool _allowClose;

    // Static icons created once — avoids repeated handle allocation
    private static readonly Icon IconGold = MakeCircleIcon(Color.FromArgb(210, 165, 20));
    private static readonly Icon IconGreen = MakeCircleIcon(Color.LimeGreen);
    private static readonly Icon IconRed   = MakeCircleIcon(Color.OrangeRed);

    // ════════════════════════════════════════════════════════════════════════
    //  Construction
    // ════════════════════════════════════════════════════════════════════════

    public MainForm()
    {
        _cfg          = AppSettings.Load();
        _tracker      = new TrackerApiClient(_cfg.TrackerBaseUrl);
        _ssh          = new SshDockerService(_cfg);
        _transmission = new TransmissionClient(_cfg.TransmissionRpcUrl);

        BuildUi();
        BuildTray();

        _pollTimer = new System.Windows.Forms.Timer { Interval = 30_000 };
        _pollTimer.Tick += async (_, _) => await PollAsync();
    }

    // ════════════════════════════════════════════════════════════════════════
    //  UI Construction
    // ════════════════════════════════════════════════════════════════════════

    private void BuildUi()
    {
        SuspendLayout();

        Text          = "Control Center";
        Size          = new Size(920, 640);
        MinimumSize   = new Size(700, 500);
        StartPosition = FormStartPosition.CenterScreen;
        Icon          = IconGold;

        BuildMenuStrip();
        BuildTabControl();
        BuildStatusStrip();

        ResumeLayout(performLayout: true);
    }

    private void BuildMenuStrip()
    {
        var menu = new MenuStrip();

        // ── File ──
        var file = new ToolStripMenuItem("&File");
        file.DropDownItems.Add(new ToolStripMenuItem("&Settings…", null, OnSettings));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(new ToolStripMenuItem("E&xit", null, OnExit));

        // ── Process ──
        var process = new ToolStripMenuItem("&Process");
        _miStart   = new ToolStripMenuItem("Start Torrents Services",  null, OnStart)   { Image = Dot(Color.LimeGreen) };
        _miStop    = new ToolStripMenuItem("Stop Torrent Service",      null, OnStop)    { Image = Dot(Color.OrangeRed) };
        _miRebuild = new ToolStripMenuItem("Rebuild Torrents Service",  null, OnRebuild) { Image = Dot(Color.DodgerBlue) };
        var miRepair = new ToolStripMenuItem("Repair Configuration",    null, OnRepair)  { Image = Dot(Color.Orange) };
        process.DropDownItems.AddRange(new ToolStripItem[]
            { _miStart, _miStop, _miRebuild, new ToolStripSeparator(), miRepair });

        // ── View ──
        var view = new ToolStripMenuItem("&View");
        view.DropDownItems.Add(new ToolStripMenuItem("Hide Window",              null, (_, _) => MinimizeToTray())  { ShortcutKeys = Keys.Control | Keys.M });
        view.DropDownItems.Add(new ToolStripMenuItem("&Refresh",                 null, async (_, _) => await PollAsync()) { ShortcutKeys = Keys.F5 });
        view.DropDownItems.Add(new ToolStripSeparator());
        view.DropDownItems.Add(new ToolStripMenuItem("Show all VPN EXIT NODES",  null, OnShowVpnNodes) { ShortcutKeys = Keys.Alt | Keys.S });
        view.DropDownItems.Add(new ToolStripMenuItem("Clear Event Window",       null, OnClearEvents)  { ShortcutKeys = Keys.Alt | Keys.C });
        view.DropDownItems.Add(new ToolStripMenuItem("List all downloaded files",null, OnListFiles));

        // ── Help ──
        var help = new ToolStripMenuItem("&Help");
        help.DropDownItems.Add(new ToolStripMenuItem("&About", null, OnAbout));

        menu.Items.AddRange(new ToolStripItem[] { file, process, view, help });
        MainMenuStrip = menu;
        Controls.Add(menu);
    }

    private void BuildTabControl()
    {
        _tabs = new TabControl
        {
            Dock    = DockStyle.Fill,
            Padding = new Point(12, 4),
        };

        _tabs.TabPages.Add(BuildLicenseTab());
        _tabs.TabPages.Add(BuildEventsTab());
        _tabs.TabPages.Add(BuildTransferTab());

        Controls.Add(_tabs);
    }

    private TabPage BuildLicenseTab()
    {
        var page = new TabPage("License");
        var rtb = new RichTextBox
        {
            Dock       = DockStyle.Fill,
            ReadOnly   = true,
            BorderStyle = BorderStyle.None,
            BackColor  = SystemColors.Window,
            Font       = new Font("Consolas", 10),
            Text       =
                "TORRENT TRACKER — Control Center\r\n" +
                "Version 1.0\r\n\r\n" +
                "Connects to a Linux server running the torrents-tracker\r\n" +
                "Django app and Transmission/VPN Docker stack via REST\r\n" +
                "API and SSH.\r\n\r\n" +
                "Configuration  (edit appsettings.json in the app folder)\r\n" +
                "──────────────────────────────────────────────────────\r\n" +
                $"  Server host  : {_cfg.ServerHost}\r\n" +
                $"  Tracker port : {_cfg.TrackerPort}\r\n" +
                $"  Transmission : {_cfg.TransmissionPort}\r\n" +
                $"  SSH user     : {_cfg.SshUser}\r\n" +
                $"  Service path : {_cfg.ServicePath}\r\n" +
                $"  Portainer    : {_cfg.PortainerUrl}\r\n\r\n" +
                "Use File › Settings to open the config location.",
        };
        page.Controls.Add(rtb);
        return page;
    }

    private TabPage BuildEventsTab()
    {
        var page  = new TabPage("Events");
        var split = new SplitContainer
        {
            Dock             = DockStyle.Fill,
            SplitterDistance = 570,
            Panel1MinSize    = 280,
            Panel2MinSize    = 160,
        };

        _rtbEvents = new RichTextBox
        {
            Dock        = DockStyle.Fill,
            ReadOnly    = true,
            BackColor   = Color.FromArgb(15, 15, 20),
            ForeColor   = Color.FromArgb(210, 210, 210),
            Font        = new Font("Consolas", 8.5f),
            ScrollBars  = RichTextBoxScrollBars.Vertical,
            BorderStyle = BorderStyle.None,
        };

        _lvFiles = new ListView
        {
            Dock          = DockStyle.Fill,
            View          = View.Details,
            FullRowSelect = true,
            GridLines     = true,
            Font          = new Font("Consolas", 8.5f),
        };
        _lvFiles.Columns.Add("FILE NAME", 175);
        _lvFiles.Columns.Add("Status",     62);
        _lvFiles.Columns.Add("Size",       60);
        _lvFiles.Columns.Add("ETA",        55);

        split.Panel1.Controls.Add(_rtbEvents);
        split.Panel2.Controls.Add(_lvFiles);
        page.Controls.Add(split);
        return page;
    }

    private TabPage BuildTransferTab()
    {
        var page = new TabPage("Transfer");

        _dgvTorrents = new DataGridView
        {
            Dock                  = DockStyle.Fill,
            ReadOnly              = true,
            AllowUserToAddRows    = false,
            AllowUserToDeleteRows = false,
            AutoGenerateColumns   = false,
            AutoSizeColumnsMode   = DataGridViewAutoSizeColumnsMode.Fill,
            SelectionMode         = DataGridViewSelectionMode.FullRowSelect,
            RowHeadersVisible     = false,
            Font                  = new Font("Segoe UI", 9),
            BackgroundColor       = SystemColors.Window,
        };

        _dgvTorrents.Columns.AddRange(new DataGridViewColumn[]
        {
            new DataGridViewTextBoxColumn { HeaderText = "Name",     FillWeight = 35 },
            new DataGridViewTextBoxColumn { HeaderText = "Progress",  FillWeight = 9  },
            new DataGridViewTextBoxColumn { HeaderText = "Status",    FillWeight = 12 },
            new DataGridViewTextBoxColumn { HeaderText = "↓",         FillWeight = 8  },
            new DataGridViewTextBoxColumn { HeaderText = "↑",         FillWeight = 8  },
            new DataGridViewTextBoxColumn { HeaderText = "Size",      FillWeight = 10 },
            new DataGridViewTextBoxColumn { HeaderText = "Peers",     FillWeight = 7  },
            new DataGridViewTextBoxColumn { HeaderText = "ETA",       FillWeight = 11 },
        });

        page.Controls.Add(_dgvTorrents);
        return page;
    }

    private void BuildStatusStrip()
    {
        var strip = new StatusStrip();

        _dotTracker = new ToolStripStatusLabel("●") { ForeColor = Color.Gray, Font = new Font("Segoe UI", 13) };
        _txtTracker = new ToolStripStatusLabel("TORRENTS-TRACKER SERVICE");

        _dotVpn = new ToolStripStatusLabel("●") { ForeColor = Color.Gray, Font = new Font("Segoe UI", 13), Margin = new Padding(8, 0, 0, 0) };
        _txtVpn = new ToolStripStatusLabel("TRANSMISSION VPN SERVICE");

        var spring = new ToolStripStatusLabel { Spring = true };

        _lblUpdated = new ToolStripStatusLabel("") { ForeColor = Color.Gray, Font = new Font("Segoe UI", 8) };

        var btnWebAdmin = new ToolStripButton("WebAdmin")
        {
            DisplayStyle = ToolStripItemDisplayStyle.Text,
            Font         = new Font("Segoe UI", 9, FontStyle.Bold),
        };
        btnWebAdmin.Click += (_, _) => OpenUrl(_cfg.TrackerBaseUrl.Replace("/tracker", "") + "/tracker/transfers");

        strip.Items.AddRange(new ToolStripItem[]
        {
            _dotTracker, _txtTracker,
            _dotVpn, _txtVpn,
            spring, _lblUpdated, btnWebAdmin,
        });

        Controls.Add(strip);
    }

    // ════════════════════════════════════════════════════════════════════════
    //  System Tray
    // ════════════════════════════════════════════════════════════════════════

    private void BuildTray()
    {
        _trayMenu = new ContextMenuStrip();

        void Item(string text, EventHandler handler) =>
            _trayMenu.Items.Add(new ToolStripMenuItem(text, null, handler));
        void Sep() => _trayMenu.Items.Add(new ToolStripSeparator());

        Item("About",            OnAbout);
        Item("Show Window",      (_, _) => ShowWindow());
        Sep();
        Item("Show Transfers",   (_, _) => { ShowWindow(); _tabs.SelectedIndex = 2; });
        Item("Portainer",        (_, _) => OpenUrl(_cfg.PortainerUrl));
        Item("Explore Files",    OnListFiles);
        Sep();
        Item("Start Service",    OnStart);
        Item("Stop Service",     OnStop);
        Item("Rebuild Service",  OnRebuild);
        Sep();

        var miPause = new ToolStripMenuItem("Pause transfers");
        void PauseItem(string lbl, int hours) =>
            miPause.DropDownItems.Add(new ToolStripMenuItem(lbl, null, async (_, _) => await PauseAsync(hours)));
        PauseItem("Pause for 1 hour",  1);
        PauseItem("Pause for 4 hours", 4);
        PauseItem("Pause for 8 hours", 8);
        miPause.DropDownItems.Add(new ToolStripMenuItem("Pause until tomorrow (8AM)", null,
            async (_, _) => await PauseUntilTomorrowAsync()));
        miPause.DropDownItems.Add(new ToolStripMenuItem("Pause indefinitely", null,
            async (_, _) => await PauseAsync(-1)));
        miPause.DropDownItems.Add(new ToolStripSeparator());
        miPause.DropDownItems.Add(new ToolStripMenuItem("Resume transfers", null,
            async (_, _) => await ResumeAsync()));
        _trayMenu.Items.Add(miPause);

        Sep();
        Item("Exit", OnExit);

        _tray = new NotifyIcon
        {
            Icon             = IconGold,
            Text             = "Torrent Tracker",
            ContextMenuStrip = _trayMenu,
            Visible          = true,
        };
        _tray.DoubleClick += (_, _) => ShowWindow();
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Window / tray lifecycle
    // ════════════════════════════════════════════════════════════════════════

    protected override async void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        AppendEvent("Control Center started.");
        AppendEvent($"Server: {_cfg.ServerHost}  |  Tracker: {_cfg.TrackerPort}  |  Transmission: {_cfg.TransmissionPort}");
        _pollTimer.Start();
        await PollAsync();
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (WindowState == FormWindowState.Minimized)
            MinimizeToTray();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (!_allowClose && e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            MinimizeToTray();
            return;
        }
        base.OnFormClosing(e);
    }

    private void MinimizeToTray()
    {
        Hide();
        _tray.ShowBalloonTip(1500, "Torrent Tracker", "Running in the system tray.", ToolTipIcon.Info);
    }

    private void ShowWindow()
    {
        Show();
        WindowState = FormWindowState.Normal;
        BringToFront();
        Activate();
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Polling
    // ════════════════════════════════════════════════════════════════════════

    private async Task PollAsync()
    {
        try
        {
            var trackerUp = await _tracker.IsReachableAsync();
            var vpnUp     = await _transmission.IsReachableAsync();

            _dotTracker.ForeColor = trackerUp ? Color.LimeGreen : Color.OrangeRed;
            _txtTracker.Text      = trackerUp
                ? "TORRENTS-TRACKER SERVICE RUNNING"
                : "TORRENTS-TRACKER SERVICE STOPPED";

            _dotVpn.ForeColor = vpnUp ? Color.LimeGreen : Color.OrangeRed;
            _txtVpn.Text      = vpnUp
                ? "TRANSMISSION VPN SERVICE RUNNING"
                : "TRANSMISSION VPN SERVICE STOPPED";

            _tray.Icon = trackerUp ? IconGreen : IconRed;
            _lblUpdated.Text = $"Updated {DateTime.Now:HH:mm:ss}";

            if (trackerUp)
                await RefreshTorrentsAsync();

            if (_pauseUntil.HasValue && DateTime.Now >= _pauseUntil.Value)
            {
                _pauseUntil = null;
                await ResumeAsync();
                AppendEvent("Scheduled pause expired — transfers resumed.");
            }
        }
        catch (Exception ex)
        {
            AppendEvent($"Poll error: {ex.Message}");
        }
    }

    private async Task RefreshTorrentsAsync()
    {
        var resp = await _tracker.GetTorrentsAsync();
        if (resp?.Success != true || resp.Torrents is null) return;

        // Sidebar file list (Events tab)
        _lvFiles.BeginUpdate();
        _lvFiles.Items.Clear();
        foreach (var t in resp.Torrents)
        {
            var item = new ListViewItem(Clip(t.Name, 26));
            item.SubItems.Add(t.Done ? "Done" : $"{t.Progress:0}%");
            item.SubItems.Add(t.Size);
            item.SubItems.Add(t.Eta);
            if (t.Done) item.ForeColor = Color.Gray;
            if (!string.IsNullOrEmpty(t.Error)) item.ForeColor = Color.OrangeRed;
            _lvFiles.Items.Add(item);
        }
        _lvFiles.EndUpdate();

        // Transfer grid
        _dgvTorrents.Rows.Clear();
        foreach (var t in resp.Torrents)
            _dgvTorrents.Rows.Add(t.Name, $"{t.Progress:0.0}%", t.Status, t.Down, t.Up, t.Size, t.Peers, t.Eta);
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Docker commands
    // ════════════════════════════════════════════════════════════════════════

    private async void OnStart(object? s, EventArgs e)   => await RunDockerAsync("Start",   _ssh.StartAsync);
    private async void OnStop(object? s, EventArgs e)    => await RunDockerAsync("Stop",    _ssh.StopAsync);
    private async void OnRepair(object? s, EventArgs e)
    {
        AppendEvent("Repair: fetching docker compose ps via SSH…");
        var (ok, out_) = await _ssh.StatusAsync();
        foreach (var line in out_.Split('\n', StringSplitOptions.RemoveEmptyEntries))
            AppendEvent(line.TrimEnd());
    }

    private async void OnRebuild(object? s, EventArgs e)
    {
        if (MessageBox.Show(
                "Rebuild the Docker image? This may take several minutes and will\n" +
                "briefly stop the service.",
                "Confirm Rebuild", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes)
            return;
        await RunDockerAsync("Rebuild", _ssh.RebuildAsync);
    }

    private async Task RunDockerAsync(string label, Func<Task<(bool Ok, string Output)>> action)
    {
        AppendEvent($"{label}: connecting via SSH to {_cfg.ServerHost}…");
        SetDockerMenuEnabled(false);
        try
        {
            var (ok, output) = await action();
            foreach (var line in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
                AppendEvent(line.TrimEnd());
            AppendEvent(ok ? $"{label}: completed successfully." : $"{label}: command returned errors — see above.");
            await Task.Delay(1500);
            await PollAsync();
        }
        catch (Exception ex)
        {
            AppendEvent($"{label}: exception — {ex.Message}");
        }
        finally
        {
            SetDockerMenuEnabled(true);
        }
    }

    private void SetDockerMenuEnabled(bool enabled)
    {
        _miStart.Enabled = _miStop.Enabled = _miRebuild.Enabled = enabled;
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Transmission pause / resume
    // ════════════════════════════════════════════════════════════════════════

    private async Task PauseAsync(int hours)
    {
        try
        {
            await _transmission.PauseAllAsync();
            _pauseUntil = hours > 0 ? DateTime.Now.AddHours(hours) : null;
            var msg = hours > 0 ? $"Transfers paused for {hours} hour(s)." : "Transfers paused indefinitely.";
            AppendEvent(msg);
            _tray.ShowBalloonTip(2000, "Torrent Tracker", msg, ToolTipIcon.Info);
        }
        catch (Exception ex)
        {
            AppendEvent($"Pause error: {ex.Message}");
        }
    }

    private async Task PauseUntilTomorrowAsync()
    {
        try
        {
            await _transmission.PauseAllAsync();
            var resume = DateTime.Today.AddDays(1).AddHours(8);
            _pauseUntil = resume;
            var msg = $"Transfers paused until {resume:ddd HH:mm}.";
            AppendEvent(msg);
            _tray.ShowBalloonTip(2000, "Torrent Tracker", msg, ToolTipIcon.Info);
        }
        catch (Exception ex)
        {
            AppendEvent($"Pause error: {ex.Message}");
        }
    }

    private async Task ResumeAsync()
    {
        try
        {
            _pauseUntil = null;
            await _transmission.ResumeAllAsync();
            AppendEvent("Transfers resumed.");
        }
        catch (Exception ex)
        {
            AppendEvent($"Resume error: {ex.Message}");
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Menu / tray handlers
    // ════════════════════════════════════════════════════════════════════════

    private void OnShowVpnNodes(object? s, EventArgs e) =>
        OpenUrl($"{_cfg.TrackerBaseUrl}/manage_vpn");

    private void OnClearEvents(object? s, EventArgs e) => _rtbEvents.Clear();

    private void OnListFiles(object? s, EventArgs e) =>
        OpenUrl($"{_cfg.TrackerBaseUrl}/transfers");

    private void OnSettings(object? s, EventArgs e)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(path)
                { UseShellExecute = true });
        }
        catch
        {
            MessageBox.Show($"Edit appsettings.json at:\n{path}", "Settings",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private void OnAbout(object? s, EventArgs e) =>
        MessageBox.Show(
            "Torrent Tracker — Control Center\nv1.0\n\n" +
            "Controls the torrents-tracker Docker service on your\n" +
            "Linux server via REST API (port 7070) and SSH.\n\n" +
            $"Connected to: {_cfg.ServerHost}",
            "About", MessageBoxButtons.OK, MessageBoxIcon.Information);

    private void OnExit(object? s, EventArgs e)
    {
        _allowClose = true;
        Application.Exit();
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Helpers
    // ════════════════════════════════════════════════════════════════════════

    public void AppendEvent(string message)
    {
        if (InvokeRequired) { Invoke(() => AppendEvent(message)); return; }
        _rtbEvents.AppendText($"{DateTime.Now:yyyy-MM-dd HH:mm:ss}: {message}\n");
        _rtbEvents.ScrollToCaret();
    }

    private static void OpenUrl(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return;
        try
        {
            System.Diagnostics.Process.Start(
                new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch { }
    }

    private static string Clip(string s, int max) =>
        s.Length <= max ? s : s[..(max - 1)] + "…";

    private static Icon MakeCircleIcon(Color c)
    {
        using var bmp = new Bitmap(16, 16);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            using var br = new SolidBrush(c);
            g.FillEllipse(br, 1, 1, 13, 13);
        }
        return Icon.FromHandle(bmp.GetHicon());
    }

    private static Bitmap Dot(Color c)
    {
        var bmp = new Bitmap(12, 12);
        using var g = Graphics.FromImage(bmp);
        g.Clear(Color.Transparent);
        using var b = new SolidBrush(c);
        g.FillEllipse(b, 1, 1, 10, 10);
        return bmp;
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Disposal
    // ════════════════════════════════════════════════════════════════════════

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _pollTimer.Stop();
            _pollTimer.Dispose();
            _tray.Visible = false;
            _tray.Dispose();
            _trayMenu.Dispose();
            _tracker.Dispose();
            _transmission.Dispose();
        }
        base.Dispose(disposing);
    }
}
