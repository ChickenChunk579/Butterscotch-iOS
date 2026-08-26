#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <simd/simd.h>

#include "metal_renderer.h"
#include "log.h"
#include "platformdefs.h"
#include "utils.h"
#include "image_decoder.h"
#include "text_utils.h"

typedef struct {
    vector_float2 position;
    vector_float2 uv;
    vector_float4 color;
} MetalVertex;

typedef struct {
    Renderer base;
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<CAMetalDrawable> drawable;
    id<MTLCommandBuffer> commandBuffer;
    id<MTLCommandBuffer> presentedCommandBuffer;
    id<MTLRenderCommandEncoder> encoder;
    id<MTLRenderPipelineState> pipeline;
    id<MTLTexture> whiteTexture;
    id<MTLTexture> videoTexture;
    int32_t videoWidth;
    int32_t videoHeight;
    id<MTLTexture> stagedTextures[MAX_TEXTURE_STAGES];
    __strong id<MTLTexture>* textures;
    int32_t* textureWidths;
    int32_t* textureHeights;
    bool* textureLoaded;
    uint32_t textureCount;
    int32_t windowW;
    int32_t windowH;
    bool blendEnabled;
    bool colorWriteR;
    bool colorWriteG;
    bool colorWriteB;
    bool colorWriteA;
} MetalRenderer;

static MetalRenderer* activeMetalRenderer;
static bool metalTextDiagnosticLogged;
static bool metalGlyphDiagnosticLogged;
static bool metalVisibleTextDiagnosticLogged;

static const char* metalShaderSource =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "struct Vertex { float2 position; float2 uv; float4 color; };\n"
    "struct VSOut { float4 position [[position]]; float2 uv; float4 color; };\n"
    "vertex VSOut bs_vertex(const device Vertex* vertices [[buffer(0)]], uint id [[vertex_id]]) {\n"
    "    VSOut out; out.position = float4(vertices[id].position, 0.0, 1.0);\n"
    "    out.uv = vertices[id].uv; out.color = vertices[id].color; return out;\n"
    "}\n"
    "fragment float4 bs_fragment(VSOut in [[stage_in]], texture2d<float> texture [[texture(0)]]) {\n"
    "    constexpr sampler sampler2d(filter::nearest, address::clamp_to_edge);\n"
    "    return texture.sample(sampler2d, in.uv) * in.color;\n"
    "}\n";

static bool metalEnsureTextureLoaded(MetalRenderer* metal, uint32_t pageId) {
    if (pageId >= metal->textureCount) return false;
    if (metal->textureLoaded[pageId]) return metal->textures[pageId] != nil;

    metal->textureLoaded[pageId] = true;
    DataWin* dataWin = metal->base.dataWin;
    Texture* texture = &dataWin->txtr.textures[pageId];
    DataWin_loadTxtrIfNeeded(dataWin, pageId);

    int width = 0;
    int height = 0;
    bool gm2022_5 = DataWin_isVersionAtLeast(dataWin, 2022, 5, 0, 0);
    uint8_t* pixels = ImageDecoder_decodeToRgba(texture->blobData, (size_t)texture->blobSize,
                                                gm2022_5, &width, &height);
    if (pixels == nullptr) {
        logWarn("Metal: failed to decode TXTR page %u\n", pageId);
        return false;
    }
    if (!texture->mapped) {
        free(texture->blobData);
        texture->blobData = nullptr;
    }

    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                             width:(NSUInteger)width
                                                                                            height:(NSUInteger)height
                                                                                         mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> gpuTexture = [metal->device newTextureWithDescriptor:descriptor];
    [gpuTexture replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)width, (NSUInteger)height)
                   mipmapLevel:0
                     withBytes:pixels
                   bytesPerRow:(NSUInteger)width * 4];
    free(pixels);

    metal->textures[pageId] = gpuTexture;
    metal->textureWidths[pageId] = width;
    metal->textureHeights[pageId] = height;
    logInfo("Metal: loaded TXTR page %u (%dx%d)\n", pageId, width, height);
    return true;
}

static void metalInit(Renderer* renderer, DataWin* dataWin) {
    MetalRenderer* metal = (MetalRenderer*) renderer;
    CAMetalLayer* layer = (__bridge CAMetalLayer*) platformGetMetalLayer();

    renderer->dataWin = dataWin;
    Matrix4f world;
    Matrix4f_identity(&world);
    renderer->gmlMatrices[MATRIX_WORLD] = world;
    metal->device = MTLCreateSystemDefaultDevice();
    if (metal->device == nil || layer == nil) {
        logError("Metal: no default device or CAMetalLayer is available\n");
        return;
    }

    layer.device = metal->device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.magnificationFilter = kCAFilterNearest;
    layer.minificationFilter = kCAFilterNearest;
    metal->commandQueue = [metal->device newCommandQueue];
    NSError* error = nil;
    id<MTLLibrary> library = [metal->device newLibraryWithSource:[NSString stringWithUTF8String:metalShaderSource]
                                                           options:nil
                                                             error:&error];
    if (library == nil) {
        logError("Metal: shader library creation failed: %s\n", error.localizedDescription.UTF8String);
        return;
    }
    MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"bs_vertex"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"bs_fragment"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;
    pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    metal->pipeline = [metal->device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (metal->pipeline == nil) {
        logError("Metal: pipeline creation failed: %s\n", error.localizedDescription.UTF8String);
        return;
    }
    MTLTextureDescriptor* whiteDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                  width:1 height:1 mipmapped:NO];
    metal->whiteTexture = [metal->device newTextureWithDescriptor:whiteDescriptor];
    uint32_t whitePixel = 0xFFFFFFFF;
    [metal->whiteTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
                              withBytes:&whitePixel bytesPerRow:sizeof(whitePixel)];
    metal->textureCount = dataWin->txtr.count;
    metal->textures = (__strong id<MTLTexture>*)safeCalloc(metal->textureCount, sizeof(id<MTLTexture>));
    metal->textureWidths = (int32_t*)safeCalloc(metal->textureCount, sizeof(int32_t));
    metal->textureHeights = (int32_t*)safeCalloc(metal->textureCount, sizeof(int32_t));
    metal->textureLoaded = (bool*)safeCalloc(metal->textureCount, sizeof(bool));
    metal->blendEnabled = true;
    metal->colorWriteR = true;
    metal->colorWriteG = true;
    metal->colorWriteB = true;
    metal->colorWriteA = true;

    logInfo("Metal: initialized device %s\n", metal->device.name.UTF8String);
}

