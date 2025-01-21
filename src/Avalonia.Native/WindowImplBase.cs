#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Input.Platform;
using Avalonia.Input.Raw;
using Avalonia.Media.Imaging;
using Avalonia.Native.Interop;
using Avalonia.Platform;
using Avalonia.Platform.Storage;
using Avalonia.Platform.Storage.FileIO;
using Avalonia.Rendering.Composition;
using Avalonia.Threading;
using Color = Avalonia.Media.Color;
using Avalonia.Native.Interop;
using Avalonia.Platform;

namespace Avalonia.Native
{
    internal abstract class WindowBaseImpl : TopLevelImpl, IWindowBaseImpl
    {
        internal WindowBaseImpl(IAvaloniaNativeFactory factory) : base(factory)
        {

        }

        public new IAvnWindowBase? Native => _handle?.Native as IAvnWindowBase;

        public PixelPoint Position
        {
            get => Native?.Position.ToAvaloniaPixelPoint() ?? default;
            set => Native?.SetPosition(value.ToAvnPoint());
        }

        public Action? Deactivated { get; set; }
        public Action? Activated { get; set; }

        public Action<PixelPoint>? PositionChanged { get; set; }

        public Size? FrameSize
        {
            get
            {
                if (Native != null)
                {
                    unsafe
                    {
                        var s = new AvnSize { Width = -1, Height = -1 };
                        Native.GetFrameSize(&s);
                        return s.Width < 0  && s.Height < 0 ? null : new Size(s.Width, s.Height);
                    }
                }

                return default;
            }
        }

        public Action<string> FirstResponderChanged { get; set; }
        public Action<Point> OnSlideMouseActivate { get; set; }
        public Func<Point, bool> ShouldPassThrough { get; set; }
        public Func<RawKeyEventType, Key, RawInputModifiers, bool> MonitorKeyEvent { get; set; }

        internal override void Init(MacOSTopLevelHandle handle)
        {
            _handle = handle;

            base.Init(handle);

            var monitor = this.TryGetFeature<IScreenImpl>()!.AllScreens
                .OrderBy(x => x.Scaling)
                .First(m => m.Bounds.Contains(Position));

            Resize(new Size(monitor!.WorkingArea.Width * 0.75d, monitor.WorkingArea.Height * 0.7d), WindowResizeReason.Layout);
        }

        public void Activate()
        {
            Native?.Activate();
        }

        public void Resize(Size clientSize, WindowResizeReason reason)
        {
            Native?.Resize(clientSize.Width, clientSize.Height, (AvnPlatformResizeReason)reason);
        }
        
        public override void SetFrameThemeVariant(PlatformThemeVariant themeVariant)
        {
            Native?.SetFrameThemeVariant((AvnPlatformThemeVariant)themeVariant);
        }

        public override void Dispose()
        {
            Native?.Close();
            base.Dispose();
        }

        public virtual void Show(bool activate, bool isDialog)
        {
            Native?.Show(activate.AsComBool(), isDialog.AsComBool());
        }

        public void Hide()
        {
            Native?.Hide();
        }

        public void BeginMoveDrag(PointerPressedEventArgs e)
        {
            Native?.BeginMoveDrag();
        }

        public Size MaxAutoSizeHint => this.TryGetFeature<IScreenImpl>()!.AllScreens
            .Select(s => s.Bounds.Size.ToSize(1))
            .OrderByDescending(x => x.Width + x.Height).FirstOrDefault();

        public void SetTopmost(bool value)
        {
            Native?.SetTopMost(value.AsComBool());
        }

        // TODO
        public void BeginResizeDrag(WindowEdge edge, PointerPressedEventArgs e)
        {

        }

        public void SetMinMaxSize(Size minSize, Size maxSize)
        {
            Native?.SetMinMaxSize(minSize.ToAvnSize(), maxSize.ToAvnSize());
        }

