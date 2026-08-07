using System;
using System.IO;
using System.Windows;
using System.Windows.Media;

namespace AgentVideoParse
{
    /// <summary>
    /// Dark/light GUI theme. Dark is the product default; choice is persisted under %AppData%.
    /// Keep visual tokens roughly aligned with the macOS SwiftUI shell.
    /// </summary>
    internal static class ThemeSettings
    {
        public const string Dark = "dark";
        public const string Light = "light";
        public const string Default = Dark;

        private static string ConfigPath
        {
            get
            {
                return Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                    "AgentVideoParse",
                    "appearance.txt");
            }
        }

        public static string Load()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    string t = File.ReadAllText(ConfigPath).Trim().ToLowerInvariant();
                    if (t == Light || t == Dark)
                        return t;
                }
            }
            catch
            {
                /* ignore — fall back to default */
            }
            return Default;
        }

        public static void Save(string theme)
        {
            if (theme != Light && theme != Dark)
                theme = Default;
            try
            {
                string dir = Path.GetDirectoryName(ConfigPath);
                if (!string.IsNullOrEmpty(dir))
                    Directory.CreateDirectory(dir);
                File.WriteAllText(ConfigPath, theme);
            }
            catch
            {
                /* non-fatal */
            }
        }

        public static void Apply(FrameworkElement target, string theme)
        {
            bool dark = !string.Equals(theme, Light, StringComparison.OrdinalIgnoreCase);

            // Dark palette mirrors the shipping macOS dark look; light matches prior Windows defaults.
            var windowBg = Brush(dark, 0x1E, 0x1E, 0x20, 0xF5, 0xF5, 0xF7);
            var panelBg = Brush(dark, 0x2C, 0x2C, 0x2E, 0xFF, 0xFF, 0xFF);
            var text = Brush(dark, 0xF5, 0xF5, 0xF7, 0x1C, 0x1C, 0x1E);
            var secondary = Brush(dark, 0x98, 0x98, 0x9D, 0x6C, 0x6C, 0x70);
            var disclaimerBg = Brush(dark, 0x4A, 0x45, 0x22, 0xFF, 0xF3, 0xCD);
            var disclaimerBorder = Brush(dark, 0x7A, 0x6E, 0x35, 0xE6, 0xC8, 0x66);
            var disclaimerText = Brush(dark, 0xF5, 0xF0, 0xD8, 0x1C, 0x1C, 0x1E);
            var dropFill = Brush(dark, 0x2C, 0x2C, 0x2E, 0xF0, 0xF4, 0xF8);
            var dropBorder = Brush(dark, 0x8E, 0x8E, 0x93, 0x8E, 0x8E, 0x93);
            var controlBg = Brush(dark, 0x3A, 0x3A, 0x3C, 0xE8, 0xE8, 0xED);
            var controlBorder = Brush(dark, 0x54, 0x54, 0x58, 0xC6, 0xC6, 0xC8);
            var inputBg = Brush(dark, 0x28, 0x28, 0x2A, 0xFF, 0xFF, 0xFF);

            Set(target, "WindowBackground", windowBg);
            Set(target, "PanelBackground", panelBg);
            Set(target, "PrimaryText", text);
            Set(target, "SecondaryText", secondary);
            Set(target, "DisclaimerBackground", disclaimerBg);
            Set(target, "DisclaimerBorder", disclaimerBorder);
            Set(target, "DisclaimerText", disclaimerText);
            Set(target, "DropFill", dropFill);
            Set(target, "DropBorder", dropBorder);
            Set(target, "ControlBackground", controlBg);
            Set(target, "ControlBorder", controlBorder);
            Set(target, "InputBackground", inputBg);

            var win = target as Window ?? Window.GetWindow(target);
            if (win != null)
                win.Background = windowBg;
        }

        private static void Set(FrameworkElement target, string key, Brush brush)
        {
            target.Resources[key] = brush;
        }

        private static SolidColorBrush Brush(
            bool dark,
            byte dr, byte dg, byte db,
            byte lr, byte lg, byte lb)
        {
            var b = new SolidColorBrush(
                dark
                    ? Color.FromRgb(dr, dg, db)
                    : Color.FromRgb(lr, lg, lb));
            b.Freeze();
            return b;
        }
    }
}
