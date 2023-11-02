#include "WindowOverlayImpl.h"

WindowOverlayImpl::WindowOverlayImpl(void* parentWindow, char* parentView, IAvnWindowEvents *events) : WindowImpl(events), WindowBaseImpl(events, false, true) {
    this->parentWindow = (__bridge NSWindow*) parentWindow;
    this->parentView = FindNSView(this->parentWindow, [NSString stringWithUTF8String:parentView]);

    [this->parentView addSubview:View];

    // We should ideally choose our parentview to be positioned exactly on top of the main window
    // This is needed to replicate default avalonia behaviour
    // If parentview is positioned differently, we shall adjust the origin and size accordingly (bottom left coordinates)
    NSRect frame = this->parentView.frame;
    frame.size.height += frame.origin.y;
    frame.origin.y = -frame.origin.y;

    [View setFrame:frame];
    lastSize = frame.size;

    [[NSNotificationCenter defaultCenter] addObserver:View selector:@selector(overlayWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:this->parentWindow];
    [[NSNotificationCenter defaultCenter] addObserver:View selector:@selector(overlayWindowDidResignKey:) name:NSWindowDidResignKeyNotification object:this->parentWindow];


    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved handler:^NSEvent * (NSEvent * event) {
        NSLog(@"MONITOR mouseMoved START");

        if ([event window] != this->parentWindow)
        {
            NSLog(@"MONITOR overlay=FALSE -> normal chain");
            return event;
        }

        // We add our own event monitor in order to be able to catch and override all mouse events before PowerPoint.
        // This fixes cursor overrides done by PowerPoint in the NSResponder chain.
        // We add it here in WindowOverlayImpl because we only need to monitor the overlay for events and not any other Avalonia window.

        auto localPoint = [View convertPoint:[event locationInWindow] toView:View];
        auto avnPoint = [AvnView toAvnPoint:localPoint];
        auto point = [View translateLocalPoint:avnPoint];

        auto hitTest = this->BaseEvents->HitTest(point);

        if (hitTest == false)
        {
            NSLog(@"MONITOR overlay=TRUE hitTest=FALSE -> normal chain");
            return event;
        }
        else
        {
            NSLog(@"MONITOR overlay=TRUE hitTest=TRUE -> force event");
            [View mouseMoved:event];
            return nil;
        }
    }];

    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * (NSEvent * event) {
        NSLog(@"MONITOR mouseDown START");

        if ([event window] != this->parentWindow)
        {
            NSLog(@"MONITOR overlay=FALSE -> normal chain");
            return event;
        }

        auto localPoint = [View convertPoint:[event locationInWindow] toView:View];
        auto avnPoint = [AvnView toAvnPoint:localPoint];
        auto point = [View translateLocalPoint:avnPoint];

        auto hitTest = this->BaseEvents->HitTest(point);

        if (hitTest == false)
        {
            this->BaseEvents->OnSlideMouseActivate(point);
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

        *ret = [View translateLocalPoint:ToAvnPoint(viewPoint)];

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
