using System;

namespace Avalonia.Platform
{
    public interface ISpecialOverlayWindow
    {
        public Action<string> FirstResponderChanged { get; set; }
        public Action<Point> OnSlideMouseActivate { get; set; }

        public Func<Point, bool> ShouldPassThrough { get; set; }
    }
}
