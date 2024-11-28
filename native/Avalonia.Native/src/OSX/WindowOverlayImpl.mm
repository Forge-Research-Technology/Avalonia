#include "WindowOverlayImpl.h"
#include "WindowInterfaces.h"

WindowOverlayImpl::WindowOverlayImpl(void* parentWindow, char* parentView, IAvnWindowEvents *events) : WindowImpl(events), WindowBaseImpl(events, false, true) {
    this->parentWindow = (__bridge NSWindow*) parentWindow;
    this->parentView = FindNSView(this->parentWindow, [NSString stringWithUTF8String:parentView]);
    this->canvasView = FindNSView(this->parentWindow, @"PPTClipView");
    
    // We should ideally choose our parentview to be positioned exactly on top of the main window
    // This is needed to replicate default avalonia behaviour
    // If parentview is positioned differently, we shall adjust the origin and size accordingly (bottom left coordinates)
    [this->parentView addSubview:View];
    
    NSRect frame = this->parentView.frame;
    frame.size.height += frame.origin.y;
    frame.origin.y = -frame.origin.y;

    [View setFrame:frame];
    lastSize = frame.size;

    InitializeColorPicker();

    [[NSNotificationCenter defaultCenter] addObserver:View selector:@selector(overlayWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:this->parentWindow];
    [[NSNotificationCenter defaultCenter] addObserver:View selector:@selector(overlayWindowDidResignKey:) name:NSWindowDidResignKeyNotification object:this->parentWindow];

    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved handler:^NSEvent * (NSEvent * event) {
        //NSLog(@"MONITOR mouseMoved START");

        if ([event window] != this->parentWindow)
        {
            //NSLog(@"MONITOR overlay=FALSE -> normal chain");
            return event;
        }

        // We add our own event monitor in order to be able to catch and override all mouse events before PowerPoint
        // This fixes cursor overrides done by PowerPoint in the NSResponder chain
        // We only need it here in WindowOverlayImpl and not any other Avalonia window

        auto localPoint = [View convertPoint:[event locationInWindow] toView:View];
        auto avnPoint = [AvnView toAvnPoint:localPoint];
        auto point = [View translateLocalPoint:avnPoint];

        auto hitTest = this->BaseEvents->HitTest(point);
        static bool shouldUpdateCursor = false;

        if (hitTest == false)
        {
            //NSLog(@"MONITOR overlay=TRUE hitTest=FALSE -> normal chain");
            shouldUpdateCursor = true;
            return event;
        }
        else
        {
            //NSLog(@"MONITOR overlay=TRUE hitTest=TRUE -> force event");
            if (shouldUpdateCursor)
            {
                // There are times when PowerPoint's NSTrackingArea fires after Avalonia's NSTrackingArea
                // We must ensure that we have the final word for the cursor set by forcing a second update of the cursor

                UpdateCursor();
                shouldUpdateCursor = false;
            }

            [View mouseMoved:event];
            return nil;
        }
    }];

    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * (NSEvent * event) {
        NSLog(@"MONITOR mouseDown START");

        if ([event window] != this->parentWindow)
        {
            NSLog(@"MONITOR window=FALSE overlay=FALSE -> normal chain");
            return event;
        }

        auto localPoint = [View convertPoint:[event locationInWindow] toView:View];
        auto avnPoint = [AvnView toAvnPoint:localPoint];
        auto point = [View translateLocalPoint:avnPoint];

        if (point.Y < 0)
        {
            // Ribbon/title bar above our view
            NSLog(@"MONITOR window=TRUE overlay=FALSE -> ribbon/title bar");
            return event;
        }

        auto hitTest = this->BaseEvents->HitTest(point);
        if (hitTest == false)
        {
            this->BaseEvents->OnSlideMouseActivate(point);
        }

                return event;
    }];

    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged handler:^NSEvent * (NSEvent * event) {
        bool handled = false;
        NSUInteger flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;

        NSLog(@"WOI: Dispatching Key Flags =%ld, Event=%ld", flags, [event type]);

        // When any modifier key is pressed or released, the if block shall execute hence it responds to NSEventTypeFlagsChanged
        if ([event type] == NSEventTypeFlagsChanged)
        {
            NSLog(@"WOI: Captured Key Event Flags =%ld, Event=%ld", flags, [event type]);
            if ([event keyCode] == 9 && [[event window] isKindOfClass:[AvnWindow class]])
            {
                // We treat Cmd+v (keycode 9) in a special way. This is similar to what Avalonia does in the
                // app.mm sendEvent handler but never executed in our case, because PowerPoint already has
                // instantiated an NSApplication. Thus we need to do a similar thing from some other place.

                // PowerPoint catches some of the key events before getting to their normal window handler.
                // Some of those Cmd+key events include: q, w, o, p, a, s, f, h, v, m
                // Those must be key equivalents that get tested via `performKeyEquivalent`, but at this time
                // this is handled in a strange way by Avalonia.

                // When we update to 11.0.9, we should revisit this again.

                // For example, hitting Cmd+v in the `About PowerPoint` window will cause previous clipboard 
                // contents to be inserted in the slide. Other windows completely disable the slide editor,
                // but we don't want to do that (eg. Preferences window).
                
                // Tried makeFirstResponder, makeKeyAndOrderFront without any luck.
                // In order to maintain Powerpoint's default behaviour, we will only manually execute some of
                // those keyboard events that were intended for our Avalonia windows (eg. Data Editor window).
                
                NSLog(@"MONITOR Forcing keyboard event to AvnWindow");
                [[event window] sendEvent:event];
                return nil;
            }
            // This code is adapted from AvnView
            // - (void) keyboardEvent: (NSEvent *) event withType: (AvnRawKeyEventType)type

            auto scanCode = [event keyCode];
            auto key = VirtualKeyFromScanCode(scanCode, [event modifierFlags]);
            
            uint64_t timestamp = static_cast<uint64_t>([event timestamp] * 1000);
            AvnInputModifiers modifiers = GetCommandModifier([event modifierFlags]); 
            AvnRawKeyEventType type;

            // Type flag change with the set modifier is a key down. 
            // Same with the unset modifier is a key up. [When the modifier key is released, the flag changes to 0x0]
            if (modifiers != AvnInputModifiersNone)
            {
                type = KeyDown;
            }
            else
            {
                type = KeyUp;
            }

            handled = this->BaseEvents->MonitorKeyEvent(type, timestamp, modifiers, key);
        }

        NSLog(@"Monitor handled = %d", handled);

        if (handled)
        {
            return nil;
        }

        return event;
    }];
}


