using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Input;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using MiniMvvm;

namespace ControlCatalog.ViewModels
{
    public class CursorPageViewModel : ViewModelBase
    {
        public CursorPageViewModel()
        {
            StandardCursors = Enum.GetValues(typeof(StandardCursorType))
                .Cast<StandardCursorType>()
                .Select(x => new StandardCursorModel(x))
                .ToList();

            var loader = AvaloniaLocator.Current.GetRequiredService<IAssetLoader>();
            var s = loader.Open(new Uri("avares://ControlCatalog/Assets/avalonia-32.png"));
            var bitmap = new Bitmap(s);
            CustomCursor = new Cursor(bitmap, new PixelPoint(16, 16));

            CustomCursorScaled = new Cursor(
                new ScaledCursor(new Bitmap(loader.Open(new Uri("avares://ControlCatalog/Assets/Duplication-32.png"))), new PixelPoint(1, 1), 1.0),
                new ScaledCursor(new Bitmap(loader.Open(new Uri("avares://ControlCatalog/Assets/Duplication-48.png"))), new PixelPoint(1, 1), 1.5),
                new ScaledCursor(new Bitmap(loader.Open(new Uri("avares://ControlCatalog/Assets/Duplication-64.png"))), new PixelPoint(1, 1), 2.0),
                new ScaledCursor(new Bitmap(loader.Open(new Uri("avares://ControlCatalog/Assets/Duplication-96.png"))), new PixelPoint(1, 1), 3.0),
                new ScaledCursor(new Bitmap(loader.Open(new Uri("avares://ControlCatalog/Assets/Duplication-128.png"))), new PixelPoint(1, 1), 4.0)
                );
        }

        public IEnumerable<StandardCursorModel> StandardCursors { get; }
        
        public Cursor CustomCursor { get; }

        public Cursor CustomCursorScaled { get; }
    }
    
    public class StandardCursorModel
    {
        public StandardCursorModel(StandardCursorType type)
        {
            Type = type;
            Cursor = new Cursor(type);
        }

        public StandardCursorType Type { get; }
            
        public Cursor Cursor { get; }
    }
}