static void metalDestroy(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*) renderer;
    [metal->encoder endEncoding];
    metal->encoder = nil;
    metal->commandBuffer = nil;
    metal->drawable = nil;
    metal->commandQueue = nil;
    metal->device = nil;
    free(metal->textures);
    free(metal->textureWidths);
    free(metal->textureHeights);
    free(metal->textureLoaded);
    if (activeMetalRenderer == metal) activeMetalRenderer = nil;
    free(metal);
}

static void metalBeginFrame(Renderer* renderer, int32_t gameW, int32_t gameH,
                            int32_t windowW, int32_t windowH) {
    MetalRenderer* metal = (MetalRenderer*) renderer;
    CAMetalLayer* layer = (__bridge CAMetalLayer*) platformGetMetalLayer();
    metal->windowW = windowW;
    metal->windowH = windowH;

    if (layer == nil || metal->commandQueue == nil) return;
    layer.drawableSize = CGSizeMake(windowW, windowH);
    metal->drawable = [layer nextDrawable];
    metal->commandBuffer = [metal->commandQueue commandBuffer];
    if (metal->drawable == nil || metal->commandBuffer == nil) {
        logDebug("Metal: drawable acquisition skipped for frame\n");
        return;
    }

    MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = metal->drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    metal->encoder = [metal->commandBuffer renderCommandEncoderWithDescriptor:pass];
    int32_t viewportW = windowW;
    int32_t viewportH = windowH;
    int32_t viewportX = 0;
    int32_t viewportY = 0;
    if (gameW > 0 && gameH > 0 && windowW > 0 && windowH > 0) {
        if ((int64_t)windowW * gameH > (int64_t)windowH * gameW) {
            viewportW = (int32_t)((int64_t)windowH * gameW / gameH);
            viewportX = (windowW - viewportW) / 2;
        } else {
            viewportH = (int32_t)((int64_t)windowW * gameH / gameW);
            viewportY = (windowH - viewportH) / 2;
        }
    }
    [metal->encoder setViewport:(MTLViewport){(double)viewportX, (double)viewportY,
                                               (double)viewportW, (double)viewportH, 0.0, 1.0}];
    (void)gameW;
    (void)gameH;
}

static void metalEndFrameInit(MAYBE_UNUSED Renderer* renderer) {}

static void metalEndFrameEnd(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*) renderer;
    if (metal->encoder == nil || metal->commandBuffer == nil || metal->drawable == nil) return;
    [metal->encoder endEncoding];
    metal->encoder = nil;
}

