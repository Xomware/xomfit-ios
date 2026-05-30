#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "XomFitBanner" asset catalog image resource.
static NSString * const ACImageNameXomFitBanner AC_SWIFT_PRIVATE = @"XomFitBanner";

/// The "XomFitLogo" asset catalog image resource.
static NSString * const ACImageNameXomFitLogo AC_SWIFT_PRIVATE = @"XomFitLogo";

#undef AC_SWIFT_PRIVATE
