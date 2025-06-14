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

#include "SDL_system.h"
#include "SDL_uikitmodes.h"

#include "../../events/SDL_events_c.h"

#import <sys/utsname.h>

@implementation SDL_DisplayData

- (instancetype)initWithScreen:(UIScreen*)screen
{
    if (self = [super init]) {
        NSDictionary* devices;
        struct utsname systemInfo;
        NSString* deviceName;
        id foundDPI;
        self.uiscreen = screen;

        /*
         * A well up to date list of device info can be found here:
         * https://github.com/lmirosevic/GBDeviceInfo/blob/master/GBDeviceInfo/GBDeviceInfo_iOS.m
         */
        devices = @{
            @"iPhone1,1": @163,
            @"iPhone1,2": @163,
            @"iPhone2,1": @163,
            @"iPhone3,1": @326,
            @"iPhone3,2": @326,
            @"iPhone3,3": @326,
            @"iPhone4,1": @326,
            @"iPhone5,1": @326,
            @"iPhone5,2": @326,
            @"iPhone5,3": @326,
            @"iPhone5,4": @326,
            @"iPhone6,1": @326,
            @"iPhone6,2": @326,
            @"iPhone7,1": @401,
            @"iPhone7,2": @326,
            @"iPhone8,1": @326,
            @"iPhone8,2": @401,
            @"iPhone8,4": @326,
            @"iPhone9,1": @326,
            @"iPhone9,2": @401,
            @"iPhone9,3": @326,
            @"iPhone9,4": @401,
            @"iPhone10,1": @326,
            @"iPhone10,2": @401,
            @"iPhone10,3": @458,
            @"iPhone10,4": @326,
            @"iPhone10,5": @401,
            @"iPhone10,6": @458,
            @"iPhone11,2": @458,
            @"iPhone11,4": @458,
            @"iPhone11,6": @458,
            @"iPhone11,8": @326,
            @"iPhone12,1": @326,
            @"iPhone12,3": @458,
            @"iPhone12,5": @458,
            @"iPad1,1": @132,
            @"iPad2,1": @132,
            @"iPad2,2": @132,
            @"iPad2,3": @132,
            @"iPad2,4": @132,
            @"iPad2,5": @163,
            @"iPad2,6": @163,
            @"iPad2,7": @163,
            @"iPad3,1": @264,
            @"iPad3,2": @264,
            @"iPad3,3": @264,
            @"iPad3,4": @264,
            @"iPad3,5": @264,
            @"iPad3,6": @264,
            @"iPad4,1": @264,
            @"iPad4,2": @264,
            @"iPad4,3": @264,
            @"iPad4,4": @326,
            @"iPad4,5": @326,
            @"iPad4,6": @326,
            @"iPad4,7": @326,
            @"iPad4,8": @326,
            @"iPad4,9": @326,
            @"iPad5,1": @326,
            @"iPad5,2": @326,
            @"iPad5,3": @264,
            @"iPad5,4": @264,
            @"iPad6,3": @264,
            @"iPad6,4": @264,
            @"iPad6,7": @264,
            @"iPad6,8": @264,
            @"iPad6,11": @264,
            @"iPad6,12": @264,
            @"iPad7,1": @264,
            @"iPad7,2": @264,
            @"iPad7,3": @264,
            @"iPad7,4": @264,
            @"iPad7,5": @264,
            @"iPad7,6": @264,
            @"iPad7,11": @264,
            @"iPad7,12": @264,
            @"iPad8,1": @264,
            @"iPad8,2": @264,
            @"iPad8,3": @264,
            @"iPad8,4": @264,
            @"iPad8,5": @264,
            @"iPad8,6": @264,
            @"iPad8,7": @264,
            @"iPad8,8": @264,
            @"iPad11,1": @326,
            @"iPad11,2": @326,
            @"iPad11,3": @326,
            @"iPad11,4": @326,
            @"iPod1,1": @163,
            @"iPod2,1": @163,
            @"iPod3,1": @163,
            @"iPod4,1": @326,
            @"iPod5,1": @326,
            @"iPod7,1": @326,
            @"iPod9,1": @326,
        };

        uname(&systemInfo);
        deviceName =
            [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        foundDPI = [devices objectForKey:deviceName];
        if (foundDPI) {
            self.screenDPI = (float)[foundDPI integerValue];
        } else {
            float scale = 1.0f; // lul
            float defaultDPI = 163.0f;
            self.screenDPI = scale * defaultDPI;
        }
    }
    return self;
}

@synthesize uiscreen;
@synthesize screenDPI;

@end

static int UIKit_AddSingleDisplayMode(SDL_VideoDisplay * display, int w, int h, UIScreen * uiscreen)
{
    SDL_DisplayMode mode;
    SDL_zero(mode);

    mode.format = SDL_PIXELFORMAT_ABGR8888;
    mode.refresh_rate = 0;
    mode.w = w;
    mode.h = h;

    if (SDL_AddDisplayMode(display, &mode)) {
        return 0;
    } else {
        return -1;
    }
}

static int UIKit_AddDisplayMode(SDL_VideoDisplay * display, int w, int h, UIScreen * uiscreen, SDL_bool addRotation)
{
    if (UIKit_AddSingleDisplayMode(display, w, h, uiscreen) < 0) {
        return -1;
    }

    if (addRotation) {
        /* Add the rotated version */
        if (UIKit_AddSingleDisplayMode(display, h, w, uiscreen) < 0) {
            return -1;
        }
    }

    return 0;
}

int UIKit_AddDisplay(UIScreen *uiscreen, SDL_bool send_event)
{
    CGSize size = uiscreen.applicationFrame.size;
    SDL_VideoDisplay display;
    SDL_DisplayMode mode;
    SDL_DisplayData *data;
    SDL_zero(mode);

    /* Make sure the width/height are oriented correctly */
    if (UIKit_IsDisplayLandscape(uiscreen) != (size.width > size.height)) {
        CGFloat height = size.width;
        size.width = size.height;
        size.height = height;
    }

    mode.format = SDL_PIXELFORMAT_ABGR8888;
    mode.refresh_rate = 0;
    mode.w = (int) size.width;
    mode.h = (int) size.height;

    SDL_zero(display);
    display.desktop_mode = mode;
    display.current_mode = mode;

    /* Allocate the display data */
    data = [[SDL_DisplayData alloc] initWithScreen:uiscreen];
    if (!data) {
        return SDL_OutOfMemory();
    }

    display.driverdata = (__bridge_retained void *)data;
    SDL_AddVideoDisplay(&display, send_event);

    return 0;
}

void UIKit_DelDisplay(UIScreen *uiscreen)
{
    int i;

    for (i = 0; i < SDL_GetNumVideoDisplays(); ++i) {
        SDL_DisplayData *data = (__bridge SDL_DisplayData *)SDL_GetDisplayDriverData(i);

        if (data && data.uiscreen == uiscreen) {
            CFRelease(SDL_GetDisplayDriverData(i));
            SDL_GetDisplay(i)->driverdata = NULL;
            SDL_DelVideoDisplay(i);
            return;
        }
    }
}

SDL_bool UIKit_IsDisplayLandscape(UIScreen *uiscreen)
{
#if !TARGET_OS_TV
    if (uiscreen == [UIScreen mainScreen]) {
        return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
    } else
#endif /* !TARGET_OS_TV */
    {
        CGSize size = uiscreen.bounds.size;
        return (size.width > size.height);
    }
}

int UIKit_InitModes(_THIS)
{
    @autoreleasepool {
        if (UIKit_AddDisplay([UIScreen mainScreen], SDL_FALSE) < 0) {
            return -1;
        }
    }

    return 0;
}

void UIKit_GetDisplayModes(_THIS, SDL_VideoDisplay * display)
{
    @autoreleasepool {
        SDL_DisplayData *data = (__bridge SDL_DisplayData *) display->driverdata;
        int w = data.uiscreen.bounds.size.width;
        int h = data.uiscreen.bounds.size.height;
        UIKit_AddDisplayMode(display, w, h, data.uiscreen, false);
    }
}

int UIKit_GetDisplayDPI(_THIS, SDL_VideoDisplay * display, float * ddpi, float * hdpi, float * vdpi)
{
    @autoreleasepool {
        SDL_DisplayData *data = (__bridge SDL_DisplayData *) display->driverdata;
        float dpi = data.screenDPI;

        if (ddpi) {
            *ddpi = dpi * (float)SDL_sqrt(2.0);
        }
        if (hdpi) {
            *hdpi = dpi;
        }
        if (vdpi) {
            *vdpi = dpi;
        }
    }

    return 0;
}

int UIKit_SetDisplayMode(_THIS, SDL_VideoDisplay * display, SDL_DisplayMode * mode)
{
    @autoreleasepool {
        SDL_DisplayData *data = (__bridge SDL_DisplayData *) display->driverdata;

        if (data.uiscreen == [UIScreen mainScreen]) {
            /* [UIApplication setStatusBarOrientation:] no longer works reliably
             * in recent iOS versions, so we can't rotate the screen when setting
             * the display mode. */
            if (mode->w > mode->h) {
                if (!UIKit_IsDisplayLandscape(data.uiscreen)) {
                    return SDL_SetError("Screen orientation does not match display mode size");
                }
            } else if (mode->w < mode->h) {
                if (UIKit_IsDisplayLandscape(data.uiscreen)) {
                    return SDL_SetError("Screen orientation does not match display mode size");
                }
            }
        }
    }

    return 0;
}

int UIKit_GetDisplayUsableBounds(_THIS, SDL_VideoDisplay * display, SDL_Rect * rect)
{
    @autoreleasepool {
        int displayIndex = (int) (display - _this->displays);
        SDL_DisplayData *data = (__bridge SDL_DisplayData *) display->driverdata;
        CGRect frame = data.uiscreen.applicationFrame;

        /* the default function iterates displays to make a fake offset,
         as if all the displays were side-by-side, which is fine for iOS. */
        if (SDL_GetDisplayBounds(displayIndex, rect) < 0) {
            return -1;
        }

        rect->x += frame.origin.x;
        rect->y += frame.origin.y;
        rect->w = frame.size.width;
        rect->h = frame.size.height;
    }

    return 0;
}

void UIKit_QuitModes(_THIS)
{
    int i, j;

    /* Release Objective-C objects, so higher level doesn't free() them. */
    @autoreleasepool {
        for (i = 0; i < _this->num_displays; i++) {
            SDL_VideoDisplay *display = &_this->displays[i];
            if (display->driverdata != NULL) {
                CFRelease(display->driverdata);
                display->driverdata = NULL;
            }
        }
    }
}

#endif /* SDL_VIDEO_DRIVER_UIKIT_LEGACY */

/* vi: set ts=4 sw=4 expandtab: */
