//
//  GhosttyBridge.m
//  GitMac
//
//  Objective-C implementation of Ghostty wrapper
//

#import "GhosttyBridge.h"
#import <AppKit/AppKit.h>

@interface GhosttyTerminal () {
    ghostty_app_t *_app;
    ghostty_surface_t *_surface;
    ghostty_config_t *_config;
}
@end

@implementation GhosttyTerminal

- (instancetype)initWithConfig:(ghostty_config_options_t)config {
    self = [super init];
    if (self) {
        // Create Ghostty configuration
        _config = ghostty_config_new();

        if (config.font_family) {
            ghostty_config_set_font(_config, config.font_family, config.font_size);
        }

        if (config.theme) {
            ghostty_config_set_theme(_config, config.theme);
        }

        ghostty_config_set_gpu_renderer(_config, config.gpu_renderer);

        // Create Ghostty app instance
        _app = ghostty_app_new(_config);

        if (!_app) {
            NSLog(@"[Ghostty] Failed to create app instance");
            return nil;
        }

        // Create terminal surface
        _surface = ghostty_surface_new(_app);

        if (!_surface) {
            NSLog(@"[Ghostty] Failed to create surface");
            ghostty_app_free(_app);
            return nil;
        }

        // Set up callbacks
        __weak typeof(self) weakSelf = self;

        ghostty_surface_set_title_callback(_surface, ^(void *ctx, const char *title) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.onTitleChange) {
                NSString *titleStr = [NSString stringWithUTF8String:title];
                dispatch_async(dispatch_get_main_queue(), ^{
                    strongSelf.onTitleChange(titleStr);
                });
            }
        }, (__bridge void *)self);

        ghostty_surface_set_pwd_callback(_surface, ^(void *ctx, const char *pwd) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.onDirectoryChange) {
                NSString *pwdStr = [NSString stringWithUTF8String:pwd];
                dispatch_async(dispatch_get_main_queue(), ^{
                    strongSelf.onDirectoryChange(pwdStr);
                });
            }
        }, (__bridge void *)self);

        NSLog(@"[Ghostty] Terminal initialized successfully");
    }
    return self;
}

- (NSView *)terminalView {
    if (!_surface) {
        return nil;
    }

    // Get the native NSView from Ghostty
    NSView *view = ghostty_surface_get_view(_surface);

    if (!view) {
        NSLog(@"[Ghostty] Failed to get terminal view");
        return nil;
    }

    return view;
}

- (void)writeInput:(NSString *)input {
    if (!_surface || !input) {
        return;
    }

    const char *utf8 = [input UTF8String];
    size_t len = strlen(utf8);

    ghostty_surface_write(_surface, utf8, len);
}

- (void)resizeToColumns:(NSInteger)cols rows:(NSInteger)rows {
    if (!_surface) {
        return;
    }

    ghostty_surface_resize(_surface, (int)cols, (int)rows);
}

- (void)setWorkingDirectory:(NSString *)path {
    if (!_surface || !path) {
        return;
    }

    const char *utf8Path = [path UTF8String];
    ghostty_surface_set_working_directory(_surface, utf8Path);
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
