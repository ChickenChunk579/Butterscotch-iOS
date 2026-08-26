#ifndef _BS_METAL_INTERNAL_H_
#define _BS_METAL_INTERNAL_H_

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <simd/simd.h>

#include "renderer.h"
#include "runner.h"
#include "log.h"
#include "platformdefs.h"
#include "utils.h"
#include "image_decoder.h"
#include "text_utils.h"
#include "matrix_math.h"

#ifdef __cplusplus
extern "C" {
#endif

#define METAL_SURFACE_TEXTURE_FLAG 0x40000000u
#define METAL_MAX_PIPELINE_CACHE 64
#define METAL_MAX_SHADER_SAMPLERS 8
#define METAL_MAX_SHADER_UNIFORMS 64
#define METAL_UNIFORM_BUFFER_FLOATS 256

typedef struct {
    vector_float2 position;
    vector_float2 uv;
    vector_float4 color;
} MetalVertex;

typedef struct {
    matrix_float4x4 wvp;
    vector_float4 fogColor;
    float alphaTestRef;
    int alphaTestEnabled;
    int _pad0;
    int _pad1;
} MetalDefaultUniforms;

typedef enum {
    METAL_UNIFORM_FLOAT = 0,
    METAL_UNIFORM_FLOAT2,
    METAL_UNIFORM_FLOAT3,
    METAL_UNIFORM_FLOAT4,
    METAL_UNIFORM_INT,
    METAL_UNIFORM_INT2,
    METAL_UNIFORM_INT3,
    METAL_UNIFORM_INT4,
    METAL_UNIFORM_MAT2,
    METAL_UNIFORM_MAT3,
    METAL_UNIFORM_MAT4,
    METAL_UNIFORM_SAMPLER,
    METAL_UNIFORM_BOOL,
    METAL_UNIFORM_UNKNOWN
} MetalUniformType;

typedef struct {
    char* name;
    MetalUniformType type;
    int32_t location;     // float-index into uniform float buffer, or sampler slot
    uint32_t samplerSlot;
    uint32_t arraySize;   // 1 for scalars; N for arrays (floats counted in floats)
    uint32_t floatCount;  // number of floats occupied in the uniform buffer
} MetalShaderUniform;

typedef struct {
    bool compiled;
    id<MTLLibrary> library;
    id<MTLFunction> vertexFunction;
    id<MTLFunction> fragmentFunction;
    id<MTLRenderPipelineState> pipeline; // normal blend; other blends via cache

    uint32_t uniformCount;
    MetalShaderUniform* uniforms;
    float* uniformData;
    uint32_t uniformFloatCount;

    MetalShaderUniform* gmBaseTexture;
    MetalShaderUniform* gmMatrices;
    MetalShaderUniform* gmFogColour;
    MetalShaderUniform* gmAlphaTestEnabled;
    MetalShaderUniform* gmAlphaRefValue;

    uint32_t samplerCount;
} MetalGMLShader;

typedef struct {
    int32_t blendMode;
    int32_t sfactor;
    int32_t dfactor;
    int32_t sfactorAlpha;
    int32_t dfactorAlpha;
    bool blendEnabled;
    uint8_t colorWriteMask;
    int32_t shaderIndex; // -1 = default
    MTLPixelFormat pixelFormat;
} MetalPipelineKey;

typedef struct {
    MetalPipelineKey key;
    id<MTLRenderPipelineState> pipeline;
} MetalPipelineCacheEntry;

typedef struct {
    Renderer base;

    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<CAMetalDrawable> drawable;
    id<MTLCommandBuffer> commandBuffer;
    id<MTLCommandBuffer> presentedCommandBuffer;
    id<MTLRenderCommandEncoder> encoder;
    id<MTLTexture> currentTarget;
    id<MTLTexture> encoderTarget; // texture currently bound to encoder (nil if no encoder)

    id<MTLLibrary> defaultLibrary;
    id<MTLFunction> defaultVertexFunction;
    id<MTLFunction> defaultFragmentFunction;
    id<MTLRenderPipelineState> defaultPipeline;
    id<MTLRenderPipelineState> presentPipeline; // BGRA8 drawable letterbox blit

    id<MTLTexture> whiteTexture;
    id<MTLTexture>* textures; // TXTR pages (+ dynamic)
    int32_t* textureWidths;
    int32_t* textureHeights;
    bool* textureLoaded;
    uint32_t textureCount;
    uint32_t originalTexturePageCount;
    uint32_t originalTpagCount;
    uint32_t originalSpriteCount;

    id<MTLTexture>* stagedTextures;
    id<MTLSamplerState> nearestSampler;
    id<MTLSamplerState> nearestRepeatSampler;

    // Surfaces
    id<MTLTexture>* surfaceTextures;
    int32_t* surfaceWidth;
    int32_t* surfaceHeight;
    bool* surfaceAlive;
    uint32_t surfaceCount;
    int32_t currentSurfaceId; // -1 = host drawable (rare); normally app/user surface
    int32_t videoSurfaceId;

    // Frame sizing
    int32_t windowW;
    int32_t windowH;
    int32_t gameW;
    int32_t gameH;

    // GPU state
    bool blendEnabled;
    bool colorWriteR, colorWriteG, colorWriteB, colorWriteA;
    bool alphaTestEnable;
    float alphaTestRef;
    bool fogEnable;
    uint32_t fogColor;
    int32_t currentBlendMode;
    int32_t currentSFactor;
    int32_t currentDFactor;
    int32_t currentSFactorAlpha;
    int32_t currentDFactorAlpha;

    MetalPipelineCacheEntry pipelineCache[METAL_MAX_PIPELINE_CACHE];
    uint32_t pipelineCacheCount;

    MetalGMLShader* gmlShaders;
    uint32_t gmlShaderCount;

    MetalDefaultUniforms defaultUniforms;
} MetalRenderer;

extern MetalRenderer* gActiveMetalRenderer;

// Lifecycle / frame (metal_renderer.m)
void metalEnsureEncoder(MetalRenderer* metal, bool clear, MTLClearColor clearColor);
void metalEndEncoder(MetalRenderer* metal);
void metalBindSurfaceTarget(MetalRenderer* metal, int32_t surfaceId, bool clear, MTLClearColor clearColor);
void metalApplyViewportScissor(MetalRenderer* metal, int32_t x, int32_t y, int32_t w, int32_t h, bool enableScissor);
id<MTLRenderPipelineState> metalGetPipeline(MetalRenderer* metal);
void metalBindDrawState(MetalRenderer* metal);
void metalUploadDefaultUniforms(MetalRenderer* metal);
bool metalEnsureTextureLoaded(MetalRenderer* metal, uint32_t pageId);
bool metalResolveTpag(MetalRenderer* metal, int32_t tpagIndex, TexturePageItem** outTpag, uint32_t* outPageId);
uint32_t metalFindOrAllocTexturePageSlot(MetalRenderer* metal);
uint32_t metalFindOrAllocTpagSlot(DataWin* dw, uint32_t originalTpagCount);
uint32_t metalFindOrAllocateSurfaceSlot(MetalRenderer* metal);
id<MTLTexture> metalCreateRenderTexture(MetalRenderer* metal, int32_t width, int32_t height);
MTLBlendFactor metalBlendFactorToMTL(int factor);
MTLBlendOperation metalBlendModeToEquation(int mode);
void metalFillBlendFactors(MetalRenderer* metal, MTLRenderPipelineColorAttachmentDescriptor* attachment);

// Draw (metal_draw.m)
void metalDrawTexturedVertices(MetalRenderer* metal, const MetalVertex* vertices, uint32_t vertexCount, id<MTLTexture> texture);
void metalDrawQuadRaw(MetalRenderer* metal, id<MTLTexture> texture,
                      float x0, float y0, float x1, float y1, float x2, float y2, float x3, float y3,
                      uint32_t c0, uint32_t c1, uint32_t c2, uint32_t c3, float alpha,
                      float u0, float v0, float u1, float v1);
void metalDrawSolidQuad(MetalRenderer* metal, float x0, float y0, float x1, float y1,
                        float x2, float y2, float x3, float y3, uint32_t color, float alpha);

void metalDrawSprite(Renderer* renderer, int32_t tpagIndex, float x, float y, float originX, float originY,
                     float xscale, float yscale, float angleDeg, uint32_t color, float alpha);
void metalDrawSpritePart(Renderer* renderer, int32_t tpagIndex, int32_t srcOffX, int32_t srcOffY,
                         int32_t srcW, int32_t srcH, float x, float y, float xscale, float yscale,
                         float angleDeg, float pivotX, float pivotY, uint32_t color, float alpha);
void metalDrawSpritePos(Renderer* renderer, int32_t tpagIndex, float x1, float y1, float x2, float y2,
                        float x3, float y3, float x4, float y4, float alpha);
void metalDrawSpriteTiled(Renderer* renderer, int32_t tpagIndex, float originX, float originY,
                          float x, float y, float xscale, float yscale, bool tileX, bool tileY,
                          float roomW, float roomH, uint32_t color, float alpha);
void metalDrawTiledPart(Renderer* renderer, int32_t tpagIndex, int32_t srcX, int32_t srcY,
                        int32_t srcW, int32_t srcH, float dstX, float dstY, float dstW, float dstH,
                        uint32_t color, float alpha);
void metalDrawRectangle(Renderer* renderer, float x1, float y1, float x2, float y2,
                        uint32_t color, float alpha, bool outline);
void metalDrawRectangleColor(Renderer* renderer, float x1, float y1, float x2, float y2,
                             uint32_t color1, uint32_t color2, uint32_t color3, uint32_t color4,
                             float alpha, bool outline);
void metalDrawLine(Renderer* renderer, float x1, float y1, float x2, float y2,
                   float width, uint32_t color, float alpha);
void metalDrawLineColor(Renderer* renderer, float x1, float y1, float x2, float y2,
                        float width, uint32_t color1, uint32_t color2, float alpha);
void metalDrawTriangle(Renderer* renderer, float x1, float y1, float x2, float y2, float x3, float y3,
                       uint32_t color1, uint32_t color2, uint32_t color3, float alpha, bool outline);
void metalDrawText(Renderer* renderer, const char* text, float x, float y, float xscale, float yscale,
                   float angleDeg, float lineSeparation);
void metalDrawTextColor(Renderer* renderer, const char* text, float x, float y, float xscale, float yscale,
                        float angleDeg, int32_t c1, int32_t c2, int32_t c3, int32_t c4, float alpha,
                        float lineSeparation);
void metalClearScreen(Renderer* renderer, uint32_t color, float alpha);

// Surfaces (metal_surfaces.m)
int32_t metalCreateSurface(Renderer* renderer, int32_t width, int32_t height);
bool metalSurfaceExists(Renderer* renderer, int32_t surfaceId);
bool metalSetRenderTarget(Renderer* renderer, int32_t surfaceId, bool implicitApplicationSurface);
int32_t metalEnsureApplicationSurface(Renderer* renderer, int32_t width, int32_t height);
float metalGetSurfaceWidth(Renderer* renderer, int32_t surfaceId);
float metalGetSurfaceHeight(Renderer* renderer, int32_t surfaceId);
void metalDrawSurface(Renderer* renderer, int32_t surfaceID, int32_t srcLeft, int32_t srcTop,
                      int32_t srcWidth, int32_t srcHeight, float x, float y, float xscale, float yscale,
                      float angleDeg, uint32_t color, float alpha);
void metalDrawSurfaceColor(Renderer* renderer, int32_t surfaceID, int32_t srcLeft, int32_t srcTop,
                           int32_t srcWidth, int32_t srcHeight, float x, float y, float xscale, float yscale,
                           float angleDeg, uint32_t color1, uint32_t color2, uint32_t color3, uint32_t color4,
                           float alpha);
void metalDrawSurfaceTiled(Renderer* renderer, int32_t surfaceID, float x, float y, float xscale, float yscale,
                           float roomW, float roomH, uint32_t color, float alpha);
void metalSurfaceResize(Renderer* renderer, int32_t surfaceID, int32_t width, int32_t height);
void metalSurfaceFree(Renderer* renderer, int32_t surfaceID);
void metalSurfaceCopy(Renderer* renderer, int32_t destSurfaceID, int32_t destX, int32_t destY,
                      int32_t srcSurfaceID, int32_t srcX, int32_t srcY, int32_t srcW, int32_t srcH, bool part);
bool metalSurfaceGetPixels(Renderer* renderer, int32_t surfaceID, uint8_t* outRGBA);
int32_t metalCreateSpriteFromSurface(Renderer* renderer, int32_t surfaceID, int32_t x, int32_t y,
                                     int32_t w, int32_t h, bool removeback, bool smooth,
                                     int32_t xorig, int32_t yorig);
void metalDeleteSprite(Renderer* renderer, int32_t spriteIndex);
int32_t metalVideoUploadFrame(Renderer* renderer, int32_t width, int32_t height, const uint8_t* rgba);
uint32_t metalSurfaceGetTexture(Renderer* renderer, int32_t surfaceID);

// State / shaders (metal_state.m + metal_shaders.m)
void metalInitShaders(MetalRenderer* metal, DataWin* dataWin);
void metalDestroyShaders(MetalRenderer* metal);
void metalGpuSetShader(Renderer* renderer, int32_t shaderIndex);
void metalGpuResetShader(Renderer* renderer);
int32_t metalShaderGetUniform(Renderer* renderer, int32_t shaderIndex, char* uniform);
int32_t metalShaderGetSamplerIndex(Renderer* renderer, int32_t shaderIndex, char* uniform);
void metalShaderSetUniformF(Renderer* renderer, int32_t handle, int32_t count,
                            float value1, float value2, float value3, float value4);
void metalShaderSetUniformFArray(Renderer* renderer, int32_t handle, float* values, uint32_t count);
void metalShaderSetUniformI(Renderer* renderer, int32_t handle, int32_t count,
                            int32_t value1, int32_t value2, int32_t value3, int32_t value4);
bool metalShaderIsCompiled(Renderer* renderer, int32_t shader);
bool metalShadersSupported(void);
void metalRefreshShaderBuiltins(MetalRenderer* metal);

BlendFactors metalGpuGetBlendFactors(Renderer* renderer);
int32_t metalGpuGetBlendMode(Renderer* renderer);
void metalGpuSetBlendMode(Renderer* renderer, int32_t mode);
void metalGpuSetBlendModeExt(Renderer* renderer, int32_t sfactor, int32_t dfactor,
                             int32_t sfactor_alpha, int32_t dfactor_alpha);
void metalGpuSetBlendEnable(Renderer* renderer, bool enable);
bool metalGpuGetBlendEnable(Renderer* renderer);
void metalGpuSetAlphaTestEnable(Renderer* renderer, bool enable);
void metalGpuSetAlphaTestRef(Renderer* renderer, uint8_t ref);
void metalGpuSetColorWriteEnable(Renderer* renderer, bool red, bool green, bool blue, bool alpha);
void metalGpuGetColorWriteEnable(Renderer* renderer, bool* red, bool* green, bool* blue, bool* alpha);
void metalGpuSetFog(Renderer* renderer, bool enable, uint32_t color);
void metalSetMatrix(Renderer* renderer, int32_t matrixType, Matrix4f matrix);
void metalApplyProjection(Renderer* renderer, const Matrix4f* viewMatrix, const Matrix4f* projectionMatrix);

uint32_t metalSpriteGetTexture(Renderer* renderer, int32_t tpagIndex);
float metalTextureGetTexelWidth(Renderer* renderer, uint32_t texHandle);
float metalTextureGetTexelHeight(Renderer* renderer, uint32_t texHandle);
bool metalTextureGetUVs(Renderer* renderer, uint32_t texHandle, float* outUVs);
void metalTextureSetStage(Renderer* renderer, int32_t slot, uint32_t texHandle);
bool metalResolveTextureHandle(MetalRenderer* metal, uint32_t texHandle, TexturePageItem** outTpag,
                               id<MTLTexture>* outTex, int32_t* outW, int32_t* outH);

char* metalTranspileGMEStoMSL(const char* glslVertex, const char* glslFragment,
                              const char** vertexAttributes, uint32_t vertexAttributeCount,
                              MetalGMLShader* outMeta);

void metalSetGuiProjection(Renderer* renderer, int32_t guiW, int32_t guiH,
                           int32_t portW, int32_t portH, bool renderingToUserSurface);

#ifdef __cplusplus
}
#endif

#endif /* _BS_METAL_INTERNAL_H_ */
