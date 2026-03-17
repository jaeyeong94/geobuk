//
//  Geobuk-Bridging-Header.h
//  Geobuk
//
//  Bridging header for libghostty C API access from Swift.
//  Only stable API subset is exposed through GhosttyTerminalAdapter.
//

#ifndef Geobuk_Bridging_Header_h
#define Geobuk_Bridging_Header_h

// Full libghostty API (rendering + terminal emulation)
// Requires: Metal, CoreText, AppKit frameworks
#include "../Vendor/ghostty/include/ghostty.h"

#endif /* Geobuk_Bridging_Header_h */
