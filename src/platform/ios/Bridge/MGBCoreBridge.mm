// MGBCoreBridge.mm
// mGBA
//
// Created by SternXD on 9/12/25.
//

@class NSString;
#import "MGBCoreBridge.h"

#import <mgba/flags.h>
#import <mgba/core/core.h>
#import <mgba/core/interface.h>
#import <mgba/core/config.h>
#import <mgba/core/thread.h>
#import <mgba/core/serialize.h>
#import <mgba-util/vfs.h>
#import <mgba-util/image.h>
#import "MGBAAudio.h"
#import <mgba/gb/interface.h>

#import <mgba/internal/gba/gba.h>
#import <mgba/internal/gba/video.h>
#import <mgba-util/math.h>
#import <mgba/internal/gba/memory.h>
#import <mgba/internal/gba/audio.h>
#import <mgba/internal/gba/sio.h>
#import <mgba/internal/gba/sio/lockstep.h>
#import <mgba/internal/gb/sio/lockstep.h>
#import <mgba/internal/gb/gb.h>
#import <mgba/internal/gba/timer.h>
#import <mgba/internal/gba/io.h>
#import <mgba/internal/arm/arm.h>
#import <mgba/internal/gba/savedata.h>

#include <stddef.h>
#include <stdint.h>
#include <fcntl.h>
#include <string.h>

static MGBCoreBridge* gBridge = nil;

static void _onThreadStart(struct mCoreThread* thread) {
	UNUSED(thread);
}

static void _onVideoFrameEnded(void* context) {
	MGBCoreBridge* self = (__bridge MGBCoreBridge*) context;
	if (!self) {
		return;
	}
	struct mCore* core = [self coreRef];
	if (!core) {
		return;
	}
	unsigned w = 0, h = 0;
	core->currentVideoSize(core, &w, &h);
	const void* buffer = NULL;
	size_t stride = 0;
	core->getPixels(core, &buffer, &stride);
	if (!buffer || !w || !h) {
		return;
	}
	void (^frameBlock)(const void*, int32_t, int32_t, int32_t) = [self videoFrame];
	if (frameBlock) {
		frameBlock(buffer, (int32_t) w, (int32_t) h, (int32_t) stride);
	}
}

@implementation MGBCoreBridge {
	struct mCore* _core;
	struct mCoreThread _thread;
	struct mAVStream _stream;
	mColor* _fb;
	size_t _fbStride;
	MGBAAudio* _audio;
}

-(struct mCore*)coreRef { return _core; }
-(struct mCoreThread*)threadRef { return &_thread; }

- (instancetype)init {
	self = [super init];
	if (self) {
		gBridge = self;
		_fb = NULL;
		_fbStride = 0;
	}
	return self;
}

