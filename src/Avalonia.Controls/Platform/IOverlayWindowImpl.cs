using System;

namespace Avalonia.Platform
{
    public interface IOverlayWindowImpl
    {
        public Action<string> FirstResponderChanged { get; set; }

        public Func<Point, bool> ShouldPassThrough { get; set; }
    }
}
