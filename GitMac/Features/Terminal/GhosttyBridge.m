//
//  GhosttyBridge.m
//  GitMac
//
//  Objective-C bridge to Ghostty C API implementation
//

#import "GhosttyBridge.h"
#import <AppKit/AppKit.h>

@interface GhosttyTerminal ()
@property (nonatomic) ghostty_app_t app;
@property (nonatomic) ghostty_config_t config;
@property (nonatomic) ghostty_surface_t surface;
@property (nonatomic, strong) NSView *terminalView;
@end

// C callback functions for runtime

static void wakeup_callback(void *userdata) {
    // Wakeup the main thread if needed
    dispatch_async(dispatch_get_main_queue(), ^{
        // Process events
    });
}

static void close_surface_callback(void *userdata, bool force) {
    GhosttyTerminal *terminal = (__bridge GhosttyTerminal *)userdata;
    if (terminal) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Surface wants to close
            [terminal cleanup];
        });
    }
}

static bool action_callback(ghostty_app_t app, ghostty_target_s target, ghostty_action_s action) {
    // Handle terminal actions
    return true;
}

static void read_clipboard_callback(void *userdata, ghostty_clipboard_e clipboard, void *req) {
    // Read from system clipboard
    dispatch_async(dispatch_get_main_queue(), ^{
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        NSString *string = [pasteboard stringForType:NSPasteboardTypeString];
        if (string) {
            const char *text = [string UTF8String];
            // Complete the clipboard request (simplified)
        }
    });
}

static void write_clipboard_callback(void *userdata,
                                     ghostty_clipboard_e clipboard,
                                     const ghostty_clipboard_content_s *contents,
                                     size_t count,
                                     bool confirm) {
    // Write to system clipboard
    dispatch_async(dispatch_get_main_queue(), ^{
        if (count > 0 && contents[0].data) {
            NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
            [pasteboard clearContents];
            NSString *string = [NSString stringWithUTF8String:contents[0].data];
            [pasteboard setString:string forType:NSPasteboardTypeString];
        }
    });
}

static void confirm_read_clipboard_callback(void *userdata,
                                           const char *text,
                                           void *req,
                                           ghostty_clipboard_request_e type) {
    // Confirm clipboard read (usually just allow)
}

@implementation GhosttyTerminal

- (instancetype)initWithWorkingDirectory:(NSString *)workingDirectory {
    // Create default config
    ghostty_config_t config = ghostty_config_new();
    return [self initWithConfig:config workingDirectory:workingDirectory];
}

- (instancetype)initWithConfig:(ghostty_config_t)config workingDirectory:(NSString *)workingDirectory {
    self = [super init];
    if (self) {
        _config = config;

        // Configure the config
        ghostty_config_load_default_files(config);
        ghostty_config_finalize(config);

        // Create runtime configuration
        ghostty_runtime_config_s runtime_config = {
            .userdata = (__bridge void *)self,
            .supports_selection_clipboard = true,
            .wakeup_cb = wakeup_callback,
            .action_cb = action_callback,
            .read_clipboard_cb = read_clipboard_callback,
            .write_clipboard_cb = write_clipboard_callback,
            .confirm_read_clipboard_cb = confirm_read_clipboard_callback,
            .close_surface_cb = close_surface_callback
        };

        // Create the app
        _app = ghostty_app_new(&runtime_config, config);
        if (!_app) {
            NSLog(@"[Ghostty] Failed to create app");
            return nil;
        }

        // Create surface configuration
        ghostty_surface_config_s surface_config = ghostty_surface_config_new();
        surface_config.platform_tag = GHOSTTY_PLATFORM_MACOS;
        surface_config.userdata = (__bridge void *)self;
        surface_config.scale_factor = [[NSScreen mainScreen] backingScaleFactor];
        surface_config.font_size = 13.0f;

        // Set working directory
        if (workingDirectory) {
            surface_config.working_directory = [workingDirectory UTF8String];
        }

        // Create a container NSView for the terminal
        NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
        surface_config.platform.macos.nsview = (__bridge void *)containerView;

        // Create the surface
        _surface = ghostty_surface_new(_app, &surface_config);
        if (!_surface) {
            NSLog(@"[Ghostty] Failed to create surface");
            ghostty_app_free(_app);
            return nil;
        }

        _terminalView = containerView;

        NSLog(@"[Ghostty] Successfully initialized terminal");
    }
    return self;
}

- (void)writeInput:(NSString *)input {
    if (!_surface) return;

    const char *text = [input UTF8String];
    size_t length = strlen(text);
    ghostty_surface_text(_surface, text, length);
}

- (void)setWorkingDirectory:(NSString *)path {
    // Working directory is set during surface creation
    // For runtime changes, would need to send escape sequence or action
    NSLog(@"[Ghostty] Working directory change requested: %@", path);
}

- (void)cleanup {
    if (_surface) {
        ghostty_surface_free(_surface);
        _surface = NULL;
    }
    if (_app) {
        ghostty_app_free(_app);
        _app = NULL;
    }
    if (_config) {
        ghostty_config_free(_config);
        _config = NULL;
    }
}

- (void)dealloc {
    [self cleanup];
}

@end
