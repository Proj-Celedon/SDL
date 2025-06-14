/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2025 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#include "../../SDL_internal.h"

#ifdef SDL_VIDEO_DRIVER_UIKIT_LEGACY

#include "SDL_hints.h"
#include "SDL_mouse.h"
#include "SDL_system.h"
#include "SDL_syswm.h"
#include "SDL_video.h"
#include "../SDL_sysvideo.h"
#include "../SDL_pixels_c.h"
#include "../../events/SDL_events_c.h"

#include "SDL_uikitvideo.h"
#include "SDL_uikitevents.h"
#include "SDL_uikitmodes.h"
#include "SDL_uikitwindow.h"
#import "SDL_uikitappdelegate.h"

#import "SDL_uikitview.h"
#import "SDL_uikitopenglview.h"

#include <Foundation/Foundation.h>

@implementation SDL_WindowData

@synthesize uiwindow;
@synthesize viewcontroller;
@synthesize views;

- (instancetype)init
{
    if ((self = [super init])) {
        views = [NSMutableArray new];
    }

    return self;
}

@end

@interface SDL_uikitwindow : UIWindow

@end

@implementation SDL_uikitwindow

@end


static int SetupWindowData(_THIS, SDL_Window *window, UIWindow *uiwindow, SDL_bool created)
{
    SDL_VideoDisplay *display = SDL_GetDisplayForWindow(window);
    SDL_DisplayData *displaydata = (__bridge SDL_DisplayData *) display->driverdata;
    SDL_uikitview *view;

    CGRect frame = UIKit_ComputeViewFrame(window, displaydata.uiscreen);
    int width  = (int) frame.size.width;
    int height = (int) frame.size.height;

    SDL_WindowData *data = [[SDL_WindowData alloc] init];
    if (!data) {
        return SDL_OutOfMemory();
    }

    window->driverdata = (__bridge_retained void *)data;

    data.uiwindow = uiwindow;

    /* only one window on iOS, always shown */
    window->flags &= ~SDL_WINDOW_HIDDEN;

    if (displaydata.uiscreen != [UIScreen mainScreen]) {
        window->flags &= ~SDL_WINDOW_RESIZABLE;  /* window is NEVER resizable */
        window->flags &= ~SDL_WINDOW_INPUT_FOCUS;  /* never has input focus */
        window->flags |= SDL_WINDOW_BORDERLESS;  /* never has a status bar. */
    }

#if 0 /* Don't set the x/y position, it's already placed on a display */
    window->x = 0;
    window->y = 0;
#endif
    window->w = width;
    window->h = height;

    /* The View Controller will handle rotating the view when the device
     * orientation changes. This will trigger resize events, if appropriate. */
    data.viewcontroller = [[SDL_uikitviewcontroller alloc] initWithSDLWindow:window];

    /* The window will initially contain a generic view so resizes, touch events,
     * etc. can be handled without an active OpenGL view/context. */
    view = [[SDL_uikitview alloc] initWithFrame:frame];

    /* Sets this view as the controller's view, and adds the view to the window
     * heirarchy. */
    [view setSDLWindow:window];

    return 0;
}

int UIKit_CreateWindow(_THIS, SDL_Window *window)
{
    @autoreleasepool {
        SDL_VideoDisplay *display = SDL_GetDisplayForWindow(window);
        SDL_DisplayData *data = (__bridge SDL_DisplayData *) display->driverdata;
        SDL_Window *other;
        UIWindow *uiwindow;

        /* We currently only handle a single window per display on iOS */
        for (other = _this->windows; other; other = other->next) {
            if (other != window && SDL_GetDisplayForWindow(other) == display) {
                return SDL_SetError("Only one window allowed per display.");
            }
        }

        /* ignore the size user requested, and make a fullscreen window */
        /* !!! FIXME: can we have a smaller view? */
        uiwindow = [[SDL_uikitwindow alloc] initWithFrame:data.uiscreen.bounds];

        if (SetupWindowData(_this, window, uiwindow, SDL_TRUE) < 0) {
            return -1;
        }
    }

    return 1;
}

void UIKit_SetWindowTitle(_THIS, SDL_Window * window)
{
    @autoreleasepool {
        SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
        data.viewcontroller.title = @(window->title);
    }
}

void UIKit_ShowWindow(_THIS, SDL_Window * window)
{
    @autoreleasepool {
        SDL_VideoDisplay *display;
        SDL_DisplayData *displaydata;
        SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
        [data.uiwindow makeKeyAndVisible];

        /* Make this window the current mouse focus for touch input */
        display = SDL_GetDisplayForWindow(window);
        displaydata = (__bridge SDL_DisplayData *) display->driverdata;
        if (displaydata.uiscreen == [UIScreen mainScreen]) {
            SDL_SetMouseFocus(window);
            SDL_SetKeyboardFocus(window);
        }
    }
}

void UIKit_HideWindow(_THIS, SDL_Window * window)
{
    @autoreleasepool {
        SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
        data.uiwindow.hidden = YES;
    }
}

void UIKit_RaiseWindow(_THIS, SDL_Window * window)
{
    /* We don't currently offer a concept of "raising" the SDL window, since
     * we only allow one per display, in the iOS fashion.
     * However, we use this entry point to rebind the context to the view
     * during OnWindowRestored processing. */
    _this->GL_MakeCurrent(_this, _this->current_glwin, _this->current_glctx);
}

