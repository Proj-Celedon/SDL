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

#include "SDL_uikitvideo.h"
#include "../../events/SDL_clipboardevents_c.h"

#import <UIKit/UIPasteboard.h>

@implementation SDL_VideoData
- (void)sendClipboardUpdate:(NSNotification *)aNotification {
    SDL_SendClipboardUpdate();
}
@end

int UIKit_SetClipboardText(_THIS, const char *text)
{
#if TARGET_OS_TV
    return SDL_SetError("The clipboard is not available on tvOS");
#else
    @autoreleasepool {
        [UIPasteboard generalPasteboard].string = @(text);
        return 0;
    }
#endif
}

char *UIKit_GetClipboardText(_THIS)
{
#if TARGET_OS_TV
    return SDL_strdup(""); // Unsupported.
#else
    @autoreleasepool {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSString *string = pasteboard.string;

        if (string != nil) {
            return SDL_strdup(string.UTF8String);
        } else {
            return SDL_strdup("");
        }
    }
#endif
}

SDL_bool UIKit_HasClipboardText(_THIS)
{
    @autoreleasepool {
#if !TARGET_OS_TV
        if ([UIPasteboard generalPasteboard].string != nil) {
            return SDL_TRUE;
        }
#endif
        return SDL_FALSE;
    }
}

void UIKit_InitClipboard(_THIS)
{
    SDL_VideoData *data = (__bridge SDL_VideoData *) _this->driverdata;
    [[NSNotificationCenter defaultCenter] addObserver:data
                                selector:@selector(data:UIKit_sendClipboardUpdate:)
                                name:UIPasteboardChangedNotification
                                object:nil];

}

void UIKit_QuitClipboard(_THIS)
{
    SDL_VideoData *data = (__bridge SDL_VideoData *) _this->driverdata;
    [[NSNotificationCenter defaultCenter] removeObserver:data name:UIPasteboardChangedNotification object:nil];
}

#endif /* SDL_VIDEO_DRIVER_UIKIT_LEGACY */

/* vi: set ts=4 sw=4 expandtab: */
