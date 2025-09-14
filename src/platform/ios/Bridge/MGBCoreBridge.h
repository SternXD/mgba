// MGBCoreBridge.h
// mGBA
//
// Created by SternXD on 9/12/25.
//

#include <stdint.h>

// Forward declare the C core type so we can expose an accessor
struct mCore;
struct mCoreThread;

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MGBCoreBridge : NSObject

- (instancetype)init;
- (void)startWithROMPath:(NSString*)romPath NS_SWIFT_NAME(start(withROMPath:));
- (void)stop;
// Flush any pending battery saves to disk; safe to call anytime
- (void)flushSaves;

// Accessor to the underlying C core pointer (for internal callbacks)
- (struct mCore*)coreRef;
// Accessor to the core thread (for sync pacing)
- (struct mCoreThread*)threadRef;

// Save states
- (BOOL)saveState:(int)slot;
- (BOOL)loadState:(int)slot;

// Input keys (bitmask matches core setKeys/addKeys/clearKeys)
- (void)setKeys:(uint32_t)keys;
- (void)addKeys:(uint32_t)keys;
- (void)clearKeys:(uint32_t)keys;

// Option setters (subset of Qt parity)
- (void)setVideoSync:(BOOL)enabled;
- (void)setAudioSync:(BOOL)enabled;
- (void)setFpsTarget:(float)fps;
- (void)setVolume:(int)volume; // 0-100
- (void)setMute:(BOOL)enabled;
- (void)setFrameskip:(int)frameskip;
- (void)setAllowOpposingDirections:(BOOL)enabled;
- (void)setSkipBios:(BOOL)enabled;
- (void)setUseBios:(BOOL)enabled;
- (void)setIdleOptimization:(NSString*)mode; // "ignore"|"remove"|"detect"
- (void)setAutoload:(BOOL)enabled;
- (void)setAutosave:(BOOL)enabled;

// UI/Video toggles
- (void)setShowOSD:(BOOL)enabled;
- (void)setShowFrameCounter:(BOOL)enabled;
- (void)setShowResetInfo:(BOOL)enabled;
- (void)setInterframeBlending:(BOOL)enabled;
- (void)setResampleVideo:(BOOL)enabled;
- (void)setLockAspectRatio:(BOOL)enabled;
- (void)setLockIntegerScaling:(BOOL)enabled;
- (void)setVBABugCompat:(BOOL)enabled;
- (void)setAudioBuffers:(int)size;
- (void)setSampleRate:(int)rate;
- (void)setGBAForceGBP:(BOOL)enabled;

// Fast forward audio settings
- (void)setFastForwardMute:(BOOL)enabled;
- (void)setFastForwardVolume:(int)volume;

// Logging settings
- (void)setLogToFile:(BOOL)enabled;
- (void)setLogToStdout:(BOOL)enabled;
- (void)setLogFile:(NSString*)path;
- (void)setLogLevel:(int)level;

// Rewind
- (void)setRewindEnable:(BOOL)enabled;
- (void)setRewindBufferCapacity:(int)seconds;
- (void)setRewindBufferInterval:(int)ms;

// Fast-forward ratios (-1 for unbounded)
- (void)setFastForwardRatio:(double)ratio;
- (void)setFastForwardHeldRatio:(double)ratio;

// Game Boy options
- (void)setSGBBorders:(BOOL)enabled;
- (void)setGBPalettePreset:(NSString*)name;

// Query GB color presets
- (NSArray<NSString*>*)listGBPalettePresets;

// Multiplayer
- (void)attachMultiplayerLockstep:(void*)lockstepNode;
- (void)detachMultiplayerLockstep;

@property (nonatomic, copy) void (^videoFrame)(const void* pixels, int32_t width, int32_t height, int32_t stride);

@end

NS_ASSUME_NONNULL_END
#endif


