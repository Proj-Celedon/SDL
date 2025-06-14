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

#include "../SDL_sysurl.h"

#import <UIKit/UIKit.h>
#import <Availability.h>

int SDL_SYS_OpenURL(const char *url)
{
    @autoreleasepool {
        NSString *nsstr = [NSString stringWithUTF8String:url];
        NSURL *nsurl = [NSURL URLWithString:nsstr];
        if (![[UIApplication sharedApplication] canOpenURL:nsurl]) {
            return SDL_SetError("No handler registered for this type of URL");
        }
#ifdef __IPHONE_10_0
        if (@available(iOS 10.0, tvOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:nsurl options:@{} completionHandler:^(BOOL success) {}];
        }
        else
#else
        {
            #ifndef SDL_PLATFORM_VISIONOS   /* Fallback is never available in any version of VisionOS (but correct API always is). */
            [[UIApplication sharedApplication] openURL:nsurl];
            #endif
        }
#endif
        return 0;
    }
}

/* vi: set ts=4 sw=4 expandtab: */
