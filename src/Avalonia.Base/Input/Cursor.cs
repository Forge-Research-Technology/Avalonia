using System;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

#nullable enable

namespace Avalonia.Input
{
    public enum StandardCursorType
    {
        Arrow,
        Ibeam,
        Wait,
        Cross,
        UpArrow,
        SizeWestEast,
        SizeNorthSouth,
        SizeAll,
        No,
        Hand,
        AppStarting,
        Help,
        TopSide,
        BottomSide,
        LeftSide,
        RightSide,
        TopLeftCorner,
        TopRightCorner,
        BottomLeftCorner,
        BottomRightCorner,
        DragMove,
        DragCopy,
        DragLink,
        None,
        
        // Not available in GTK directly, see https://www.pixelbeat.org/programming/x_cursors/
        // We might enable them later, preferably, by loading pixmax directly from theme with fallback image
        // SizeNorthWestSouthEast,
        // SizeNorthEastSouthWest,
    }

    public class ScaledCursor
    {
        public ScaledCursor(Bitmap cursor, PixelPoint hotSpot, double scale)
        {
            Cursor = cursor;
            HotSpot = hotSpot;
            Scale = scale;
        }

        public Bitmap Cursor { get; }
        public PixelPoint HotSpot { get; }
        public double Scale { get; }
    }

    public class Cursor : IDisposable
    {
        public static readonly Cursor Default = new Cursor(StandardCursorType.Arrow);
        private string _name;
        private ScaledCursor[]? _scaledImages;
        private int _loadedScaleIndex = 0;

        private Cursor(ICursorImpl platformImpl, string name)
        {
            PlatformImpl = platformImpl;
            _name = name;
        }

        public Cursor(StandardCursorType cursorType)
            : this(GetCursorFactory().GetCursor(cursorType), cursorType.ToString())
        {
        }

        public Cursor(Bitmap cursor, PixelPoint hotSpot)
            : this(GetCursorFactory().CreateCursor(cursor.PlatformImpl.Item, hotSpot), "BitmapCursor")
        {
        }

        public Cursor(params ScaledCursor[] scaledImages)
            : this(GetCursorFactory().CreateCursor(scaledImages[0].Cursor.PlatformImpl.Item, scaledImages[0].HotSpot), "BitmapCursor")
        {
            _scaledImages = scaledImages;
        }

        public ICursorImpl PlatformImpl { get; private set; }

        public void Dispose() => PlatformImpl.Dispose();

        public void Scale(double scale)
        {
            if (_scaledImages is null)
                return;

            var bestIndex = FindClosestScaleIndex(scale);

            if (bestIndex == _loadedScaleIndex)
                return;

            var bestImage = _scaledImages[bestIndex];

            PlatformImpl.Dispose();

            PlatformImpl = GetCursorFactory().CreateCursor(bestImage.Cursor.PlatformImpl.Item, bestImage.HotSpot);

            _loadedScaleIndex = bestIndex;
        }

        private int FindClosestScaleIndex(double scale)
        {
            if(_scaledImages is null)
                return -1;

            var bestIndex = -1;
            var bestScale = 0.0;

            for (int i = 0; i < _scaledImages.Length; i++)
            {
                var image = _scaledImages[i];
                if (bestIndex == -1)
                {
                    bestIndex = i;
                    bestScale = image.Scale;
                }
                else if(Math.Abs(image.Scale - scale) < Math.Abs(bestScale - scale))
                {
                    bestIndex = i;
                    bestScale = image.Scale;
                }
            }

            return bestIndex;
        }

        public static Cursor Parse(string s)
        {
            return Enum.TryParse<StandardCursorType>(s, true, out var t) ?
                new Cursor(t) :
                throw new ArgumentException($"Unrecognized cursor type '{s}'.");
        }

        private static ICursorFactory GetCursorFactory()
        {
            return AvaloniaLocator.Current.GetRequiredService<ICursorFactory>();
        }

        public override string ToString()
        {
            return _name;
        }
    }
}