static void metalNoopView(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c,
                          int32_t d, int32_t e, int32_t f, int32_t g, int32_t h, float i) {
    (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i;
}
static void metalNoopRenderer(MAYBE_UNUSED Renderer* renderer) {}
static void metalApplyProjection(Renderer* renderer, const Matrix4f* viewMatrix, const Matrix4f* projectionMatrix) {
    Matrix4f world = renderer->gmlMatrices[MATRIX_WORLD];
    Matrix4f worldView;
    Matrix4f worldViewProjection;
    Matrix4f_multiply(&worldView, viewMatrix, &world);
    Matrix4f_multiply(&worldViewProjection, projectionMatrix, &worldView);
    renderer->gmlMatrices[MATRIX_VIEW] = *viewMatrix;
    renderer->gmlMatrices[MATRIX_PROJECTION] = *projectionMatrix;
    renderer->gmlMatrices[MATRIX_WORLD_VIEW] = worldView;
    renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION] = worldViewProjection;
}
static void metalBeginView(Renderer* renderer, MAYBE_UNUSED int32_t viewX, MAYBE_UNUSED int32_t viewY,
                           MAYBE_UNUSED int32_t viewW, MAYBE_UNUSED int32_t viewH, int32_t portX,
                           int32_t portY, int32_t portW, int32_t portH, MAYBE_UNUSED float viewAngle) {
    renderer->CPortX = portX;
    renderer->CPortY = portY;
    renderer->CPortW = portW;
    renderer->CPortH = portH;
    int32_t viewCurrent = renderer->runner->viewsEnabled ? renderer->runner->viewCurrent : 0;
    RuntimeView* view = &renderer->runner->views[viewCurrent];
    renderer->cameraCurrent = view->cameraId;
    GMLCamera* camera = Runner_getCameraById(renderer->runner, renderer->cameraCurrent);
    metalApplyProjection(renderer, &camera->viewMatrix, &camera->projectionMatrix);
}
static void metalSetGuiProjection(Renderer* renderer, int32_t guiW, int32_t guiH,
                                  MAYBE_UNUSED int32_t portW, MAYBE_UNUSED int32_t portH,
                                  bool renderingToUserSurface) {
    renderer->cameraCurrent = GUI_CAMERA;
    GMLCamera* camera = &renderer->runner->guiCamera;
    camera->allocated = true;
    camera->viewX = 0.0;
    camera->viewY = 0.0;
    camera->viewWidth = guiW;
    camera->viewHeight = guiH;
    camera->borderX = 0;
    camera->borderY = 0;
    camera->speedX = 0;
    camera->speedY = 0;
    camera->objectId = -1;
    camera->viewAngle = 0;

    Matrix4f projection;
    Matrix4f_Orthographic(&projection, (float)guiW, (float)guiH, 32000.0, 0.0);
    if (renderingToUserSurface) Matrix4f_flipClipY(&projection);
    Matrix4f view;
    Matrix4f_identity(&view);
    Matrix4f_LookAt(&view, (float)guiW * 0.5f, (float)guiH * 0.5f, -16000.0,
                   (float)guiW * 0.5f, (float)guiH * 0.5f, 16000.0,
                   0.0, 1.0, 0.0);
    camera->viewMatrix = view;
    camera->projectionMatrix = projection;
    metalApplyProjection(renderer, &view, &projection);
}
static void metalBeginGUI(Renderer* renderer, int32_t guiW, int32_t guiH,
                          MAYBE_UNUSED int32_t portX, MAYBE_UNUSED int32_t portY,
                          MAYBE_UNUSED int32_t portW, MAYBE_UNUSED int32_t portH,
                          MAYBE_UNUSED int32_t targetSurfaceId) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (metal->encoder == nil && metal->commandBuffer != nil && metal->drawable != nil) {
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = metal->drawable.texture;
        pass.colorAttachments[0].loadAction = MTLLoadActionLoad;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        metal->encoder = [metal->commandBuffer renderCommandEncoderWithDescriptor:pass];
    }
    metalSetGuiProjection(renderer, guiW, guiH, portW, portH, false);
}
static void metalEndGUI(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (metal->encoder != nil) {
        [metal->encoder endEncoding];
        metal->encoder = nil;
    }
}
static void metalNoopDraw(MAYBE_UNUSED Renderer* renderer, const char* a, float b, float c, float d, float e, float f, float g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
static void metalNoopDrawColor(MAYBE_UNUSED Renderer* renderer, const char* a, float b, float c, float d, float e, float f, int32_t g, int32_t h, int32_t i, int32_t j, float k, float l) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l; }
static void metalClearScreen(MAYBE_UNUSED Renderer* renderer, uint32_t color, float alpha) { (void)color; (void)alpha; }
static void metalNoopSprite(MAYBE_UNUSED Renderer* renderer, int32_t a, float b, float c, float d, float e, float f, float g, float h, uint32_t i, float j) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; }
static void metalNoopSpritePart(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, float f, float g, float h, float i, float j, float k, float l, uint32_t m, float n) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l; (void)m; (void)n; }
static void metalDrawQuad(MetalRenderer* metal, TexturePageItem* tpag, uint32_t pageId,
                          float x0, float y0, float x1, float y1, float x2, float y2,
                          float x3, float y3, uint32_t color, float alpha,
                          float u0, float v0, float u1, float v1) {
    if (metal->encoder == nil || metal->pipeline == nil || !metalEnsureTextureLoaded(metal, pageId)) return;
    Matrix4f* matrix = &metal->base.gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    float positions[8] = {x0, y0, x1, y1, x2, y2, x3, y3};
    MetalVertex vertices[6];
    uint32_t bgr = color;
    vector_float4 vertexColor = {BGR_R(bgr) / 255.0f, BGR_G(bgr) / 255.0f, BGR_B(bgr) / 255.0f, alpha};
    const float uvs[8] = {u0, v0, u1, v0, u1, v1, u0, v1};
    const int indices[6] = {0, 1, 2, 2, 3, 0};
    for (int i = 0; i < 6; i++) {
        int source = indices[i];
        float clipX, clipY;
        Matrix4f_transformPoint(matrix, positions[source * 2], positions[source * 2 + 1], &clipX, &clipY);
        vertices[i].position = (vector_float2){clipX, clipY};
        vertices[i].uv = (vector_float2){uvs[source * 2], uvs[source * 2 + 1]};
        vertices[i].color = vertexColor;
    }
    [metal->encoder setRenderPipelineState:metal->pipeline];
    [metal->encoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    id<MTLTexture> drawTexture = metal->textures[pageId];
    if (metal->base.currentShader != -1 && metal->stagedTextures[0] != nil)
        drawTexture = metal->stagedTextures[0];
    [metal->encoder setFragmentTexture:drawTexture atIndex:0];
    [metal->encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    (void)tpag;
}

static bool metalResolveTpag(MetalRenderer* metal, int32_t tpagIndex, TexturePageItem** outTpag, uint32_t* outPageId) {
    DataWin* dataWin = metal->base.dataWin;
    if (tpagIndex < 0 || (uint32_t)tpagIndex >= dataWin->tpag.count) return false;
    TexturePageItem* tpag = &dataWin->tpag.items[tpagIndex];
    if (tpag->texturePageId < 0 || (uint32_t)tpag->texturePageId >= metal->textureCount) return false;
    *outTpag = tpag;
    *outPageId = (uint32_t)tpag->texturePageId;
    return true;
}

static void metalDrawSprite(Renderer* renderer, int32_t tpagIndex, float x, float y, float originX,
                            float originY, float xscale, float yscale, float angleDeg,
                            uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId)) return;
    float localX0 = (float)tpag->targetX - originX;
    float localY0 = (float)tpag->targetY - originY;
    float localX1 = localX0 + (float)tpag->targetWidth;
    float localY1 = localY0 + (float)tpag->targetHeight;
    float angle = -angleDeg * ((float)M_PI / 180.0f);
    Matrix4f transform;
    Matrix4f_setTransform2D(&transform, x, y, xscale, yscale, angle);
    float x0, y0, x1, y1, x2, y2, x3, y3;
    Matrix4f_transformPoint(&transform, localX0, localY0, &x0, &y0);
    Matrix4f_transformPoint(&transform, localX1, localY0, &x1, &y1);
    Matrix4f_transformPoint(&transform, localX1, localY1, &x2, &y2);
    Matrix4f_transformPoint(&transform, localX0, localY1, &x3, &y3);
    float invW = 1.0f / (float)metal->textureWidths[pageId];
    float invH = 1.0f / (float)metal->textureHeights[pageId];
    metalDrawQuad(metal, tpag, pageId, x0, y0, x1, y1, x2, y2, x3, y3, color, alpha,
                  tpag->sourceX * invW, tpag->sourceY * invH,
                  (tpag->sourceX + tpag->sourceWidth) * invW,
                  (tpag->sourceY + tpag->sourceHeight) * invH);
}