AvnInputModifiers WindowOverlayImpl::GetCommandModifier(NSEventModifierFlags modFlag)
{
    unsigned int rv = 0;

    if (modFlag & NSEventModifierFlagControl)
        rv |= Control;
    if (modFlag & NSEventModifierFlagShift)
        rv |= Shift;
    if (modFlag & NSEventModifierFlagOption)
        rv |= Alt;
    if (modFlag & NSEventModifierFlagCommand)
        rv |= Windows;

    if (rv == 0)
        return AvnInputModifiersNone;
    else
        return (AvnInputModifiers)rv;
}


bool WindowOverlayImpl::IsOverlay()
{
    return true;
}


HRESULT WindowOverlayImpl::PointToClient(AvnPoint point, AvnPoint *ret) {
    START_COM_CALL;

    @autoreleasepool {
        if (ret == nullptr) {
            return E_POINTER;
        }

        point = ConvertPointY(point);
        NSRect convertRect = [parentWindow convertRectFromScreen:NSMakeRect(point.X, point.Y, 0.0, 0.0)];

        auto viewPoint = NSMakePoint(convertRect.origin.x, convertRect.origin.y);

        // NSLog(@"PointToClient %@", NSStringFromPoint(viewPoint));
        *ret = [View translateLocalPoint:ToAvnPoint(viewPoint)];

        return S_OK;
    }
}

HRESULT WindowOverlayImpl::GetScaling(double *ret) {
    START_COM_CALL;
    @autoreleasepool {
        if (ret == nullptr)
            return E_POINTER;

        if (parentWindow == nullptr) {
            *ret = 1;
            return S_OK;
        }

        *ret = [parentWindow backingScaleFactor];
        return S_OK;
    }
}

HRESULT WindowOverlayImpl::GetPosition(AvnPoint *ret) {
    START_COM_CALL;

    @autoreleasepool {
        if (ret == nullptr) {
            return E_POINTER;
        }

        if(parentWindow != nullptr) {
            auto frame = [parentWindow frame];

            ret->X = frame.origin.x;
            ret->Y = frame.origin.y + frame.size.height;

            *ret = ConvertPointY(*ret);
        }
        else
        {
            *ret = lastPositionSet;
        }

        return S_OK;
    }
}