static void UIKit_UpdateWindowBorder(_THIS, SDL_Window * window)
{
    SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
    SDL_uikitviewcontroller *viewcontroller = data.viewcontroller;

#ifdef SDL_IPHONE_KEYBOARD
    /* Make sure the view is offset correctly when the keyboard is visible. */
    [viewcontroller updateKeyboard];
#endif

    [viewcontroller.view setNeedsLayout];
    [viewcontroller.view layoutIfNeeded];
}

void UIKit_SetWindowBordered(_THIS, SDL_Window * window, SDL_bool bordered)
{
    @autoreleasepool {
        UIKit_UpdateWindowBorder(_this, window);
    }
}

void UIKit_SetWindowFullscreen(_THIS, SDL_Window * window, SDL_VideoDisplay * display, SDL_bool fullscreen)
{
    @autoreleasepool {
        UIKit_UpdateWindowBorder(_this, window);
    }
}

void UIKit_SetWindowMouseGrab(_THIS, SDL_Window * window, SDL_bool grabbed)
{
    /* There really isn't a concept of window grab or cursor confinement on iOS */
}

void UIKit_UpdatePointerLock(_THIS, SDL_Window * window)
{
#if !TARGET_OS_TV
#if defined(__IPHONE_14_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_0
    @autoreleasepool {
        SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
        SDL_uikitviewcontroller *viewcontroller = data.viewcontroller;
        if (@available(iOS 14.0, *)) {
            [viewcontroller setNeedsUpdateOfPrefersPointerLocked];
        }
    }
#endif /* defined(__IPHONE_14_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_0 */
#endif /* !TARGET_OS_TV */
}

void UIKit_DestroyWindow(_THIS, SDL_Window * window)
{
    @autoreleasepool {
        if (window->driverdata != NULL) {
            SDL_WindowData *data = (__bridge SDL_WindowData *)window->driverdata;
            NSArray *views = nil;

            [data.viewcontroller stopAnimation];

            /* Detach all views from this window. We use a copy of the array
             * because setSDLWindow will remove the object from the original
             * array, which would be undesirable if we were iterating over it. */
            views = [data.views copy];
            for (SDL_uikitview *view in views) {
                [view setSDLWindow:NULL];
            }

            /* iOS may still hold a reference to the window after we release it.
             * We want to make sure the SDL view controller isn't accessed in
             * that case, because it would contain an invalid pointer to the old
             * SDL window. */
            views = [data.uiwindow.subviews copy];
            for (UIView *view in views) {
                [view removeFromSuperview];
            }
            data.uiwindow.hidden = YES;

            CFRelease(window->driverdata);
            window->driverdata = NULL;
        }
    }
}

void UIKit_GetWindowSizeInPixels(_THIS, SDL_Window * window, int *w, int *h)
{ @autoreleasepool
{
    SDL_WindowData *windata = (__bridge SDL_WindowData *) window->driverdata;
    UIView *view = windata.viewcontroller.view;
    CGSize size = view.bounds.size;
    CGFloat scale = 1.0;

    /* Integer truncation of fractional values matches SDL_uikitmetalview and
     * SDL_uikitopenglview. */
    *w = size.width * scale;
    *h = size.height * scale;
}}

SDL_bool UIKit_GetWindowWMInfo(_THIS, SDL_Window * window, SDL_SysWMinfo * info)
{
    @autoreleasepool {
        SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;

        if (info->version.major <= SDL_MAJOR_VERSION) {
            int versionnum = SDL_VERSIONNUM(info->version.major, info->version.minor, info->version.patch);

            info->subsystem = SDL_SYSWM_UIKIT;
            info->info.uikit.window = data.uiwindow;

            /* These struct members were added in SDL 2.0.4. */
            if (versionnum >= SDL_VERSIONNUM(2,0,4)) {
#if defined(SDL_VIDEO_OPENGL_ES) || defined(SDL_VIDEO_OPENGL_ES2)
                if ([data.viewcontroller.view isKindOfClass:[SDL_uikitopenglview class]]) {
                    SDL_uikitopenglview *glview = (SDL_uikitopenglview *)data.viewcontroller.view;
                    info->info.uikit.framebuffer = glview.drawableFramebuffer;
                    info->info.uikit.colorbuffer = glview.drawableRenderbuffer;
                    info->info.uikit.resolveFramebuffer = 0;
                } else {
#else
                {
#endif
                    info->info.uikit.framebuffer = 0;
                    info->info.uikit.colorbuffer = 0;
                    info->info.uikit.resolveFramebuffer = 0;
                }
            }

            return SDL_TRUE;
        } else {
            SDL_SetError("Application not compiled with SDL %d",
                         SDL_MAJOR_VERSION);
            return SDL_FALSE;
        }
    }
}

int SDL_iPhoneSetAnimationCallback(SDL_Window * window, int interval, SDL_iOSAnimationCallback callback, void *callbackParam)
{
    if (!window || !window->driverdata) {
        return SDL_SetError("Invalid window");
    }

    @autoreleasepool {
        SDL_WindowData *data = (__bridge SDL_WindowData *)window->driverdata;
        [data.viewcontroller setAnimationCallback:interval
                                         callback:callback
                                    callbackParam:callbackParam];
    }

    return 0;
}

#endif /* SDL_VIDEO_DRIVER_UIKIT_LEGACY */

/* vi: set ts=4 sw=4 expandtab: */
