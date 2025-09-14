// MGBAAudio.h
// mGBA
//
// Created by SternXD on 9/12/25.
//

#include <stdint.h>

struct mCoreThread;

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MGBAAudio : NSObject

- (instancetype)initWithCoreThread:(struct mCoreThread*)thread;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
#endif


