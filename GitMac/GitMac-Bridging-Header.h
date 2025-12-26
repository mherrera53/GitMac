//
//  GitMac-Bridging-Header.h
//  GitMac
//
//  Bridging header to import C/Objective-C code into Swift
//

#ifndef GitMac_Bridging_Header_h
#define GitMac_Bridging_Header_h

// Import Ghostty C API
// This header is from GhosttyKit.xcframework
// Only import if the framework is available (not in CI builds)
#if __has_include(<ghostty.h>)
#import <ghostty.h>
#endif

#endif /* GitMac_Bridging_Header_h */
