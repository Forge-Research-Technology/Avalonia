using System;
using System.ComponentModel;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Native.Interop;
using Avalonia.Platform;

namespace Avalonia.Native
{
    internal class AvaloniaNativeApplicationPlatform : NativeCallbackBase, IAvnApplicationEvents, IPlatformLifetimeEventsImpl, ISpecialApplication
    {
        public event EventHandler<ShutdownRequestedEventArgs> ShutdownRequested;
        public Action OnClipboardChange { get; set; }
        
        void IAvnApplicationEvents.FilesOpened(IAvnStringArray urls)
        {
            ((IApplicationPlatformEvents)Application.Current).RaiseUrlsOpened(urls.ToStringArray());
        }
        
        void IAvnApplicationEvents.UrlsOpened(IAvnStringArray urls)
        {
            // Raise the urls opened event to be compatible with legacy behavior.
            ((IApplicationPlatformEvents)Application.Current).RaiseUrlsOpened(urls.ToStringArray());

            if (Application.Current?.ApplicationLifetime is MacOSClassicDesktopStyleApplicationLifetime lifetime)
            {
                foreach (var url in urls.ToStringArray())
                {
                    if (Uri.TryCreate(url, UriKind.RelativeOrAbsolute, out var uri))
                    {
                        lifetime.RaiseUrl(uri);
                    }
                }
            }
        }

        void IAvnApplicationEvents.OnReopen()
        {
            if (Application.Current?.ApplicationLifetime is MacOSClassicDesktopStyleApplicationLifetime lifetime)
            {
                lifetime.RaiseActivated(ActivationKind.Reopen);    
            }
        }

        void IAvnApplicationEvents.OnHide()
        {
            if (Application.Current?.ApplicationLifetime is MacOSClassicDesktopStyleApplicationLifetime lifetime)
            {
                lifetime.RaiseDeactivated(ActivationKind.Background);    
            }
        }

        void IAvnApplicationEvents.OnUnhide()
        {
            if (Application.Current?.ApplicationLifetime is MacOSClassicDesktopStyleApplicationLifetime lifetime)
            {
                lifetime.RaiseActivated(ActivationKind.Background);    
            }
        }

        void IAvnApplicationEvents.OnClipboardChange()
        {
            System.Diagnostics.Debug.WriteLine($"Got clipboard change");
            OnClipboardChange?.Invoke();
        }

        public int TryShutdown()
        {
            if (ShutdownRequested is null) return 1;
            var e = new ShutdownRequestedEventArgs();
            ShutdownRequested(this, e);
            return (!e.Cancel).AsComBool();
        }
    }
}