static void metalDrawSpritePart(Renderer* renderer, int32_t tpagIndex, int32_t srcOffX,
                                int32_t srcOffY, int32_t srcW, int32_t srcH, float x, float y,
                                float xscale, float yscale, float angleDeg,
                                float pivotX, float pivotY, uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId)) return;
    float angle = -angleDeg * ((float)M_PI / 180.0f);
    float cosA = cosf(angle), sinA = sinf(angle);
    float px[4] = {x, x + srcW * xscale, x + srcW * xscale, x};
    float py[4] = {y, y, y + srcH * yscale, y + srcH * yscale};
    for (int i = 0; i < 4; i++) {
        float dx = px[i] - pivotX, dy = py[i] - pivotY;
        px[i] = cosA * dx - sinA * dy + pivotX;
        py[i] = sinA * dx + cosA * dy + pivotY;
    }
    float invW = 1.0f / (float)metal->textureWidths[pageId];
    float invH = 1.0f / (float)metal->textureHeights[pageId];
    float u0 = (tpag->sourceX + srcOffX + 0.5f) * invW;
    float v0 = (tpag->sourceY + srcOffY + 0.5f) * invH;
    float u1 = (tpag->sourceX + srcOffX + srcW - 0.5f) * invW;
    float v1 = (tpag->sourceY + srcOffY + srcH - 0.5f) * invH;
    metalDrawQuad(metal, tpag, pageId, px[0], py[0], px[1], py[1], px[2], py[2], px[3], py[3], color, alpha,
                  u0, v0, u1, v1);
}

static void metalDrawSolidQuad(MetalRenderer* metal, float x0, float y0, float x1, float y1,
                               float x2, float y2, float x3, float y3, uint32_t color, float alpha) {
    if (metal->encoder == nil || metal->pipeline == nil || metal->whiteTexture == nil) return;
    Matrix4f* matrix = &metal->base.gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    float positions[8] = {x0, y0, x1, y1, x2, y2, x3, y3};
    const int indices[6] = {0, 1, 2, 2, 3, 0};
    MetalVertex vertices[6];
    vector_float4 vertexColor = {BGR_R(color) / 255.0f, BGR_G(color) / 255.0f, BGR_B(color) / 255.0f, alpha};
    for (int i = 0; i < 6; i++) {
        int source = indices[i];
        float clipX, clipY;
        Matrix4f_transformPoint(matrix, positions[source * 2], positions[source * 2 + 1], &clipX, &clipY);
        vertices[i].position = (vector_float2){clipX, clipY};
        vertices[i].uv = (vector_float2){0.5f, 0.5f};
        vertices[i].color = vertexColor;
    }
    [metal->encoder setRenderPipelineState:metal->pipeline];
    [metal->encoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [metal->encoder setFragmentTexture:metal->whiteTexture atIndex:0];
    [metal->encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

static void metalDrawRectangle(Renderer* renderer, float x1, float y1, float x2, float y2,
                               uint32_t color, float alpha, bool outline) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (!outline) {
        metalDrawSolidQuad(metal, x1, y1, x2 + 1, y1, x2 + 1, y2 + 1, x1, y2 + 1, color, alpha);
        return;
    }
    metalDrawSolidQuad(metal, x1, y1, x2 + 1, y1, x2 + 1, y1 + 1, x1, y1 + 1, color, alpha);
    metalDrawSolidQuad(metal, x1, y2, x2 + 1, y2, x2 + 1, y2 + 1, x1, y2 + 1, color, alpha);
    metalDrawSolidQuad(metal, x1, y1 + 1, x1 + 1, y1 + 1, x1 + 1, y2, x1, y2, color, alpha);
    metalDrawSolidQuad(metal, x2, y1 + 1, x2 + 1, y1 + 1, x2 + 1, y2, x2, y2, color, alpha);
}

static void metalDrawRectangleColor(Renderer* renderer, float x1, float y1, float x2, float y2,
                                    uint32_t color1, MAYBE_UNUSED uint32_t color2,
                                    MAYBE_UNUSED uint32_t color3, MAYBE_UNUSED uint32_t color4,
                                    float alpha, bool outline) {
    metalDrawRectangle(renderer, x1, y1, x2, y2, color1, alpha, outline);
}

static void metalDrawLine(Renderer* renderer, float x1, float y1, float x2, float y2,
                          float width, uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    float dx = x2 - x1, dy = y2 - y1;
    float length = sqrtf(dx * dx + dy * dy);
    if (length <= 0.0001f) return;
    float px = -dy / length * width * 0.5f;
    float py = dx / length * width * 0.5f;
    metalDrawSolidQuad(metal, x1 + px, y1 + py, x1 - px, y1 - py,
                       x2 - px, y2 - py, x2 + px, y2 + py, color, alpha);
}

static void metalDrawSpriteTiled(Renderer* renderer, int32_t tpagIndex, float originX,
                                 float originY, float x, float y, float xscale, float yscale,
                                 bool tileX, bool tileY, float roomW, float roomH,
                                 uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId)) return;
    float tileW = tpag->boundingWidth * fabsf(xscale);
    float tileH = tpag->boundingHeight * fabsf(yscale);
    if (tileW <= 0.0f || tileH <= 0.0f) return;
    float startX = tileX ? fmodf(x - originX * fabsf(xscale), tileW) : x - originX * fabsf(xscale);
    float startY = tileY ? fmodf(y - originY * fabsf(yscale), tileH) : y - originY * fabsf(yscale);
    if (startX > 0.0f) startX -= tileW;
    if (startY > 0.0f) startY -= tileH;
    float endX = tileX ? roomW : startX + tileW;
    float endY = tileY ? roomH : startY + tileH;
    float drawScaleX = xscale * (float)tpag->targetWidth / (float)tpag->sourceWidth;
    float drawScaleY = yscale * (float)tpag->targetHeight / (float)tpag->sourceHeight;
    for (float tileYPos = startY; tileYPos < endY; tileYPos += tileH) {
        for (float tileXPos = startX; tileXPos < endX; tileXPos += tileW) {
            metalDrawSpritePart(renderer, tpagIndex, 0, 0, tpag->sourceWidth, tpag->sourceHeight,
                                tileXPos + originX * fabsf(xscale),
                                tileYPos + originY * fabsf(yscale), drawScaleX, drawScaleY,
                                0.0f, 0.0f, 0.0f, color, alpha);
        }
    }
}

