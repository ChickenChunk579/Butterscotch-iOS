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
    id<MTLRenderCommandEncoder> encoder;
    id<MTLRenderPipelineState> pipeline;
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
    "    constexpr sampler sampler2d(filter::nearest, address::repeat);\n"
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
    [metal->commandBuffer presentDrawable:metal->drawable];
    [metal->commandBuffer commit];
    metal->encoder = nil;
    metal->commandBuffer = nil;
    metal->drawable = nil;
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
static void metalNoopGUI(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
static void metalNoopGuiProjection(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, bool e) { (void)a; (void)b; (void)c; (void)d; (void)e; }
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
    [metal->encoder setFragmentTexture:metal->textures[pageId] atIndex:0];
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
    if (renderer->drawFont < 0 || (uint32_t)renderer->drawFont >= dataWin->font.count || text == nullptr) return;
    Font* font = &dataWin->font.fonts[renderer->drawFont];
    if (font->isSpriteFont || font->tpagIndex < 0) return;

    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, font->tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId)) return;
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
    float invW = 1.0f / (float)metal->textureWidths[pageId];
    float invH = 1.0f / (float)metal->textureHeights[pageId];

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
                float localX0 = cursorX + glyph->offset;
                float localY0 = cursorY;
                float localX1 = localX0 + glyph->sourceWidth;
                float localY1 = localY0 + glyph->sourceHeight;
                float x0, y0, x1, y1, x2, y2, x3, y3;
                Matrix4f_transformPoint(&transform, localX0, localY0, &x0, &y0);
                Matrix4f_transformPoint(&transform, localX1, localY0, &x1, &y1);
                Matrix4f_transformPoint(&transform, localX1, localY1, &x2, &y2);
                Matrix4f_transformPoint(&transform, localX0, localY1, &x3, &y3);
                metalDrawQuad(metal, tpag, pageId, x0, y0, x1, y1, x2, y2, x3, y3, color, alpha,
                              (tpag->sourceX + glyph->sourceX) * invW,
                              (tpag->sourceY + glyph->sourceY) * invH,
                              (tpag->sourceX + glyph->sourceX + glyph->sourceWidth) * invW,
                              (tpag->sourceY + glyph->sourceY + glyph->sourceHeight) * invH);
                cursorX += glyph->shift;
            }
        }
        cursorY += lineStride;
        lineStart = lineEnd < textLen ? TextUtils_skipNewline(text, lineEnd, textLen) : lineEnd;
    }
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

