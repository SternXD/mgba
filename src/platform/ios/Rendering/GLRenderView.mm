// GLRenderView.mm
// mGBA
//
// Created by SternXD on 9/12/25.
//

#import "GLRenderView.h"
#import "../Bridge/MGBCoreBridge.h"
#import <mgba/core/thread.h>
#import <mgba/core/sync.h>
#include <string.h>

@interface GLRenderView () {
    EAGLContext* _context;
    GLuint _framebuffer;
    GLuint _renderbuffer;
    CADisplayLink* _displayLink;
    GLint _backingWidth;
    GLint _backingHeight;
    GLint _vpX;
    GLint _vpY;
    GLint _vpW;
    GLint _vpH;
    GLuint _tex;
    GLuint _program;
    GLint _posLoc;
    GLint _uvLoc;
    GLint _samplerLoc;
    GLuint _vbo;
    GLint _texWidth;
    GLint _texHeight;
    void* _staging;
    size_t _stagingSize;
    __weak MGBCoreBridge* _bridge;
    BOOL _integerScaling;
}
@end

@implementation GLRenderView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [self stopDisplay];
    [self teardownBuffers];
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    if (_staging) {
        free(_staging);
        _staging = NULL;
        _stagingSize = 0;
    }
    if (_tex) {
        glDeleteTextures(1, &_tex);
        _tex = 0;
    }
}

- (void)commonInit {
    CAEAGLLayer* layer = (CAEAGLLayer*) self.layer;
    layer.opaque = YES;
    layer.drawableProperties = @{ (NSString*)kEAGLDrawablePropertyRetainedBacking: @NO,
                                  (NSString*)kEAGLDrawablePropertyColorFormat: (NSString*)kEAGLColorFormatRGBA8 };

    self.contentScaleFactor = UIScreen.mainScreen.scale;

    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_context];
    [self setupBuffers];
    glGenTextures(1, &_tex);
    glBindTexture(GL_TEXTURE_2D, _tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // NPOT textures on ES2 require clamp to edge default repeat can make the texture incomplete and sample black
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    _texWidth = 0;
    _texHeight = 0;
    _staging = NULL;
    _stagingSize = 0;
    _vpX = _vpY = 0;
    _vpW = _vpH = 0;
    _integerScaling = NO;

    // Compile minimal ES2 program
    const GLchar* vsrc =
        "attribute vec2 position;\n"
        "attribute vec2 uv;\n"
        "varying vec2 vUV;\n"
        "void main(){\n"
        "  gl_Position = vec4(position, 0.0, 1.0);\n"
        "  vUV = uv;\n"
        "}";
    const GLchar* fsrc =
        "precision mediump float;\n"
        "varying vec2 vUV;\n"
        "uniform sampler2D tex;\n"
        "void main(){\n"
        "  gl_FragColor = texture2D(tex, vUV);\n"
        "}";

    auto compile = ^GLuint(GLenum type, const GLchar* src) {
        GLuint s = glCreateShader(type);
        glShaderSource(s, 1, &src, NULL);
        glCompileShader(s);
        GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
        if (!ok) { glDeleteShader(s); return (GLuint)0; }
        return s;
    };
    GLuint vs = compile(GL_VERTEX_SHADER, vsrc);
    GLuint fs = compile(GL_FRAGMENT_SHADER, fsrc);
    _program = glCreateProgram();
    glAttachShader(_program, vs);
    glAttachShader(_program, fs);
    glBindAttribLocation(_program, 0, "position");
    glBindAttribLocation(_program, 1, "uv");
    glLinkProgram(_program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    _posLoc = 0;
    _uvLoc = 1;
    _samplerLoc = glGetUniformLocation(_program, "tex");

    const GLfloat quad[] = {
        //  x,   y,   u,  v
        -1.f, -1.f, 0.f, 1.f,
        -1.f,  1.f, 0.f, 0.f,
         1.f,  1.f, 1.f, 0.f,
         1.f, -1.f, 1.f, 1.f,
    };
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [EAGLContext setCurrentContext:_context];
    [self teardownBuffers];
    [self setupBuffers];
    [self recalcViewport];
    [self displayFrame];
}

- (void)setupBuffers {
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);

    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"GLRenderView: Framebuffer incomplete (status: 0x%x)", status);
        // Clean up and retry
        [self teardownBuffers];
        return;
    }

}

