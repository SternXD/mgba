// MGBAAudio.mm
// mGBA
//
// Created by SternXD on 9/12/25.
//
#import "MGBAAudio.h"

#import <AVFoundation/AVFoundation.h>

extern "C" {
	#include <mgba/core/core.h>
	#include <mgba/core/thread.h>
	#include <mgba/core/sync.h>
	#include <mgba-util/audio-buffer.h>
	#include <mgba-util/audio-resampler.h>
}

@implementation MGBAAudio {
	AVAudioEngine* _engine;
	AVAudioFormat* _format;
	AVAudioSourceNode* _source;
	struct mCoreThread* _thread;
	struct mCore* _core;
	struct mAudioBuffer _buffer;
	struct mAudioResampler _resampler;
	BOOL _started;
	UInt32 _channels;
	UInt32 _bufferSamples;
}

- (instancetype)initWithCoreThread:(struct mCoreThread*)thread {
	self = [super init];
	if (self) {
		_thread = thread;
		_core = thread ? thread->core : NULL;
		_engine = [AVAudioEngine new];
		_format = nil;
		_source = nil;
		_started = NO;
		_channels = 2;
		_bufferSamples = 4096;
		mAudioBufferInit(&_buffer, 0x8000, _channels);
		mAudioResamplerInit(&_resampler, mINTERPOLATOR_SINC);
	}
	return self;
}

- (void)dealloc {
	[self stop];
	mAudioResamplerDeinit(&_resampler);
	mAudioBufferDeinit(&_buffer);
}

- (void)start {
	if (_started) { return; }
	AVAudioSession* session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
	[session setActive:YES error:nil];

	AVAudioOutputNode* out = _engine.outputNode;
	// Prefer mixer format (deinterleaved float)
	_format = [_engine.mainMixerNode outputFormatForBus:0];
	if (!_format || _format.channelCount == 0) {
		_format = [out outputFormatForBus:0];
	}
	_channels = (UInt32)_format.channelCount;
	if (_channels == 0) { _channels = 2; }

	mAudioResamplerSetDestination(&_resampler, &_buffer, (unsigned)_format.sampleRate);

	__unsafe_unretained MGBAAudio* selfRef = self;
	_source = [[AVAudioSourceNode alloc] initWithRenderBlock:^OSStatus(BOOL * _Nonnull isSilence,
			const AudioTimeStamp * _Nonnull timestamp,
			AVAudioFrameCount frameCount,
			AudioBufferList * _Nonnull outputData) {
			if (isSilence) { *isSilence = NO; }
			return [selfRef renderInto:outputData frames:frameCount];
		}];
	[_engine attachNode:_source];
	[_engine connect:_source to:_engine.mainMixerNode format:_format];
	[_engine connect:_engine.mainMixerNode to:out format:nil];

	[_engine prepare];
	NSError* err = nil;
	if (![_engine startAndReturnError:&err]) {
		return;
	}
	_started = YES;
}

- (void)stop {
	if (!_started) { return; }
	[_engine stop];
	_started = NO;
}

static inline void ZeroFill(AudioBufferList* abl) {
	if (!abl) return;
	for (UInt32 b = 0; b < abl->mNumberBuffers; ++b) {
		if (abl->mBuffers[b].mData && abl->mBuffers[b].mDataByteSize) {
			memset(abl->mBuffers[b].mData, 0, abl->mBuffers[b].mDataByteSize);
		}
	}
}

static inline bool ThreadSyncReady(struct mCoreThread* t) { return t && t->impl; }

- (OSStatus)renderInto:(AudioBufferList*)abl frames:(AVAudioFrameCount)frames {
	if (!_core || !abl || abl->mNumberBuffers == 0) { ZeroFill(abl); return noErr; }
	if (!_core->getAudioBuffer || !_core->audioSampleRate) { ZeroFill(abl); return noErr; }
	const UInt32 ch = _channels ? _channels : 2;

	AVAudioFrameCount framesWritable = frames;
	if (abl->mNumberBuffers == 1) {
		UInt32 bytes = abl->mBuffers[0].mDataByteSize;
		UInt32 perBufFrames = (bytes / sizeof(float)) / (ch ? ch : 1);
		if (perBufFrames < framesWritable) { framesWritable = perBufFrames; }
	} else {
		for (UInt32 b = 0; b < abl->mNumberBuffers; ++b) {
			UInt32 perBufFrames = abl->mBuffers[b].mDataByteSize / sizeof(float);
			if (perBufFrames < framesWritable) { framesWritable = perBufFrames; }
		}
	}
	if (framesWritable == 0) { ZeroFill(abl); return noErr; }

	struct mAudioBuffer* source = _core->getAudioBuffer(_core);
	unsigned srcRate = _core->audioSampleRate(_core);
	if (!source || srcRate == 0) { ZeroFill(abl); return noErr; }

	double fauxClock = 1.0;
	struct mCoreSync* syncPtr = NULL;
	if (ThreadSyncReady(_thread)) {
		syncPtr = &_thread->impl->sync;
		if (syncPtr->fpsTarget > 0) {
			fauxClock = mCoreCalculateFramerateRatio(_core, syncPtr->fpsTarget);
		}
		mCoreSyncLockAudio(syncPtr);
		syncPtr->audioHighWater = _bufferSamples + _resampler.highWaterMark + _resampler.lowWaterMark + (_bufferSamples >> 6);
		syncPtr->audioHighWater *= (srcRate / (fauxClock * _format.sampleRate));
	}
	mAudioResamplerSetSource(&_resampler, source, (unsigned)(srcRate / fauxClock), true);
	mAudioResamplerProcess(&_resampler);
	if (syncPtr) {
		mCoreSyncConsumeAudio(syncPtr);
	}

	const size_t requested = (size_t)framesWritable * ch;
	static const size_t kTmpMax = 8192;
	int16_t tmpStack[kTmpMax];
	int16_t* tmp = tmpStack;
	int16_t* tmpHeap = NULL;
	if (requested > kTmpMax) {
		tmpHeap = (int16_t*) malloc(requested * sizeof(int16_t));
		tmp = tmpHeap ? tmpHeap : tmpStack;
	}
	memset(tmp, 0, requested * sizeof(int16_t));
	int available = mAudioBufferRead(&_buffer, tmp, (int)(requested > (size_t)INT_MAX ? INT_MAX : (int)requested));
	if (available < 0) available = 0;
	const float scale = 1.0f / 32768.0f;

	if (abl->mNumberBuffers == 1) {
		float* out = (float*) abl->mBuffers[0].mData;
		if (out) {
			const size_t outSamples = (size_t)framesWritable * ch;
			const size_t n = (size_t)available < outSamples ? (size_t)available : outSamples;
			for (size_t i = 0; i < n; ++i) { out[i] = (float) tmp[i] * scale; }
			if (n < outSamples) { memset(out + n, 0, (outSamples - n) * sizeof(float)); }
		}
	} else {
		for (UInt32 b = 0; b < abl->mNumberBuffers && b < ch; ++b) {
			float* outCh = (float*) abl->mBuffers[b].mData;
			if (!outCh) { continue; }
			UInt32 toWrite = framesWritable;
			for (UInt32 f = 0; f < toWrite; ++f) {
				size_t idx = (size_t)f * ch + b;
				outCh[f] = (idx < (size_t)available) ? ((float) tmp[idx] * scale) : 0.f;
			}
		}
	}
	if (tmpHeap) { free(tmpHeap); }
	return noErr;
}

@end