static void metalDrawVideoQuad(MetalRenderer* metal, float x0, float y0, float x1, float y1,
                               float x2, float y2, float x3, float y3, uint32_t color,
                               float alpha, float u0, float v0, float u1, float v1) {
    if (metal->encoder == nil || metal->pipeline == nil || metal->videoTexture == nil) return;
    Matrix4f* matrix = &metal->base.gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    float positions[8] = {x0, y0, x1, y1, x2, y2, x3, y3};
    float uvs[8] = {u0, v0, u1, v0, u1, v1, u0, v1};
    const int indices[6] = {0, 1, 2, 2, 3, 0};
    MetalVertex vertices[6];
    vector_float4 vertexColor = {BGR_R(color) / 255.0f, BGR_G(color) / 255.0f, BGR_B(color) / 255.0f, alpha};
    for (int i = 0; i < 6; i++) {
        int source = indices[i];
        float clipX, clipY;
        Matrix4f_transformPoint(matrix, positions[source * 2], positions[source * 2 + 1], &clipX, &clipY);
        vertices[i].position = (vector_float2){clipX, clipY};
        vertices[i].uv = (vector_float2){uvs[source * 2], uvs[source * 2 + 1]};
        vertices[i].color = vertexColor;
    }
    [metal->encoder setRenderPipelineState:metal->pipeline];
    [metal->encoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [metal->encoder setFragmentTexture:metal->videoTexture atIndex:0];
    [metal->encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

static void metalDrawSpritePos(Renderer* renderer, int32_t tpagIndex, float x1, float y1, float x2,
                               float y2, float x3, float y3, float x4, float y4, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId)) return;
    float invW = 1.0f / (float)metal->textureWidths[pageId];
    float invH = 1.0f / (float)metal->textureHeights[pageId];
    metalDrawQuad(metal, tpag, pageId, x1, y1, x2, y2, x3, y3, x4, y4, 0xFFFFFF, alpha,
                  tpag->sourceX * invW, tpag->sourceY * invH,
                  (tpag->sourceX + tpag->sourceWidth) * invW,
                  (tpag->sourceY + tpag->sourceHeight) * invH);
}

static void metalDrawTextCommon(Renderer* renderer, const char* text, float x, float y,
                                float xscale, float yscale, float angleDeg, float lineSeparation,
                                uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    DataWin* dataWin = renderer->dataWin;
    if (renderer->drawFont < 0 || (uint32_t)renderer->drawFont >= dataWin->font.count || text == nullptr) {
        if (!metalTextDiagnosticLogged) {
            logDebug("Metal: text skipped (font=%d, fontCount=%u, text=%s)\n",
                     renderer->drawFont, dataWin->font.count, text == nullptr ? "null" : "set");
            metalTextDiagnosticLogged = true;
        }
        return;
    }
    Font* font = &dataWin->font.fonts[renderer->drawFont];

    TexturePageItem* tpag;
    uint32_t pageId;
    Sprite* spriteFont = nullptr;
    if (font->isSpriteFont) {
        if (font->spriteIndex < 0 || (uint32_t)font->spriteIndex >= dataWin->sprt.count) return;
        spriteFont = &dataWin->sprt.sprites[font->spriteIndex];
        tpag = nullptr;
        pageId = 0;
    } else {
        if (font->tpagIndex < 0 || !metalResolveTpag(metal, font->tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId)) return;
    }
    if (!metalTextDiagnosticLogged) {
        logDebug("Metal: text font=%d glyphs=%u spriteFont=%s tpag=%d encoder=%s\n",
                 renderer->drawFont, font->glyphCount, font->isSpriteFont ? "yes" : "no",
                 font->tpagIndex, metal->encoder == nil ? "closed" : "open");
        metalTextDiagnosticLogged = true;
    }
    int32_t textLen = (int32_t)strlen(text);
    if (textLen == 0) return;

    float lineStride = lineSeparation < 0.0f ? TextUtils_lineStride(font) :
        lineSeparation / (font->scaleY != 0.0f ? font->scaleY : 1.0f);
    int32_t lineCount = TextUtils_countLines(text, textLen);
    float valignOffset = renderer->drawValign == 1 ? -(float)lineCount * lineStride * 0.5f :
                         renderer->drawValign == 2 ? -(float)lineCount * lineStride : 0.0f;
    float angle = -angleDeg * ((float)M_PI / 180.0f);
    Matrix4f transform;
    Matrix4f_setTransform2D(&transform, x, y, xscale * font->scaleX, yscale * font->scaleY, angle);
    float cursorY = valignOffset - (float)font->ascenderOffset;
    int32_t lineStart = 0;
    float invW = 0.0f;
    float invH = 0.0f;
    int32_t drawnGlyphs = 0;

    for (int32_t line = 0; line < lineCount; line++) {
        int32_t lineEnd = lineStart;
        while (lineEnd < textLen && !TextUtils_isNewlineChar(text[lineEnd])) lineEnd++;
        float cursorX = 0.0f;
        float lineWidth = TextUtils_measureLineWidth(font, text + lineStart, lineEnd - lineStart);
        if (renderer->drawHalign == 1) cursorX = -lineWidth * 0.5f;
        else if (renderer->drawHalign == 2) cursorX = -lineWidth;
        int32_t pos = 0;
        while (pos < lineEnd - lineStart) {
            uint16_t character = TextUtils_decodeUtf8(text + lineStart, lineEnd - lineStart, &pos);
            FontGlyph* glyph = TextUtils_findGlyph(font, character);
            if (glyph != nullptr) {
                TexturePageItem* glyphTpag = tpag;
                uint32_t glyphPageId = pageId;
                if (spriteFont != nullptr) {
                    int32_t glyphIndex = (int32_t)(glyph - font->glyphs);
                    if (glyphIndex < 0 || (uint32_t)glyphIndex >= spriteFont->textureCount) {
                        cursorX += glyph->shift;
                        continue;
                    }
                    int32_t glyphTpagIndex = spriteFont->tpagIndices[glyphIndex];
                    if (!metalResolveTpag(metal, glyphTpagIndex, &glyphTpag, &glyphPageId) ||
                        !metalEnsureTextureLoaded(metal, glyphPageId)) {
                        cursorX += glyph->shift;
                        continue;
                    }
                }
                invW = 1.0f / (float)metal->textureWidths[glyphPageId];
                invH = 1.0f / (float)metal->textureHeights[glyphPageId];
                float localX0 = cursorX + glyph->offset;
                float localY0 = cursorY;
                if (spriteFont != nullptr)
                    localY0 += (float)(int32_t)glyphTpag->targetY - (float)font->spriteOriginYAdjust;
                float localX1 = localX0 + glyph->sourceWidth;
                float localY1 = localY0 + glyph->sourceHeight;
                float x0, y0, x1, y1, x2, y2, x3, y3;
                Matrix4f_transformPoint(&transform, localX0, localY0, &x0, &y0);
                Matrix4f_transformPoint(&transform, localX1, localY0, &x1, &y1);
                Matrix4f_transformPoint(&transform, localX1, localY1, &x2, &y2);
                Matrix4f_transformPoint(&transform, localX0, localY1, &x3, &y3);
                metalDrawQuad(metal, glyphTpag, glyphPageId, x0, y0, x1, y1, x2, y2, x3, y3, color, alpha,
                              (glyphTpag->sourceX + glyph->sourceX) * invW,
                              (glyphTpag->sourceY + glyph->sourceY) * invH,
                              (glyphTpag->sourceX + glyph->sourceX + glyph->sourceWidth) * invW,
                              (glyphTpag->sourceY + glyph->sourceY + glyph->sourceHeight) * invH);
                if (!metalGlyphDiagnosticLogged) {
                    float clipX, clipY;
                    Matrix4f_transformPoint(&metal->base.gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION], x0, y0, &clipX, &clipY);
                    logDebug("Metal: first glyph world=(%.1f,%.1f) clip=(%.3f,%.3f) uv=(%.3f,%.3f)-(%.3f,%.3f) alpha=%.3f page=%u\n",
                             x0, y0, clipX, clipY,
                             (glyphTpag->sourceX + glyph->sourceX) * invW,
                             (glyphTpag->sourceY + glyph->sourceY) * invH,
                             (glyphTpag->sourceX + glyph->sourceX + glyph->sourceWidth) * invW,
                             (glyphTpag->sourceY + glyph->sourceY + glyph->sourceHeight) * invH,
                             alpha, glyphPageId);
                    metalGlyphDiagnosticLogged = true;
                }
                drawnGlyphs++;
                cursorX += glyph->shift;
            }
        }
        cursorY += lineStride;
        lineStart = lineEnd < textLen ? TextUtils_skipNewline(text, lineEnd, textLen) : lineEnd;
    }
    if (!metalVisibleTextDiagnosticLogged && alpha > 0.01f) {
        logDebug("Metal: visible text submitted glyphs=%d alpha=%.3f font=%d\n",
                 drawnGlyphs, alpha, renderer->drawFont);
        metalVisibleTextDiagnosticLogged = true;
    }
    if (drawnGlyphs == 0)
        logDebug("Metal: text submitted zero glyphs for font=%d\n", renderer->drawFont);
}

