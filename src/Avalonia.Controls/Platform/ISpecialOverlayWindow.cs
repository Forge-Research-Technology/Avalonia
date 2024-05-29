using System;
using Avalonia.Input;
using Avalonia.Input.Raw;
using Avalonia.Media.Imaging;

namespace Avalonia.Platform
{
    public interface ISpecialOverlayWindow
    {
        public Action<string> FirstResponderChanged { get; set; }

        public Action<Point> OnSlideMouseActivate { get; set; }

        public Func<Point, bool> ShouldPassThrough { get; set; }

        public Func<RawKeyEventType, Key, RawInputModifiers, bool> MonitorKeyEvent { get; set; }
        
        public PixelPoint PPTClipViewOrigin { get; }

        public Bitmap TakeScreenshot();
    }
}
