using System;

namespace Avalonia.Platform
{
    public interface ISpecialApplication
    {
        public Action OnClipboardChange { get; set; }
    }
}