static void metalDrawText(Renderer* renderer, const char* text, float x, float y, float xscale,
                          float yscale, float angleDeg, float lineSeparation) {
    metalDrawTextCommon(renderer, text, x, y, xscale, yscale, angleDeg, lineSeparation,
                        renderer->drawColor, renderer->drawAlpha);
}

static void metalDrawTextColor(Renderer* renderer, const char* text, float x, float y, float xscale,
                               float yscale, float angleDeg, int32_t c1, MAYBE_UNUSED int32_t c2,
                               MAYBE_UNUSED int32_t c3, MAYBE_UNUSED int32_t c4, float alpha,
                               float lineSeparation) {
    metalDrawTextCommon(renderer, text, x, y, xscale, yscale, angleDeg, lineSeparation,
                        (uint32_t)c1, alpha);
}
static void metalNoopRect(MAYBE_UNUSED Renderer* renderer, float a, float b, float c, float d, uint32_t e, float f, bool g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
static void metalNoopRectColor(MAYBE_UNUSED Renderer* renderer, float a, float b, float c, float d, uint32_t e, uint32_t f, uint32_t g, uint32_t h, float i, bool j) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; }
static void metalNoopLine(MAYBE_UNUSED Renderer* renderer, float a, float b, float c, float d, float e, uint32_t f, float g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
static void metalNoopLineColor(MAYBE_UNUSED Renderer* renderer, float a, float b, float c, float d, float e, uint32_t f, uint32_t g, float h) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; }
static void metalNoopTriangle(MAYBE_UNUSED Renderer* renderer, float a, float b, float c, float d, float e, float f, uint32_t g, uint32_t h, uint32_t i, float j, bool k) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; }

static BlendFactors metalBlendFactors(MAYBE_UNUSED Renderer* renderer) { return (BlendFactors){bm_src_alpha, bm_inv_src_alpha, bm_one, bm_inv_src_alpha}; }
static int32_t metalBlendMode(MAYBE_UNUSED Renderer* renderer) { return bm_normal; }
static void metalSetBlendMode(MAYBE_UNUSED Renderer* renderer, int32_t mode) { (void)mode; }
static void metalSetBlendModeExt(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d) { (void)a; (void)b; (void)c; (void)d; }
static void metalSetBlendEnable(Renderer* renderer, bool enabled) { ((MetalRenderer*)renderer)->blendEnabled = enabled; }
static bool metalGetBlendEnable(Renderer* renderer) { return ((MetalRenderer*)renderer)->blendEnabled; }
static void metalSetColorWrite(Renderer* renderer, bool r, bool g, bool b, bool a) { MetalRenderer* m = (MetalRenderer*)renderer; m->colorWriteR = r; m->colorWriteG = g; m->colorWriteB = b; m->colorWriteA = a; }
static void metalGetColorWrite(Renderer* renderer, bool* r, bool* g, bool* b, bool* a) { MetalRenderer* m = (MetalRenderer*)renderer; *r = m->colorWriteR; *g = m->colorWriteG; *b = m->colorWriteB; *a = m->colorWriteA; }
static void metalNoopBlendBool(MAYBE_UNUSED Renderer* renderer, bool value) { (void)value; }
static void metalNoopBlendRef(MAYBE_UNUSED Renderer* renderer, uint8_t value) { (void)value; }
static void metalNoopFog(MAYBE_UNUSED Renderer* renderer, bool a, uint32_t b) { (void)a; (void)b; }
static void metalNoopTiled(MAYBE_UNUSED Renderer* renderer, int32_t a, float b, float c, float d, float e, float f, float g, bool h, bool i, float j, float k, uint32_t l, float m) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l; (void)m; }
static void metalNoopSurfaceTiled(MAYBE_UNUSED Renderer* renderer, int32_t a, float b, float c, float d, float e, float f, float g, uint32_t h, float i) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; }