static int32_t metalCreateSurface(MAYBE_UNUSED Renderer* renderer, int32_t w, int32_t h) { (void)w; (void)h; return -1; }
static int32_t metalCreateSprite(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, bool f, bool g, int32_t h, int32_t i) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; return -1; }
static bool metalSurfaceExists(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; return false; }
static bool metalSetTarget(MAYBE_UNUSED Renderer* renderer, int32_t id, bool implicitTarget) { (void)id; (void)implicitTarget; return false; }
static int32_t metalEnsureSurface(MAYBE_UNUSED Renderer* renderer, int32_t w, int32_t h) { (void)w; (void)h; return APPLICATION_SURFACE_ID; }
static float metalSurfaceDimension(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; return 0.0f; }
static void metalDrawSurface(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, float f, float g, float h, float i, float j, uint32_t k, float l) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l; }
static void metalDrawSurfaceColor(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, float f, float g, float h, float i, float j, uint32_t k, uint32_t l, uint32_t m, uint32_t n, float o) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; (void)j; (void)k; (void)l; (void)m; (void)n; (void)o; }
static void metalSurfaceResize(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c) { (void)a; (void)b; (void)c; }
static void metalSurfaceFree(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; }
static void metalSurfaceCopy(MAYBE_UNUSED Renderer* renderer, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g, int32_t h, bool i) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; (void)i; }
static bool metalSurfacePixels(MAYBE_UNUSED Renderer* renderer, int32_t id, uint8_t* pixels) { (void)id; (void)pixels; return false; }
static uint32_t metalTexture(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; return 0; }
static float metalTexel(MAYBE_UNUSED Renderer* renderer, uint32_t id) { (void)id; return 0.0f; }
static bool metalUVs(MAYBE_UNUSED Renderer* renderer, uint32_t id, float* uvs) { (void)id; (void)uvs; return false; }
static void metalTextureStage(MAYBE_UNUSED Renderer* renderer, int32_t slot, uint32_t texture) { (void)slot; (void)texture; }
static void metalShader(MAYBE_UNUSED Renderer* renderer, int32_t id) { (void)id; }
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
    .beginGUI = metalNoopGUI, .setGuiProjection = metalNoopGuiProjection, .endGUI = metalNoopRenderer,
    .drawSprite = metalDrawSprite, .drawSpritePart = metalNoopSpritePart, .drawSpritePos = metalDrawSpritePos,
    .drawRectangle = metalNoopRect, .drawRectangleColor = metalNoopRectColor, .drawLine = metalNoopLine,
    .drawTriangle = metalNoopTriangle, .drawLineColor = metalNoopLineColor, .drawText = metalDrawText,
    .drawTextColor = metalDrawTextColor, .flush = metalNoopRenderer, .clearScreen = metalClearScreen,
    .createSpriteFromSurface = metalCreateSprite, .deleteSprite = metalSurfaceFree,
    .gpuGetBlendFactors = metalBlendFactors, .gpuGetBlendMode = metalBlendMode,
    .gpuSetBlendMode = metalSetBlendMode, .gpuSetBlendModeExt = metalSetBlendModeExt,
    .gpuSetBlendEnable = metalSetBlendEnable, .gpuSetAlphaTestEnable = metalNoopBlendBool,
    .gpuSetAlphaTestRef = metalNoopBlendRef, .gpuSetColorWriteEnable = metalSetColorWrite,
    .gpuGetColorWriteEnable = metalGetColorWrite, .gpuGetBlendEnable = metalGetBlendEnable,
    .gpuSetFog = metalNoopFog, .drawSpriteTiled = metalNoopTiled, .drawSurfaceTiled = metalNoopSurfaceTiled,
    .createSurface = metalCreateSurface, .surfaceExists = metalSurfaceExists, .setRenderTarget = metalSetTarget,
    .ensureApplicationSurface = metalEnsureSurface, .getSurfaceWidth = metalSurfaceDimension,
    .getSurfaceHeight = metalSurfaceDimension, .drawSurface = metalDrawSurface, .drawSurfaceColor = metalDrawSurfaceColor,
    .surfaceResize = metalSurfaceResize,
    .surfaceFree = metalSurfaceFree, .surfaceCopy = metalSurfaceCopy, .surfaceGetPixels = metalSurfacePixels,
    .spriteGetTexture = metalTexture, .surfaceGetTexture = metalTexture,
    .textureGetTexelWidth = metalTexel, .textureGetTexelHeight = metalTexel, .textureGetUVs = metalUVs,
    .textureSetStage = metalTextureStage, .gpuSetShader = metalShader, .gpuResetShader = metalNoopRenderer,
    .shaderGetUniform = metalUniform, .shaderGetSamplerIndex = metalUniform,
    .shaderSetUniformF = metalUniformF, .shaderSetUniformFArray = metalUniformFA,
    .shaderSetUniformI = metalUniformI, .shaderIsCompiled = metalShaderCompiled,
    .shadersSupported = metalShadersSupported, .setMatrix = metalSetMatrix
};

Renderer* MetalRenderer_create(void) {
    MetalRenderer* metal = (MetalRenderer*)safeCalloc(1, sizeof(MetalRenderer));
    metal->base.vtable = &metalVtable;
    metal->base.currentShader = -1;
    return &metal->base;
}