namespace TorrentsController.Forms;

public sealed class SettingsForm : Form
{
    private readonly string _path;
    private RichTextBox _editor = null!;

    public SettingsForm(string configPath)
    {
        _path = configPath;
        BuildUi();
        LoadFile();
    }

    private void BuildUi()
    {
        SuspendLayout();

        Text            = "Settings";
        Size            = new Size(660, 530);
        MinimumSize     = new Size(500, 380);
        StartPosition   = FormStartPosition.CenterParent;
        FormBorderStyle = FormBorderStyle.Sizable;

        // ── Config editor ────────────────────────────────────────────────
        var grpConfig = new GroupBox
        {
            Text    = "config appsettings.json",
            Dock    = DockStyle.Fill,
            Padding = new Padding(6),
        };
        _editor = new RichTextBox
        {
            Dock        = DockStyle.Fill,
            Font        = new Font("Consolas", 10),
            BorderStyle = BorderStyle.None,
            WordWrap    = false,
            ScrollBars  = RichTextBoxScrollBars.Both,
            BackColor   = SystemColors.Window,
        };
        grpConfig.Controls.Add(_editor);

        // ── Bottom strip ─────────────────────────────────────────────────
        var bottom = new Panel { Dock = DockStyle.Bottom, Height = 88 };

        var grpActions = new GroupBox
        {
            Text   = "actions",
            Size   = new Size(232, 72),
            Anchor = AnchorStyles.Top | AnchorStyles.Right,
        };
        bottom.Resize += (_, _) =>
            grpActions.Location = new Point(bottom.ClientSize.Width - grpActions.Width - 10, 8);

        var btnSave   = new Button { Text = "save",   Size = new Size(84, 28), Location = new Point(12,  28) };
        var btnCancel = new Button { Text = "cancel",  Size = new Size(84, 28), Location = new Point(106, 28) };
        btnSave.Click   += OnSave;
        btnCancel.Click += (_, _) => Close();
        grpActions.Controls.AddRange(new Control[] { btnSave, btnCancel });
        bottom.Controls.Add(grpActions);

        // Fill before Bottom so docking resolves correctly
        Controls.Add(grpConfig);
        Controls.Add(bottom);

        ResumeLayout(performLayout: true);
    }

    private void LoadFile()
    {
        try
        {
            if (File.Exists(_path))
                _editor.Text = File.ReadAllText(_path);
        }
        catch (Exception ex)
        {
            _editor.Text = $"// Error loading file: {ex.Message}";
        }
    }

    private void OnSave(object? sender, EventArgs e)
    {
        try
        {
            System.Text.Json.JsonDocument.Parse(_editor.Text);
        }
        catch (System.Text.Json.JsonException ex)
        {
            MessageBox.Show($"Invalid JSON:\n{ex.Message}", "Validation Error",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        try
        {
            File.WriteAllText(_path, _editor.Text);
            DialogResult = DialogResult.OK;
            Close();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Could not save file:\n{ex.Message}", "Save Error",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