static int32_t metalCreateSurface(MAYBE_UNUSED Renderer* renderer, int32_t w, int32_t h) {
    static bool logged;
    if (!logged) {
        logDebug("Metal: surface_create requested size=%dx%d (surfaces not implemented)\n", w, h);
        logged = true;
    }
    return -1;
}
static int32_t metalCreateSprite(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, bool f, bool g, int32_t h, int32_t i) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; return -1; }
static bool metalSurfaceExists(Renderer* renderer, int32_t id) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    return id == RENDERER_VIDEO_SURFACE_ID && metal->videoTexture != nil;
}
static bool metalSetTarget(MAYBE_UNUSED Renderer* renderer, int32_t id, bool implicitTarget) {
    static bool logged;
    if (!logged) {
        logDebug("Metal: surface_set_target requested surface=%d implicit=%s (surfaces not implemented)\n",
                 id, implicitTarget ? "yes" : "no");
        logged = true;
    }
    return false;
}
static int32_t metalEnsureSurface(MAYBE_UNUSED Renderer* renderer, int32_t w, int32_t h) { (void)w; (void)h; return APPLICATION_SURFACE_ID; }
static float metalSurfaceWidth(Renderer* renderer, int32_t id) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (id != RENDERER_VIDEO_SURFACE_ID) return 0.0f;
    return metal->videoTexture == nil ? 0.0f : (float)metal->videoWidth;
}
static float metalSurfaceHeight(Renderer* renderer, int32_t id) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (id != RENDERER_VIDEO_SURFACE_ID) return 0.0f;
    return metal->videoTexture == nil ? 0.0f : (float)metal->videoHeight;
}
static void metalDrawSurface(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, float f, float g, float h, float i, float j, uint32_t k, float l) {
    static bool logged;
    if (a == RENDERER_VIDEO_SURFACE_ID) {
        MetalRenderer* metal = (MetalRenderer*)renderer;
        if (metal->videoTexture == nil || metal->encoder == nil) return;
        static bool logged;
        if (!logged) {
            logDebug("Metal: drawing video surface (%dx%d)\n", metal->videoWidth, metal->videoHeight);
            logged = true;
        }
        int32_t srcWidth = d < 0 ? metal->videoWidth : d;
        int32_t srcHeight = e < 0 ? metal->videoHeight : e;
        if (srcWidth <= 0 || srcHeight <= 0) return;
        float angle = -j * ((float)M_PI / 180.0f);
        Matrix4f transform;
        Matrix4f_setTransform2D(&transform, f, g, h, i, angle);
        float x0, y0, x1, y1, x2, y2, x3, y3;
        Matrix4f_transformPoint(&transform, 0.0f, 0.0f, &x0, &y0);
        Matrix4f_transformPoint(&transform, (float)srcWidth, 0.0f, &x1, &y1);
        Matrix4f_transformPoint(&transform, (float)srcWidth, (float)srcHeight, &x2, &y2);
        Matrix4f_transformPoint(&transform, 0.0f, (float)srcHeight, &x3, &y3);
        metalDrawVideoQuad(metal, x0, y0, x1, y1, x2, y2, x3, y3, k, l,
                   (float)b / (float)metal->videoWidth,
                   (float)c / (float)metal->videoHeight,
                   (float)(b + srcWidth) / (float)metal->videoWidth,
                   (float)(c + srcHeight) / (float)metal->videoHeight);
        return;
    }
    if (!logged) {
        logDebug("Metal: draw_surface requested surface=%d (surfaces not implemented)\n", a);
        logged = true;
    }
    (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l;
}
static void metalDrawSurfaceColor(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, float f, float g, float h, float i, float j, uint32_t k, uint32_t l, uint32_t m, uint32_t n, float o) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l; (void)m; (void)n; (void)o; }
static void metalSurfaceResize(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c) { (void)a; (void)b; (void)c; }
static void metalSurfaceFree(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; }
static void metalSurfaceCopy(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g, int32_t h, bool i) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; }
static bool metalSurfacePixels(MAYBE_UNUSED Renderer* renderer, int32_t id, uint8_t* pixels) { (void)id; (void)pixels; return false; }
static uint32_t metalTexture(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; return 0; }
static float metalTexel(MAYBE_UNUSED Renderer* renderer, uint32_t id) { (void)id; return 0.0f; }
static bool metalUVs(MAYBE_UNUSED Renderer* renderer, uint32_t id, float* uvs) { (void)id; (void)uvs; return false; }
static void metalTextureStage(Renderer* renderer, int32_t slot, uint32_t texture) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (slot < 0 || slot >= MAX_TEXTURE_STAGES) return;
    metal->stagedTextures[slot] = nil;
    if (texture == 0 || texture & 0x80000000U) return;
    int32_t tpagIndex = (int32_t)texture - 1;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (metalResolveTpag(metal, tpagIndex, &tpag, &pageId) && metalEnsureTextureLoaded(metal, pageId))
        metal->stagedTextures[slot] = metal->textures[pageId];
}
static void metalShader(MAYBE_UNUSED Renderer* renderer, int32_t id) {
    static bool logged;
    if (!logged) {
        const char* name = "unknown";
        size_t vertexLength = 0;
        size_t fragmentLength = 0;
        if (renderer->dataWin != nullptr && id >= 0 && (uint32_t)id < renderer->dataWin->shdr.count) {
            Shader* shader = &renderer->dataWin->shdr.shaders[id];
            name = shader->name != nullptr ? shader->name : "unnamed";
            if (shader->glslES_Vertex != nullptr) vertexLength = strlen(shader->glslES_Vertex);
            if (shader->glslES_Fragment != nullptr) fragmentLength = strlen(shader->glslES_Fragment);
        }
        logDebug("Metal: gpu_set_shader requested shader=%d name=%s GLSL=(%zu vertex,%zu fragment); custom shaders not implemented\n",
                 id, name, vertexLength, fragmentLength);
        logged = true;
    }
    renderer->currentShader = id;
}
static void metalResetShader(Renderer* renderer) { renderer->currentShader = -1; }
static int32_t metalVideoUploadFrame(Renderer* renderer, int32_t width, int32_t height, const uint8_t* rgba) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (width <= 0 || height <= 0 || rgba == nullptr) return -1;
    if (metal->videoTexture == nil || metal->videoWidth != width || metal->videoHeight != height) {
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                 width:(NSUInteger)width height:(NSUInteger)height mipmapped:NO];
        descriptor.usage = MTLTextureUsageShaderRead;
        metal->videoTexture = [metal->device newTextureWithDescriptor:descriptor];
        metal->videoWidth = width;
        metal->videoHeight = height;
    }
    [metal->videoTexture replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)width, (NSUInteger)height)
                           mipmapLevel:0 withBytes:rgba bytesPerRow:(NSUInteger)width * 4];
    return RENDERER_VIDEO_SURFACE_ID;
}
static int32_t metalUniform(MAYBE_UNUSED Renderer* renderer, int32_t id, char* name) { (void)id; (void)name; return -1; }
static void metalUniformF(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, float c, float d, float e, float f) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; }
static void metalUniformFA(MAYBE_UNUSED Renderer* renderer, int32_t a, float* b, uint32_t c) { (void)a; (void)b; (void)c; }
static void metalUniformI(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; }
static bool metalShaderCompiled(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; return false; }
static bool metalShadersSupported(void) { return false; }
static void metalSetMatrix(MAYBE_UNUSED Renderer* renderer, int32_t type, Matrix4f matrix) { (void)type; (void)matrix; }

