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

    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown | NSEventMaskKeyUp handler:^NSEvent * (NSEvent * event) {
        bool handled = false;
        NSUInteger flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;

        NSLog(@"MONITOR key window=%@ overlay=%d key=%d, type=%d", [event window], [event window] == this->parentWindow, [event keyCode], [event type]);

        if ([event window] != this->parentWindow && [[event window] isKindOfClass:[AvnWindow class]])
        {
            // This is needed because PowerPoint captures paste events even when inside child windows.
            // For example, hitting Cmd+v in the `About PowerPoint` window will cause previous clipboard 
            // contents to be inserted in the slide. The only child windows that disable paste events
            // are those that completely deactivate PowerPoint's main window (eg. Preferences).

            // Tried makeFirstResponder, makeKeyAndOrderFront without any luck.
            // In order to keep Powerpoint's default behaviour, we will only forward keyboard events
            // that are intended for Avalonia windows.
            
            NSLog(@"MONITOR Forwarding keyboard event to AvnWindow");
            [[event window] sendEvent:event];
            return nil;
        }

        if (flags == NSCommandKeyMask)
        {
            // This code is adapted from AvnView
            // - (void) keyboardEvent: (NSEvent *) event withType: (AvnRawKeyEventType)type

            auto scanCode = [event keyCode];
            auto key = VirtualKeyFromScanCode(scanCode, [event modifierFlags]);
            
            uint64_t timestamp = static_cast<uint64_t>([event timestamp] * 1000);
            AvnInputModifiers modifiers = Windows; // Windows is equivalent to CMD
            AvnRawKeyEventType type;
            
            if ([event type] == NSEventTypeKeyDown)
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
