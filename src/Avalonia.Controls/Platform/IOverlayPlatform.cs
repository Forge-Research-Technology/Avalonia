using System;
using Avalonia.Metadata;

namespace Avalonia.Platform
{
    [Unstable]
    public interface IOverlayPlatform
    {
        IWindowImpl CreateOverlay(IntPtr parentWindow, string parentView);
        bool AppActivate(string name);
        void HideWindow(IntPtr nsWindow);
        void ShowFolder(string filePath);
    }

}
