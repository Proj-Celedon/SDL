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

#import <UIKit/UIKit.h>

#include "SDL_video.h"
#include "SDL_mouse.h"
#include "SDL_hints.h"
#include "../SDL_sysvideo.h"
#include "../SDL_pixels_c.h"
#include "../../events/SDL_events_c.h"

#include "SDL_uikitvideo.h"
#include "SDL_uikitevents.h"
#include "SDL_uikitmodes.h"
#include "SDL_uikitwindow.h"
#include "SDL_uikitopengles.h"
#include "SDL_uikitclipboard.h"
#include "SDL_uikitmessagebox.h"

#define UIKITVID_DRIVER_NAME "uikit_legacy"

/* Initialization/Query functions */
static int UIKit_VideoInit(_THIS);
static void UIKit_VideoQuit(_THIS);

/* DUMMY driver bootstrap functions */

static void UIKit_DeleteDevice(SDL_VideoDevice * device)
{
    @autoreleasepool {
        CFRelease(device->driverdata);
        SDL_free(device);
    }
}

static SDL_VideoDevice *UIKit_CreateDevice(void)
{
    @autoreleasepool {
        SDL_VideoDevice *device;
        /* Initialize all variables that we clean on shutdown */
        device = (SDL_VideoDevice *) SDL_calloc(1, sizeof(SDL_VideoDevice));
        if (!device) {
            SDL_free(device);
            SDL_OutOfMemory();
            return (0);
        }

        /* Set the function pointers */
        device->VideoInit = UIKit_VideoInit;
        device->VideoQuit = UIKit_VideoQuit;
        // device->GetDisplayModes = UIKit_GetDisplayModes;
        // device->SetDisplayMode = UIKit_SetDisplayMode;
        device->PumpEvents = UIKit_PumpEvents;
        device->SuspendScreenSaver = UIKit_SuspendScreenSaver;
        device->CreateSDLWindow = UIKit_CreateWindow;
        // device->SetWindowTitle = UIKit_SetWindowTitle;
        device->ShowWindow = UIKit_ShowWindow;
        // device->HideWindow = UIKit_HideWindow;
        // device->RaiseWindow = UIKit_RaiseWindow;
        // device->SetWindowBordered = UIKit_SetWindowBordered;
        // device->SetWindowFullscreen = UIKit_SetWindowFullscreen;
        // device->SetWindowMouseGrab = UIKit_SetWindowMouseGrab;
        device->DestroyWindow = UIKit_DestroyWindow;
        device->GetWindowWMInfo = UIKit_GetWindowWMInfo;
        device->GetDisplayUsableBounds = UIKit_GetDisplayUsableBounds;
        device->GetDisplayDPI = UIKit_GetDisplayDPI;
        device->GetWindowSizeInPixels = UIKit_GetWindowSizeInPixels;

        // device->SetClipboardText = UIKit_SetClipboardText;
        // device->GetClipboardText = UIKit_GetClipboardText;
        // device->HasClipboardText = UIKit_HasClipboardText;

        /* OpenGL (ES) functions */
#if defined(SDL_VIDEO_OPENGL_ES) || defined(SDL_VIDEO_OPENGL_ES2)
        device->GL_MakeCurrent      = UIKit_GL_MakeCurrent;
        device->GL_GetDrawableSize  = UIKit_GL_GetDrawableSize;
        device->GL_SwapWindow       = UIKit_GL_SwapWindow;
        device->GL_CreateContext    = UIKit_GL_CreateContext;
        device->GL_DeleteContext    = UIKit_GL_DeleteContext;
        device->GL_GetProcAddress   = UIKit_GL_GetProcAddress;
        device->GL_LoadLibrary      = UIKit_GL_LoadLibrary;
#endif
        device->free = UIKit_DeleteDevice;
        device->num_displays = 0;
        device->gl_config.accelerated = 1;

        return device;
    }
}

VideoBootStrap UIKIT_bootstrap = {
    UIKITVID_DRIVER_NAME, "SDL UIKit Legacy video driver",
    UIKit_CreateDevice,
    UIKit_ShowMessageBox
};


int UIKit_VideoInit(_THIS)
{
    UIKit_InitClipboard(_this);
    _this->gl_config.driver_loaded = 1;

    if (UIKit_InitModes(_this) < 0) {
        return -1;
    }

    return 0;
}

void UIKit_VideoQuit(_THIS)
{
}

void UIKit_SuspendScreenSaver(_THIS)
{
    @autoreleasepool {
        /* Ignore ScreenSaver API calls if the idle timer hint has been set. */
        /* FIXME: The idle timer hint should be deprecated for SDL 2.1. */
        if (!SDL_GetHintBoolean(SDL_HINT_IDLE_TIMER_DISABLED, SDL_FALSE)) {
            UIApplication *app = [UIApplication sharedApplication];

            /* Prevent the display from dimming and going to sleep. */
            app.idleTimerDisabled = (_this->suspend_screensaver != SDL_FALSE);
        }
    }
}

CGRect UIKit_ComputeViewFrame(SDL_Window *window, UIScreen *screen)
{
    SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
    CGRect frame = screen.bounds;

    if (data != nil && data.uiwindow != nil) {
        frame = data.uiwindow.bounds;
    }

    return frame;
}

/*
 * iOS log support.
 *
 * This doesn't really have anything to do with the interfaces of the SDL video
 *  subsystem, but we need to stuff this into an Objective-C source code file.
 *
 * NOTE: This is copypasted from src/video/cocoa/SDL_cocoavideo.m! Thus, if
 *  Cocoa is supported, we use that one instead. Be sure both versions remain
 *  identical!
 */

#if !defined(SDL_VIDEO_DRIVER_COCOA)
void SDL_NSLog(const char *prefix, const char *text)
{
    @autoreleasepool {
        NSString *nsText = [NSString stringWithUTF8String:text];
        if (prefix) {
            NSString *nsPrefix = [NSString stringWithUTF8String:prefix];
            NSLog(@"%@: %@", nsPrefix, nsText);
        } else {
            NSLog(@"%@", nsText);
        }
    }
}
#endif /* SDL_VIDEO_DRIVER_COCOA */

/*
 * iOS Tablet detection
 *
 * This doesn't really have aything to do with the interfaces of the SDL video
 * subsystem, but we need to stuff this into an Objective-C source code file.
 */
SDL_bool SDL_IsIPad(void)
{
    return false;
}

#endif /* SDL_VIDEO_DRIVER_UIKIT_LEGACY */

/* vi: set ts=4 sw=4 expandtab: */