- (void)startWithROMPath:(NSString*)romPath {
	const char* path = [romPath fileSystemRepresentation];

	// Open the ROM via VFS and detect/create a concrete core
	struct VFile* vf = VFileOpen(path, O_RDONLY);
	if (!vf) {
		return;
	}
	_core = mCoreFindVF(vf);
	if (!_core || !_core->init || !_core->loadROM) {
		vf->close(vf);
		_core = NULL;
		return;
	}
	if (!_core->init(_core)) {
		vf->close(vf);
		if (_core->deinit) { _core->deinit(_core); }
		_core = NULL;
		return;
	}
	mCoreInitConfig(_core, NULL);
	mCoreLoadConfig(_core);

	_core->opts.skipBios = true;
	_core->opts.videoSync = false;
	_core->opts.audioSync = false;
	_core->opts.fpsTarget = 60.0f;

	unsigned bw = 0, bh = 0;
	_core->baseVideoSize(_core, &bw, &bh);
	_fbStride = bw ? bw : 256;
	size_t fbSize = _fbStride * (bh ? bh : 160);
	_fb = (mColor*) malloc(fbSize * sizeof(mColor));
	if (_fb) {
		_core->setVideoBuffer(_core, _fb, _fbStride);
	}

	struct mCoreCallbacks cbs;
	memset(&cbs, 0, sizeof(cbs));
	cbs.context = (__bridge void*) self;
	cbs.videoFrameEnded = _onVideoFrameEnded;
	_core->addCoreCallbacks(_core, &cbs);

	vf->seek(vf, 0, SEEK_SET);
	if (!_core->loadROM(_core, vf)) {
		vf->close(vf);
		if (_core->deinit) { _core->deinit(_core); }
		_core = NULL;
		free(_fb); _fb = NULL;
		return;
	}
	(void) mCoreAutoloadSave(_core);

	[[NSUserDefaults standardUserDefaults] setObject:romPath forKey:@"LastROMPath"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	memset(&_thread, 0, sizeof(_thread));
	_thread.core = _core;
	_thread.startCallback = _onThreadStart;
	mCoreThreadStart(&_thread);

	// After thread has started, its impl is valid; now hand sync to core
	if (_core->setSync && _thread.impl) {
		_core->setSync(_core, &_thread.impl->sync);
	}

	// Start audio engine
	_audio = [[MGBAAudio alloc] initWithCoreThread:&_thread];
	[_audio start];
}

- (void)stop {
	// Ensure saves are flushed before tearing down
	[self flushSaves];
	// Stop core thread if started
	if (_thread.core) {
		mCoreThreadEnd(&_thread);
		mCoreThreadJoin(&_thread);
	}
	if (_core && _core->unloadROM) {
		_core->unloadROM(_core);
	}
	if (_core) {
		_core->deinit(_core);
		_core = NULL;
	}
	if (_audio) {
		[_audio stop];
		_audio = nil;
	}
	if (_fb) {
		free(_fb);
		_fb = NULL;
	}
}

- (void)flushSaves {
	if (!_core) { return; }
	if (_thread.core) {
		mCoreThreadEnd(&_thread);
		mCoreThreadJoin(&_thread);
	}
	if (_core->unloadROM) {
		_core->unloadROM(_core);
	}
}

- (BOOL)saveState:(int)slot {
	if (!_core) return NO;
	return mCoreSaveState(_core, slot, SAVESTATE_SAVEDATA | SAVESTATE_RTC | SAVESTATE_METADATA);
}

- (BOOL)loadState:(int)slot {
	if (!_core) return NO;
	return mCoreLoadState(_core, slot, SAVESTATE_SAVEDATA | SAVESTATE_RTC | SAVESTATE_METADATA);
}

- (void)setKeys:(uint32_t)keys {
	if (_core && _core->setKeys) { _core->setKeys(_core, keys); }
}

- (void)addKeys:(uint32_t)keys {
	if (_core && _core->addKeys) { _core->addKeys(_core, keys); }
}

- (void)clearKeys:(uint32_t)keys {
	if (_core && _core->clearKeys) { _core->clearKeys(_core, keys); }
}

- (void)setVideoSync:(BOOL)enabled {
	if (_core) { _core->opts.videoSync = enabled; }
}

- (void)setAudioSync:(BOOL)enabled {
	if (_core) { _core->opts.audioSync = enabled; }
}

- (void)setFpsTarget:(float)fps {
	if (_core) { _core->opts.fpsTarget = fps; }
}

- (void)setVolume:(int)volume {
	if (_core) { _core->opts.volume = volume; _core->reloadConfigOption(_core, "volume", NULL); }
}

- (void)setMute:(BOOL)enabled {
	if (_core) { _core->opts.mute = enabled; _core->reloadConfigOption(_core, "mute", NULL); }
}

- (void)setFrameskip:(int)frameskip {
	if (_core) { _core->opts.frameskip = frameskip; _core->reloadConfigOption(_core, "frameskip", NULL); }
}

- (void)setAllowOpposingDirections:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "allowOpposingDirections", enabled); _core->reloadConfigOption(_core, "allowOpposingDirections", NULL); }
}

- (void)setSkipBios:(BOOL)enabled {
	if (_core) { _core->opts.skipBios = enabled; }
}

- (void)setUseBios:(BOOL)enabled {
	if (_core) { _core->opts.useBios = enabled; }
}

- (void)setIdleOptimization:(NSString*)mode {
	if (!_core) return;
	const char* m = [mode UTF8String];
	mCoreConfigSetValue(&_core->config, "idleOptimization", m);
	_core->reloadConfigOption(_core, "idleOptimization", NULL);
}

- (void)setAutoload:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "autoload", enabled); }
}

- (void)setAutosave:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "autosave", enabled); }
}

- (void)setShowOSD:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "showOSD", enabled); }
}

- (void)setShowFrameCounter:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "showFrameCounter", enabled); }
}

- (void)setInterframeBlending:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "interframeBlending", enabled); }
}

