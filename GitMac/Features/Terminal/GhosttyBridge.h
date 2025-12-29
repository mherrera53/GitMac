//
//  GhosttyBridge.h
//  GitMac
//
//  Objective-C bridge to Ghostty C API
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Import the Ghostty C API
#import <ghostty.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper for Ghostty terminal
@interface GhosttyTerminal : NSObject

/// The native NSView containing the terminal
@property (nonatomic, readonly) NSView *terminalView;

/// Callback for terminal title changes
@property (nonatomic, copy, nullable) void (^onTitleChange)(NSString *title);

/// Callback for working directory changes
@property (nonatomic, copy, nullable) void (^onDirectoryChange)(NSString *directory);

/// Initialize with working directory
- (nullable instancetype)initWithWorkingDirectory:(NSString *)workingDirectory;

/// Initialize with custom configuration
- (nullable instancetype)initWithConfig:(ghostty_config_t)config
                       workingDirectory:(NSString *)workingDirectory;

/// Write input to the terminal
- (void)writeInput:(NSString *)input;

/// Set working directory
- (void)setWorkingDirectory:(NSString *)path;

/// Clean up resources
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
