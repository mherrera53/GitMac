//
//  GitMac-Bridging-Header.h
//  GitMac
//
//  Bridging header to import C/Objective-C code into Swift
//

#ifndef GitMac_Bridging_Header_h
#define GitMac_Bridging_Header_h

// Ghostty C API - only import when framework is available
// To enable: install GhosttyKit.xcframework in Frameworks/ and add GHOSTTY_AVAILABLE to Swift Active Compilation Conditions
#if __has_include(<ghostty.h>)
#import <ghostty.h>
#endif

#endif /* GitMac_Bridging_Header_h */