static RendererVtable metalVtable = {
    .init = metalInit, .destroy = metalDestroy, .beginFrame = metalBeginFrame,
    .endFrameInit = metalEndFrameInit, .endFrameEnd = metalEndFrameEnd,
    .beginView = metalBeginView, .endView = metalNoopRenderer, .applyProjection = metalApplyProjection,
    .beginGUI = metalBeginGUI, .setGuiProjection = metalSetGuiProjection, .endGUI = metalEndGUI,
    .drawSprite = metalDrawSprite, .drawSpritePart = metalDrawSpritePart, .drawSpritePos = metalDrawSpritePos,
    .drawRectangle = metalDrawRectangle, .drawRectangleColor = metalDrawRectangleColor, .drawLine = metalDrawLine,
    .drawTriangle = metalNoopTriangle, .drawLineColor = metalNoopLineColor, .drawText = metalDrawText,
    .drawTextColor = metalDrawTextColor, .flush = metalNoopRenderer, .clearScreen = metalClearScreen,
    .createSpriteFromSurface = metalCreateSprite, .deleteSprite = metalSurfaceFree,
    .gpuGetBlendFactors = metalBlendFactors, .gpuGetBlendMode = metalBlendMode,
    .gpuSetBlendMode = metalSetBlendMode, .gpuSetBlendModeExt = metalSetBlendModeExt,
    .gpuSetBlendEnable = metalSetBlendEnable, .gpuSetAlphaTestEnable = metalNoopBlendBool,
    .gpuSetAlphaTestRef = metalNoopBlendRef, .gpuSetColorWriteEnable = metalSetColorWrite,
    .gpuGetColorWriteEnable = metalGetColorWrite, .gpuGetBlendEnable = metalGetBlendEnable,
    .gpuSetFog = metalNoopFog, .drawSpriteTiled = metalDrawSpriteTiled, .drawSurfaceTiled = metalNoopSurfaceTiled,
    .createSurface = metalCreateSurface, .surfaceExists = metalSurfaceExists, .setRenderTarget = metalSetTarget,
    .ensureApplicationSurface = metalEnsureSurface, .getSurfaceWidth = metalSurfaceWidth,
    .getSurfaceHeight = metalSurfaceHeight, .drawSurface = metalDrawSurface, .drawSurfaceColor = metalDrawSurfaceColor,
    .surfaceResize = metalSurfaceResize,
    .surfaceFree = metalSurfaceFree, .surfaceCopy = metalSurfaceCopy, .surfaceGetPixels = metalSurfacePixels,
    .spriteGetTexture = metalTexture, .surfaceGetTexture = metalTexture,
    .textureGetTexelWidth = metalTexel, .textureGetTexelHeight = metalTexel, .textureGetUVs = metalUVs,
    .textureSetStage = metalTextureStage, .gpuSetShader = metalShader, .gpuResetShader = metalResetShader,
    .shaderGetUniform = metalUniform, .shaderGetSamplerIndex = metalUniform,
    .shaderSetUniformF = metalUniformF, .shaderSetUniformFArray = metalUniformFA,
    .shaderSetUniformI = metalUniformI, .shaderIsCompiled = metalShaderCompiled,
    .shadersSupported = metalShadersSupported, .setMatrix = metalSetMatrix,
    .videoUploadFrame = metalVideoUploadFrame
};

Renderer* MetalRenderer_create(void) {
    MetalRenderer* metal = (MetalRenderer*)safeCalloc(1, sizeof(MetalRenderer));
    metal->base.vtable = &metalVtable;
    metal->base.drawColor = 0xFFFFFF;
    metal->base.drawAlpha = 1.0f;
    metal->base.drawFont = -1;
    metal->base.drawHalign = 0;
    metal->base.drawValign = 0;
    metal->base.circlePrecision = 24;
    metal->base.currentShader = -1;
    activeMetalRenderer = metal;
    return &metal->base;
}

void MetalRenderer_presentFrame(void) {
    MetalRenderer* metal = activeMetalRenderer;
    if (metal == nil || metal->commandBuffer == nil || metal->drawable == nil) return;
    if (metal->encoder != nil) {
        [metal->encoder endEncoding];
        metal->encoder = nil;
    }
    [metal->commandBuffer presentDrawable:metal->drawable];
    [metal->commandBuffer commit];
    metal->presentedCommandBuffer = metal->commandBuffer;
    metal->commandBuffer = nil;
    metal->drawable = nil;
}

void MetalRenderer_waitForPresentedFrame(void) {
    if (activeMetalRenderer != nil && activeMetalRenderer->presentedCommandBuffer != nil) {
        [activeMetalRenderer->presentedCommandBuffer waitUntilCompleted];
        activeMetalRenderer->presentedCommandBuffer = nil;
    }
}