        internal void BeginDraggingSession(AvnDragDropEffects effects, AvnPoint point, IAvnClipboard clipboard,
            IAvnDndResultCallback callback, IntPtr sourceHandle)
        {
            Native?.BeginDragAndDropOperation(effects, point, clipboard, callback, sourceHandle);
        }

        protected class WindowBaseEvents : TopLevelEvents, IAvnWindowBaseEvents
        {
            private readonly WindowBaseImpl _parent;

            public WindowBaseEvents(WindowBaseImpl parent) : base(parent)
            {
                _parent = parent;
            }

            void IAvnWindowBaseEvents.PositionChanged(AvnPoint position)
            {
                _parent.PositionChanged?.Invoke(position.ToAvaloniaPixelPoint());
            }

            void IAvnWindowBaseEvents.Activated() => _parent.Activated?.Invoke();

            void IAvnWindowBaseEvents.Deactivated() => _parent.Deactivated?.Invoke();

            int IAvnWindowBaseEvents.HitTest(AvnPoint p)
            {
                Point point = p.ToAvaloniaPoint();

                bool result;
                if (_parent.ShouldPassThrough is not null)
                {
                    result = !_parent.ShouldPassThrough(point);
                }
                else
                {
                    result = _parent._inputRoot.InputHitTest(point) is not null;
                }

                System.Diagnostics.Debug.WriteLine($"HitTest {result} {p.X} {p.Y}");
                return result.AsComBool();
            }

            void IAvnWindowBaseEvents.LogFirstResponder(string responder)
            {
                System.Diagnostics.Debug.WriteLine($"Got first responder: {responder}");
                _parent.FirstResponderChanged?.Invoke(responder);
            }

            void IAvnWindowBaseEvents.OnSlideMouseActivate(AvnPoint p)
            {
                System.Diagnostics.Debug.WriteLine($"OnSlideMouseActivate: {p.X} {p.Y}");

                Point point = p.ToAvaloniaPoint();
                _parent.OnSlideMouseActivate?.Invoke(point);
            }

            int IAvnWindowBaseEvents.MonitorKeyEvent(AvnRawKeyEventType type, ulong timeStamp, AvnInputModifiers modifiers, uint key)
            {
                bool result = false;

                if (_parent.MonitorKeyEvent is not null)
                {
                    result = _parent.MonitorKeyEvent((RawKeyEventType)type, (Key)key, (RawInputModifiers)modifiers);
                }

                System.Diagnostics.Debug.WriteLine($"MonitorKeyEvent: {result}");
                return result.AsComBool();
            }
        }
       
        public void Activate()
        {
            _native?.Activate();
        }

        public PixelPoint PPTClipViewOrigin
        {
            get => _native?.PPTClipViewOrigin.ToAvaloniaPixelPoint() ?? default;
        }

        public unsafe Bitmap TakeScreenshot()
        {
            void* bufferData = null;
            int bufferLength = 0;
            _native?.TakeScreenshot(&bufferData, &bufferLength);

            if (bufferData == null || bufferLength == 0) {
                throw new Exception("Error taking screenshot");
            }

            UnmanagedMemoryStream imageBuffer = new UnmanagedMemoryStream((byte*)bufferData, bufferLength);
            return new Bitmap(imageBuffer);
        }

        public unsafe Color? PickColor(Color? initialColor)
        {
            AvnColor _initialColor = new AvnColor { Alpha = 0, Red = 0, Green = 0, Blue = 0 };

            if (initialColor.HasValue) {
                _initialColor = new AvnColor { Alpha = initialColor.Value.A, Red = initialColor.Value.R, Green = initialColor.Value.G, Blue = initialColor.Value.B }; 
            }

            int cancel = 0;
            AvnColor _outputColor = _native?.PickColor(_initialColor, &cancel) ?? default;

            if (cancel != 0) {
                return null;
            }

            return new Color(_outputColor.Alpha, _outputColor.Red, _outputColor.Green, _outputColor.Blue);
        }
    }
}
