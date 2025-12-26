//
//  GhosttyBridge.h
//  GitMac
//
//  Bridging header for Ghostty native integration
//

#ifndef GhosttyBridge_h
#define GhosttyBridge_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Ghostty requires linking against libghostty
// Add to Xcode: Build Phases > Link Binary with Libraries > libghostty.dylib
// Get libghostty from: https://github.com/ghostty-org/ghostty
// Build instructions: zig build -Doptimize=ReleaseFast

// Ghostty C API Forward Declarations
// These will resolve when libghostty is linked

typedef struct ghostty_app ghostty_app_t;
typedef struct ghostty_surface ghostty_surface_t;
typedef struct ghostty_config ghostty_config_t;

// Ghostty Configuration
typedef struct {
    const char *font_family;
    int font_size;
    const char *theme;
    bool gpu_renderer;
} ghostty_config_options_t;

// Ghostty Callbacks
typedef void (*ghostty_title_callback_t)(void *ctx, const char *title);
typedef void (*ghostty_pwd_callback_t)(void *ctx, const char *pwd);
typedef void (*ghostty_bell_callback_t)(void *ctx);

// Ghostty App Functions (from libghostty)
#ifdef __cplusplus
extern "C" {
#endif

// App lifecycle
ghostty_app_t* ghostty_app_new(ghostty_config_t *config);
void ghostty_app_free(ghostty_app_t *app);

// Surface management
ghostty_surface_t* ghostty_surface_new(ghostty_app_t *app);
void ghostty_surface_free(ghostty_surface_t *surface);
NSView* ghostty_surface_get_view(ghostty_surface_t *surface);

// Surface control
void ghostty_surface_write(ghostty_surface_t *surface, const char *data, size_t len);
void ghostty_surface_resize(ghostty_surface_t *surface, int cols, int rows);
void ghostty_surface_set_working_directory(ghostty_surface_t *surface, const char *path);

// Callbacks
void ghostty_surface_set_title_callback(ghostty_surface_t *surface, ghostty_title_callback_t cb, void *ctx);
void ghostty_surface_set_pwd_callback(ghostty_surface_t *surface, ghostty_pwd_callback_t cb, void *ctx);

// Configuration
ghostty_config_t* ghostty_config_new(void);
void ghostty_config_free(ghostty_config_t *config);
void ghostty_config_set_font(ghostty_config_t *config, const char *family, int size);
void ghostty_config_set_theme(ghostty_config_t *config, const char *theme);
void ghostty_config_set_gpu_renderer(ghostty_config_t *config, bool enabled);

#ifdef __cplusplus
}
#endif

// Objective-C wrapper for Swift interop
@interface GhosttyTerminal : NSObject

@property (nonatomic, readonly) NSView *terminalView;
@property (nonatomic, copy) void (^onTitleChange)(NSString *title);
@property (nonatomic, copy) void (^onDirectoryChange)(NSString *directory);

- (instancetype)initWithConfig:(ghostty_config_options_t)config;
- (void)writeInput:(NSString *)input;
- (void)resizeToColumns:(NSInteger)cols rows:(NSInteger)rows;
- (void)setWorkingDirectory:(NSString *)path;
- (void)cleanup;

@end

#endif /* GhosttyBridge_h */
