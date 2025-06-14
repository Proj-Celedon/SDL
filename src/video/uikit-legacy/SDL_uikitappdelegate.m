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

#include "../SDL_sysvideo.h"
#include "SDL_hints.h"
#include "SDL_system.h"
#include "SDL_main.h"

#import "SDL_uikitevents.h"
#import "SDL_uikitappdelegate.h"
#import "SDL_uikitmodes.h"
#import "SDL_uikitwindow.h"

#include "../../events/SDL_events_c.h"

#include <Availability.h>

#ifdef main
#undef main
#endif

static SDL_main_func forward_main;
static int forward_argc;
static char **forward_argv;
static int exit_status;

int SDL_UIKitRunApp(int argc, char *argv[], SDL_main_func mainFunction)
{
    int i;

    /* store arguments */
    forward_main = mainFunction;
    forward_argc = argc;
    forward_argv = (char **)malloc((argc+1) * sizeof(char *));
    for (i = 0; i < argc; i++) {
        forward_argv[i] = malloc( (strlen(argv[i])+1) * sizeof(char));
        strcpy(forward_argv[i], argv[i]);
    }
    forward_argv[i] = NULL;

    /* Give over control to run loop, SDLUIKitDelegate will handle most things from here */
    @autoreleasepool {
        UIApplicationMain(argc, argv, nil, [SDLUIKitDelegate getAppDelegateClassName]);
    }

    /* free the memory we used to hold copies of argc and argv */
    for (i = 0; i < forward_argc; i++) {
        free(forward_argv[i]);
    }
    free(forward_argv);

    return exit_status;
}

static void SDLCALL
SDL_IdleTimerDisabledChanged(void *userdata, const char *name, const char *oldValue, const char *hint)
{
    BOOL disable = (hint && *hint != '0');
    [UIApplication sharedApplication].idleTimerDisabled = disable;
}

@implementation SDLUIKitDelegate {
    UIWindow *launchWindow;
}

/* convenience method */
+ (id)sharedAppDelegate
{
    /* the delegate is set in UIApplicationMain(), which is guaranteed to be
     * called before this method */
    return [UIApplication sharedApplication].delegate;
}

+ (NSString *)getAppDelegateClassName
{
    /* subclassing notice: when you subclass this appdelegate, make sure to add
     * a category to override this method and return the actual name of the
     * delegate */
    return @"SDLUIKitDelegate";
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSBundle *bundle = [NSBundle mainBundle];

    /* Set working directory to resource path */
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[bundle resourcePath]];

    /* register a callback for the idletimer hint */
    SDL_AddHintCallback(SDL_HINT_IDLE_TIMER_DISABLED,
                        SDL_IdleTimerDisabledChanged, NULL);
    SDL_SetMainReady();
    [self performSelector:@selector(postFinishLaunch) withObject:nil afterDelay:0.0];

    return YES;
}

- (void)postFinishLaunch
{
    // run the user's application, passing argc and argv
    SDL_SetiOSEventPump(true);
    exit_status = forward_main(forward_argc, forward_argv);
    SDL_SetiOSEventPump(false);
}

- (UIWindow *)window
{
    SDL_VideoDevice *_this = SDL_GetVideoDevice();
    if (_this) {
        SDL_Window *window = NULL;
        for (window = _this->windows; window != NULL; window = window->next) {
            SDL_WindowData *data = (__bridge SDL_WindowData *) window->driverdata;
            if (data != nil) {
                return data.uiwindow;
            }
        }
    }
    return nil;
}

- (void)setWindow:(UIWindow *)window
{
    /* Do nothing. */
}

@end

#endif /* SDL_VIDEO_DRIVER_UIKIT_LEGACY */

/* vi: set ts=4 sw=4 expandtab: */