- (void)setShowResetInfo:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "showResetInfo", enabled); }
}

- (void)setResampleVideo:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "resampleVideo", enabled); }
}

- (void)setLockAspectRatio:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "lockAspectRatio", enabled); }
}

- (void)setVBABugCompat:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "vbaBugCompat", enabled); }
}

- (void)setLockIntegerScaling:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "lockIntegerScaling", enabled); }
}

- (void)setAudioBuffers:(int)size {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "audioBuffers", size); }
}

- (void)setSampleRate:(int)rate {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "sampleRate", rate); }
}

- (void)setGBAForceGBP:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "gba.forceGbp", enabled); }
}

- (void)setFastForwardMute:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "fastForwardMute", enabled); }
}

- (void)setFastForwardVolume:(int)volume {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "fastForwardVolume", volume); }
}

- (void)setLogToFile:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "logToFile", enabled); }
}

- (void)setLogToStdout:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "logToStdout", enabled); }
}

- (void)setLogFile:(NSString*)path {
	if (_core) { mCoreConfigSetValue(&_core->config, "logFile", [path UTF8String]); }
}

- (void)setLogLevel:(int)level {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "logLevel", level); }
}

- (void)setRewindEnable:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "rewindEnable", enabled); }
}

- (void)setRewindBufferCapacity:(int)seconds {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "rewindBufferCapacity", seconds); }
}

- (void)setRewindBufferInterval:(int)ms {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "rewindBufferInterval", ms); }
}

- (void)setFastForwardRatio:(double)ratio {
	if (!_core) return;
	if (ratio <= 0) { mCoreConfigSetValue(&_core->config, "fastForwardRatio", "-1"); }
	else { char buf[32]; snprintf(buf, sizeof(buf), "%g", ratio); mCoreConfigSetValue(&_core->config, "fastForwardRatio", buf); }
}

- (void)setFastForwardHeldRatio:(double)ratio {
	if (!_core) return;
	if (ratio <= 0) { mCoreConfigSetValue(&_core->config, "fastForwardHeldRatio", "-1"); }
	else { char buf[32]; snprintf(buf, sizeof(buf), "%g", ratio); mCoreConfigSetValue(&_core->config, "fastForwardHeldRatio", buf); }
}

- (void)setSGBBorders:(BOOL)enabled {
	if (_core) { mCoreConfigSetIntValue(&_core->config, "sgb.borders", enabled); }
}

- (void)setGBPalettePreset:(NSString*)name {
	if (_core) { mCoreConfigSetValue(&_core->config, "gb.pal", [name UTF8String]); }
}

- (NSArray<NSString*>*)listGBPalettePresets {
	NSMutableArray<NSString*>* out = [NSMutableArray array];
	const struct GBColorPreset* presets = NULL;
	size_t n = GBColorPresetList(&presets);
	for (size_t i = 0; i < n; ++i) {
		if (presets[i].name) {
			[out addObject:[NSString stringWithUTF8String:presets[i].name]];
		}
	}
	return out;
}

- (void)attachMultiplayerLockstep:(void*)lockstepNode {
	if (!_core) return;

	switch (_core->platform(_core)) {
#ifdef M_CORE_GBA
	case mPLATFORM_GBA: {
		struct GBA* gba = (struct GBA*)_core->board;
		GBASIOLockstepDriver* driver = (GBASIOLockstepDriver*)lockstepNode;
		gba->sio.driver = &driver->d;
		break;
	}
#endif
#ifdef M_CORE_GB
	case mPLATFORM_GB: {
		struct GB* gb = (struct GB*)_core->board;
		GBSIOLockstepNode* node = (GBSIOLockstepNode*)lockstepNode;
		gb->sio.driver = &node->d;
		break;
	}
#endif
	default:
		break;
	}
}

- (void)detachMultiplayerLockstep {
	if (!_core) return;

	switch (_core->platform(_core)) {
#ifdef M_CORE_GBA
	case mPLATFORM_GBA: {
		struct GBA* gba = (struct GBA*)_core->board;
		gba->sio.driver = NULL;
		break;
	}
#endif
#ifdef M_CORE_GB
	case mPLATFORM_GB: {
		struct GB* gb = (struct GB*)_core->board;
		gb->sio.driver = NULL;
		break;
	}
#endif
	default:
		break;
	}
}

@end



