// GLRenderView.h
// mGBA
//
// Created by SternXD on 9/12/25.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NS_ASSUME_NONNULL_BEGIN

@class MGBCoreBridge;

@interface GLRenderView : UIView

- (void)startDisplay;
- (void)stopDisplay;
- (void)displayFrame;
- (void)updateFrameWithPixels:(const void*)pixels width:(int)width height:(int)height stride:(size_t)stride;

- (void)attachBridge:(MGBCoreBridge*)bridge NS_SWIFT_NAME(attach(_:));

// Integer scaling toggle (aspect fit with nearest integer multiple)
- (void)setIntegerScalingEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END