HRESULT WindowOverlayImpl::PointToScreen(AvnPoint point, AvnPoint *ret) {
    START_COM_CALL;

    @autoreleasepool {
        if (ret == nullptr) {
            return E_POINTER;
        }

        auto cocoaViewPoint = ToNSPoint([View translateLocalPoint:point]);
        NSRect convertRect = [parentWindow convertRectToScreen:NSMakeRect(cocoaViewPoint.x, cocoaViewPoint.y, 0.0, 0.0)];

        auto cocoaScreenPoint = NSPointFromCGPoint(NSMakePoint(convertRect.origin.x, convertRect.origin.y));
        *ret = ConvertPointY(ToAvnPoint(cocoaScreenPoint));

        return S_OK;
    }
}

HRESULT WindowOverlayImpl::GetPPTClipViewOrigin(AvnPoint *ret) {
    // We need this whenever scrollbars are present inside PPTClipView.
    // This is a fix for PowerPoint's builtin PointsToScreenPixelsX returning
    // the same value regardless of scroll position on Macos.

    START_COM_CALL;

    @autoreleasepool {
        if (ret == nullptr) {
            return E_POINTER;
        }

        if (this->canvasView == nullptr) {
            NSLog(@"PPTClipView not found!");
            return E_FAIL;
        }

        auto canvasOriginPoint = [canvasView bounds].origin;
        ret->X = canvasOriginPoint.x;
        ret->Y = canvasOriginPoint.y;

        return S_OK;
    }
}

HRESULT WindowOverlayImpl::TakeScreenshot(void** ret, int* retLength) {
    NSView* view = [[this->parentWindow contentView] superview];
    
    if (view == nullptr) {
        NSLog(@"TakeScreenshot: contentView or superview not found!");
        return E_FAIL;
    }

    NSSize viewSize = [view bounds].size;
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:NULL
                                  pixelsWide:viewSize.width
                                  pixelsHigh:viewSize.height
                                  bitsPerSample:8
                                  samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                                  colorSpaceName:NSCalibratedRGBColorSpace
                                  bytesPerRow:0
                                  bitsPerPixel:0];

    [view cacheDisplayInRect:[view bounds] toBitmapImageRep:imageRep];

    NSDictionary *imageProps = @{};
    NSData *bitmapData = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:imageProps];
    
    *retLength = [bitmapData length];
    *ret = (void *)[bitmapData bytes];
    
    //NSLog(@"Writing bitmap to file %@", filePath);
    //[bitmapData writeToFile:filePath atomically:YES];

    return S_OK;
}

void WindowOverlayImpl::InitializeColorPicker() {
    this->colorPanel = [NSColorPanel sharedColorPanel];
    this->colorPanel.showsAlpha = true;

    // Create a view to serve as the accessory view
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 40)];

    // Create OK button
    NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 5, 80, 30)];
    [okButton setTitle:@"OK"];
    [okButton setTarget:View];
    [okButton setAction:@selector(colorPanelOkButtonPressed:)];

    // Create Cancel button
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(110, 5, 80, 30)];
    [cancelButton setTitle:@"Cancel"];
    [cancelButton setTarget:View];
    [cancelButton setAction:@selector(colorPanelCancelButtonPressed:)];

    // Add buttons to the accessory view
    [accessoryView addSubview:okButton];
    [accessoryView addSubview:cancelButton];

    // Set the accessory view to the color panel
    [this->colorPanel setAccessoryView:accessoryView];

    [[NSNotificationCenter defaultCenter] addObserver:View selector:@selector(colorPanelWillClose:) name:NSWindowWillCloseNotification object:this->colorPanel];
}

HRESULT WindowOverlayImpl::PickColor(AvnColor color, bool* cancel, AvnColor* ret) {
    NSColor* initialColor = this->colorPanel.color;
    
    this->colorPanel.color = [NSColor colorWithRed:color.Red / 255.0
                                           green:color.Green / 255.0
                                             blue:color.Blue / 255.0
                                           alpha:color.Alpha / 255.0];

    NSInteger modalResponse = [NSApp runModalForWindow:colorPanel];

    // Handle different modal responses
    if (modalResponse == NSModalResponseOK) {
        NSColor *selectedColor = [this->colorPanel color];
        NSLog(@"OK pressed, got back color: %@", selectedColor);

        ret->Alpha = round([selectedColor alphaComponent] * 255.0);
        ret->Red = round([selectedColor redComponent] * 255.0);
        ret->Green = round([selectedColor greenComponent] * 255.0);
        ret->Blue = round([selectedColor blueComponent] * 255.0);
        *cancel = 0;
    } else {
        NSLog(@"Modal session was aborted (cancel or window closed manually).");
        *cancel = 1;
    }

    return S_OK;
}