- (void)teardownBuffers {
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
}

- (void)startDisplay {
    if (_displayLink) {
        return;
    }
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    if (@available(iOS 15.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 60, 60);
    } else {
        _displayLink.preferredFramesPerSecond = 60;
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDisplay {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)displayLinkFired:(CADisplayLink*)link {
    (void) link;
    // Just draw at display refresh core runs on its own thread and pushes frames
    [self displayFrame];
}

- (void)displayFrame {
    [EAGLContext setCurrentContext:_context];
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(_vpX, _vpY, _vpW ? _vpW : _backingWidth, _vpH ? _vpH : _backingHeight);
    glClearColor(0.f, 0.f, 0.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(_program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _tex);
    glUniform1i(_samplerLoc, 0);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glEnableVertexAttribArray(_posLoc);
    glVertexAttribPointer(_posLoc, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 4, (const GLvoid*)0);
    glEnableVertexAttribArray(_uvLoc);
    glVertexAttribPointer(_uvLoc, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 4, (const GLvoid*)(sizeof(GLfloat) * 2));
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDisableVertexAttribArray(_uvLoc);
    glDisableVertexAttribArray(_posLoc);
    glUseProgram(0);

    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)updateFrameWithPixels:(const void*)pixels width:(int)width height:(int)height stride:(size_t)stride {
    [EAGLContext setCurrentContext:_context];
    glBindTexture(GL_TEXTURE_2D, _tex);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    if (_texWidth != width || _texHeight != height) {
        _texWidth = width;
        _texHeight = height;
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        [self recalcViewport];
    }

    const size_t bytesPerPixel = 4;
    const size_t srcStrideBytes = stride * bytesPerPixel;
    const size_t tightStrideBytes = (size_t)width * bytesPerPixel;

    if (stride == (size_t)width) {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    } else {
        const size_t needed = tightStrideBytes * (size_t)height;
        if (_stagingSize < needed) {
            void* newBuf = realloc(_staging, needed);
            if (!newBuf) { return; }
            _staging = newBuf;
            _stagingSize = needed;
        }
        const uint8_t* src = (const uint8_t*) pixels;
        uint8_t* dst = (uint8_t*) _staging;
        for (int y = 0; y < height; ++y) {
            memcpy(dst + (size_t)y * tightStrideBytes, src + (size_t)y * srcStrideBytes, tightStrideBytes);
        }
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, _staging);
    }
}

- (void)recalcViewport {
    if (_backingWidth <= 0 || _backingHeight <= 0 || _texWidth <= 0 || _texHeight <= 0) {
        _vpX = _vpY = 0;
        _vpW = _backingWidth;
        _vpH = _backingHeight;
        return;
    }
    const float viewAspect = (float) _backingWidth / (float) _backingHeight;
    const float texAspect = (float) _texWidth / (float) _texHeight;
    GLint targetW, targetH;
    if (viewAspect > texAspect) {
        targetH = _backingHeight;
        targetW = (GLint) (_backingHeight * texAspect + 0.5f);
    } else {
        targetW = _backingWidth;
        targetH = (GLint) (_backingWidth / texAspect + 0.5f);
    }
    if (_integerScaling) {
        GLint scale = (GLint) floorf((float) targetH / (float) _texHeight);
        if (scale < 1) { scale = 1; }
        targetH = _texHeight * scale;
        targetW = _texWidth * scale;
    }
    _vpW = targetW;
    _vpH = targetH;
    _vpX = (_backingWidth - _vpW) / 2;
    _vpY = (_backingHeight - _vpH) / 2;
}

- (void)attachBridge:(MGBCoreBridge*)bridge {
    _bridge = bridge;
}

- (void)setIntegerScalingEnabled:(BOOL)enabled {
    _integerScaling = enabled;
    [self recalcViewport];
}

@end


