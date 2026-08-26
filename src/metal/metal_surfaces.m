#import "metal_internal.h"

int32_t metalCreateSurface(Renderer* renderer, int32_t width, int32_t height) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (width <= 0 || height <= 0) return -1;

    uint32_t surfaceIndex = metalFindOrAllocateSurfaceSlot(metal);
    id<MTLTexture> texture = metalCreateRenderTexture(metal, width, height);
    if (texture == nil) return -1;

    metal->surfaceTextures[surfaceIndex] = texture;
    metal->surfaceWidth[surfaceIndex] = width;
    metal->surfaceHeight[surfaceIndex] = height;
    metal->surfaceAlive[surfaceIndex] = true;

    // Clear new surfaces to transparent black (GM behavior).
    if (metal->commandBuffer != nil) {
        int32_t prevSurface = metal->currentSurfaceId;
        id<MTLTexture> prevTarget = metal->currentTarget;
        bool hadEncoder = metal->encoder != nil;
        metalBindSurfaceTarget(metal, (int32_t)surfaceIndex, true, MTLClearColorMake(0, 0, 0, 0));
        metalEndEncoder(metal);
        metal->currentSurfaceId = prevSurface;
        metal->currentTarget = prevTarget;
        if (hadEncoder && prevTarget != nil)
            metalEnsureEncoder(metal, false, MTLClearColorMake(0, 0, 0, 1));
    }

    logInfo("Metal: Created surface %u with size (%dx%d)\n", surfaceIndex, width, height);
    return (int32_t)surfaceIndex;
}

bool metalSurfaceExists(Renderer* renderer, int32_t surfaceId) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceId < 0 || (uint32_t)surfaceId >= metal->surfaceCount) return false;
    return metal->surfaceAlive[surfaceId];
}

int32_t metalEnsureApplicationSurface(Renderer* renderer, int32_t width, int32_t height) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    int32_t id = renderer->runner->applicationSurfaceId;

    bool needsCreate = (id < 0) || ((uint32_t)id >= metal->surfaceCount) || !metal->surfaceAlive[id];
    if (needsCreate) {
        id = metalCreateSurface(renderer, width, height);
        renderer->runner->applicationSurfaceId = id;
        return id;
    }

    if (metal->surfaceWidth[id] != width || metal->surfaceHeight[id] != height)
        metalSurfaceResize(renderer, id, width, height);
    return id;
}

void metalSurfaceFree(Renderer* renderer, int32_t surfaceID) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceID < 0 || (uint32_t)surfaceID >= metal->surfaceCount) return;
    if (surfaceID == renderer->runner->applicationSurfaceId) return;
    if (!metal->surfaceAlive[surfaceID]) return;

    if (metal->currentSurfaceId == surfaceID) {
        metalEndEncoder(metal);
        metal->currentSurfaceId = -1;
        metal->currentTarget = nil;
    }

    metal->surfaceTextures[surfaceID] = nil;
    metal->surfaceWidth[surfaceID] = 0;
    metal->surfaceHeight[surfaceID] = 0;
    metal->surfaceAlive[surfaceID] = false;
    logInfo("Metal: Freed Surface %u\n", surfaceID);
}

void metalSurfaceResize(Renderer* renderer, int32_t surfaceID, int32_t width, int32_t height) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceID < 0 || (uint32_t)surfaceID >= metal->surfaceCount) return;
    if (!metal->surfaceAlive[surfaceID]) return;
    if (metal->surfaceWidth[surfaceID] == width && metal->surfaceHeight[surfaceID] == height) return;
    if (width <= 0 || height <= 0) return;

    bool wasCurrent = (metal->currentSurfaceId == surfaceID);
    if (wasCurrent) metalEndEncoder(metal);

    id<MTLTexture> texture = metalCreateRenderTexture(metal, width, height);
    if (texture == nil) return;
    metal->surfaceTextures[surfaceID] = texture;
    metal->surfaceWidth[surfaceID] = width;
    metal->surfaceHeight[surfaceID] = height;

    if (wasCurrent)
        metalBindSurfaceTarget(metal, surfaceID, true, MTLClearColorMake(0, 0, 0, 0));

    logInfo("Metal: Resized Surface %u Size (%dx%d)\n", surfaceID, width, height);
}

bool metalSetRenderTarget(Renderer* renderer, int32_t surfaceId, bool implicitApplicationSurface) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceId < 0 || (uint32_t)surfaceId >= metal->surfaceCount) return false;
    if (!metal->surfaceAlive[surfaceId]) return false;

    int32_t viewCurrent = renderer->runner->viewsEnabled ? renderer->runner->viewCurrent : 0;
    RuntimeView* view = &renderer->runner->views[viewCurrent];
    renderer->cameraCurrent = view->cameraId;
    GMLCamera* camera = Runner_getCameraById(renderer->runner, renderer->cameraCurrent);

    metalBindSurfaceTarget(metal, surfaceId, false, MTLClearColorMake(0, 0, 0, 1));

    if (surfaceId == renderer->runner->applicationSurfaceId && implicitApplicationSurface) {
        metalApplyViewportScissor(metal, renderer->CPortX, renderer->CPortY,
                                  renderer->CPortW, renderer->CPortH, true);
        metalApplyProjection(renderer, &camera->viewMatrix, &camera->projectionMatrix);
        return true;
    }

    if (surfaceId == view->surfaceId) {
        metalApplyViewportScissor(metal, 0, 0, metal->surfaceWidth[surfaceId], metal->surfaceHeight[surfaceId], false);
        metalApplyProjection(renderer, &camera->viewMatrix, &camera->projectionMatrix);
        return true;
    }

    renderer->cameraCurrent = SURFACE_CAMERA;
    GMLCamera* surfaceCamera = &renderer->runner->surfaceCamera;
    surfaceCamera->allocated = true;
    surfaceCamera->viewX = 0.0;
    surfaceCamera->viewY = 0.0;
    surfaceCamera->viewWidth = metal->surfaceWidth[surfaceId];
    surfaceCamera->viewHeight = metal->surfaceHeight[surfaceId];
    surfaceCamera->borderX = 0;
    surfaceCamera->borderY = 0;
    surfaceCamera->speedX = 0;
    surfaceCamera->speedY = 0;
    surfaceCamera->objectId = -1;
    surfaceCamera->viewAngle = 0;
    Runner_updateCameraViewSimple(surfaceCamera);

    metalApplyViewportScissor(metal, 0, 0, metal->surfaceWidth[surfaceId], metal->surfaceHeight[surfaceId], false);
    metalApplyProjection(renderer, &surfaceCamera->viewMatrix, &surfaceCamera->projectionMatrix);
    return true;
}

float metalGetSurfaceWidth(Renderer* renderer, int32_t surfaceId) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceId < 0 || (uint32_t)surfaceId >= metal->surfaceCount) return 0.0f;
    if (!metal->surfaceAlive[surfaceId]) return 0.0f;
    return (float)metal->surfaceWidth[surfaceId];
}

float metalGetSurfaceHeight(Renderer* renderer, int32_t surfaceId) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceId < 0 || (uint32_t)surfaceId >= metal->surfaceCount) return 0.0f;
    if (!metal->surfaceAlive[surfaceId]) return 0.0f;
    return (float)metal->surfaceHeight[surfaceId];
}

void metalDrawSurface(Renderer* renderer, int32_t surfaceID, int32_t srcLeft, int32_t srcTop,
                      int32_t srcWidth, int32_t srcHeight, float x, float y, float xscale, float yscale,
                      float angleDeg, uint32_t color, float alpha) {
    metalDrawSurfaceColor(renderer, surfaceID, srcLeft, srcTop, srcWidth, srcHeight, x, y, xscale, yscale,
                          angleDeg, color, color, color, color, alpha);
}

void metalDrawSurfaceColor(Renderer* renderer, int32_t surfaceID, int32_t srcLeft, int32_t srcTop,
                           int32_t srcWidth, int32_t srcHeight, float x, float y, float xscale, float yscale,
                           float angleDeg, uint32_t color1, uint32_t color2, uint32_t color3, uint32_t color4,
                           float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceID < 0 || (uint32_t)surfaceID >= metal->surfaceCount) return;
    if (!metal->surfaceAlive[surfaceID] || metal->surfaceTextures[surfaceID] == nil) return;

    // Cannot sample a surface while it is the active render target.
    if (metal->currentSurfaceId == surfaceID) metalEndEncoder(metal);

    int32_t texW = metal->surfaceWidth[surfaceID];
    int32_t texH = metal->surfaceHeight[surfaceID];
    if (srcWidth < 0) { srcLeft = 0; srcTop = 0; srcWidth = texW; srcHeight = texH; }
    if (srcWidth <= 0 || srcHeight <= 0) return;

    float u0 = (float)srcLeft / (float)texW;
    float v0 = (float)srcTop / (float)texH;
    float u1 = (float)(srcLeft + srcWidth) / (float)texW;
    float v1 = (float)(srcTop + srcHeight) / (float)texH;

    float angle = -angleDeg * ((float)M_PI / 180.0f);
    Matrix4f transform;
    Matrix4f_setTransform2D(&transform, x, y, xscale, yscale, angle);
    float x0, y0, x1, y1, x2, y2, x3, y3;
    Matrix4f_transformPoint(&transform, 0.0f, 0.0f, &x0, &y0);
    Matrix4f_transformPoint(&transform, (float)srcWidth, 0.0f, &x1, &y1);
    Matrix4f_transformPoint(&transform, (float)srcWidth, (float)srcHeight, &x2, &y2);
    Matrix4f_transformPoint(&transform, 0.0f, (float)srcHeight, &x3, &y3);

    if (metal->encoder == nil && metal->currentTarget != nil)
        metalEnsureEncoder(metal, false, MTLClearColorMake(0, 0, 0, 1));

    metalDrawQuadRaw(metal, metal->surfaceTextures[surfaceID], x0, y0, x1, y1, x2, y2, x3, y3,
                     color1, color2, color3, color4, alpha, u0, v0, u1, v1);
}

void metalDrawSurfaceTiled(Renderer* renderer, int32_t surfaceID, float x, float y, float xscale, float yscale,
                           float roomW, float roomH, uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceID < 0 || (uint32_t)surfaceID >= metal->surfaceCount) return;
    if (!metal->surfaceAlive[surfaceID]) return;

    int32_t texW = metal->surfaceWidth[surfaceID];
    int32_t texH = metal->surfaceHeight[surfaceID];
    float tileW = (float)texW * fabsf(xscale);
    float tileH = (float)texH * fabsf(yscale);
    if (tileW <= 0.0f || tileH <= 0.0f) return;

    float startX = fmodf(x, tileW);
    float startY = fmodf(y, tileH);
    if (startX > 0.0f) startX -= tileW;
    if (startY > 0.0f) startY -= tileH;

    for (float ty = startY; ty < roomH; ty += tileH) {
        for (float tx = startX; tx < roomW; tx += tileW) {
            metalDrawSurface(renderer, surfaceID, 0, 0, texW, texH, tx, ty, xscale, yscale, 0.0f, color, alpha);
        }
    }
}

void metalSurfaceCopy(Renderer* renderer, int32_t destSurfaceID, int32_t destX, int32_t destY,
                      int32_t srcSurfaceID, int32_t srcX, int32_t srcY, int32_t srcW, int32_t srcH, bool part) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (!metalSurfaceExists(renderer, destSurfaceID) || !metalSurfaceExists(renderer, srcSurfaceID)) return;

    Matrix4f prevWVP = renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    int32_t prevSurface = metal->currentSurfaceId;

    metalBindSurfaceTarget(metal, destSurfaceID, false, MTLClearColorMake(0, 0, 0, 1));
    metalSetGuiProjection(renderer, metal->surfaceWidth[destSurfaceID], metal->surfaceHeight[destSurfaceID],
                          metal->surfaceWidth[destSurfaceID], metal->surfaceHeight[destSurfaceID], true);

    bool prevBlend = metal->blendEnabled;
    metal->blendEnabled = false;

    int32_t sX = part ? srcX : 0;
    int32_t sY = part ? srcY : 0;
    int32_t sW = part ? srcW : metal->surfaceWidth[srcSurfaceID];
    int32_t sH = part ? srcH : metal->surfaceHeight[srcSurfaceID];
    metalDrawSurface(renderer, srcSurfaceID, sX, sY, sW, sH, (float)destX, (float)destY, 1.0f, 1.0f, 0.0f, 0xFFFFFF, 1.0f);

    metal->blendEnabled = prevBlend;
    renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION] = prevWVP;

    if (prevSurface >= 0)
        metalBindSurfaceTarget(metal, prevSurface, false, MTLClearColorMake(0, 0, 0, 1));
    else {
        metalEndEncoder(metal);
        metal->currentSurfaceId = -1;
        metal->currentTarget = nil;
    }
}

bool metalSurfaceGetPixels(Renderer* renderer, int32_t surfaceID, uint8_t* outRGBA) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (!metalSurfaceExists(renderer, surfaceID) || outRGBA == nullptr) return false;

    // Ensure any pending draws land before the readback.
    metalEndEncoder(metal);
    if (metal->commandBuffer != nil) {
        [metal->commandBuffer commit];
        [metal->commandBuffer waitUntilCompleted];
        metal->commandBuffer = [metal->commandQueue commandBuffer];
        metal->drawable = metal->drawable; // keep drawable for remaining frame present
    }

    int32_t w = metal->surfaceWidth[surfaceID];
    int32_t h = metal->surfaceHeight[surfaceID];
    id<MTLTexture> texture = metal->surfaceTextures[surfaceID];
    [texture getBytes:outRGBA
          bytesPerRow:(NSUInteger)w * 4
           fromRegion:MTLRegionMake2D(0, 0, (NSUInteger)w, (NSUInteger)h)
          mipmapLevel:0];
    return true;
}

int32_t metalCreateSpriteFromSurface(Renderer* renderer, int32_t surfaceID, int32_t x, int32_t y,
                                     int32_t w, int32_t h, MAYBE_UNUSED bool removeback,
                                     MAYBE_UNUSED bool smooth, int32_t xorig, int32_t yorig) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    DataWin* dw = renderer->dataWin;
    if (w <= 0 || h <= 0) return -1;
    if (!metalSurfaceExists(renderer, surfaceID)) return -1;

    metalEndEncoder(metal);
    if (metal->commandBuffer != nil) {
        [metal->commandBuffer commit];
        [metal->commandBuffer waitUntilCompleted];
        metal->commandBuffer = [metal->commandQueue commandBuffer];
    }

    uint8_t* pixels = (uint8_t*)safeMalloc((size_t)w * (size_t)h * 4);
    id<MTLTexture> src = metal->surfaceTextures[surfaceID];
    [src getBytes:pixels
      bytesPerRow:(NSUInteger)w * 4
       fromRegion:MTLRegionMake2D((NSUInteger)x, (NSUInteger)y, (NSUInteger)w, (NSUInteger)h)
      mipmapLevel:0];

    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                             width:(NSUInteger)w
                                                                                            height:(NSUInteger)h
                                                                                         mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> newTex = [metal->device newTextureWithDescriptor:descriptor];
    [newTex replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)w, (NSUInteger)h)
              mipmapLevel:0
                withBytes:pixels
              bytesPerRow:(NSUInteger)w * 4];
    free(pixels);

    uint32_t pageId = metalFindOrAllocTexturePageSlot(metal);
    metal->textures[pageId] = newTex;
    metal->textureWidths[pageId] = w;
    metal->textureHeights[pageId] = h;
    metal->textureLoaded[pageId] = true;

    uint32_t tpagIndex = metalFindOrAllocTpagSlot(dw, metal->originalTpagCount);
    TexturePageItem* tpag = &dw->tpag.items[tpagIndex];
    tpag->sourceX = 0;
    tpag->sourceY = 0;
    tpag->sourceWidth = (uint16_t)w;
    tpag->sourceHeight = (uint16_t)h;
    tpag->targetX = 0;
    tpag->targetY = 0;
    tpag->targetWidth = (uint16_t)w;
    tpag->targetHeight = (uint16_t)h;
    tpag->boundingWidth = (uint16_t)w;
    tpag->boundingHeight = (uint16_t)h;
    tpag->texturePageId = (int16_t)pageId;

    uint32_t spriteIndex = DataWin_allocSpriteSlot(dw, metal->originalSpriteCount);
    Sprite* sprite = &dw->sprt.sprites[spriteIndex];
    sprite->width = (uint32_t)w;
    sprite->height = (uint32_t)h;
    sprite->originX = xorig;
    sprite->originY = yorig;
    sprite->textureCount = 1;
    sprite->tpagIndices = (int32_t*)safeMalloc(sizeof(int32_t));
    sprite->tpagIndices[0] = (int32_t)tpagIndex;
    sprite->maskCount = 0;
    sprite->masks = nullptr;

    logInfo("Metal: Created dynamic sprite %u (%dx%d) from surface %d\n", spriteIndex, w, h, surfaceID);
    return (int32_t)spriteIndex;
}

void metalDeleteSprite(Renderer* renderer, int32_t spriteIndex) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    DataWin* dw = renderer->dataWin;
    if (spriteIndex < 0 || (uint32_t)spriteIndex >= dw->sprt.count) return;
    if ((uint32_t)spriteIndex < metal->originalSpriteCount) {
        logWarn("Metal: Cannot delete data.win sprite %d\n", spriteIndex);
        return;
    }

    Sprite* sprite = &dw->sprt.sprites[spriteIndex];
    if (sprite->textureCount == 0) return;

    for (uint32_t i = 0; i < sprite->textureCount; i++) {
        int32_t tpagIdx = sprite->tpagIndices[i];
        if (tpagIdx >= 0 && (uint32_t)tpagIdx >= metal->originalTpagCount) {
            TexturePageItem* tpag = &dw->tpag.items[tpagIdx];
            int16_t pageId = tpag->texturePageId;
            if (pageId >= 0 && (uint32_t)pageId < metal->textureCount) {
                metal->textures[pageId] = nil;
                metal->textureWidths[pageId] = 0;
                metal->textureHeights[pageId] = 0;
                metal->textureLoaded[pageId] = false;
            }
            tpag->texturePageId = -1;
        }
    }

    free(sprite->tpagIndices);
    const char* keepName = sprite->name;
    memset(sprite, 0, sizeof(Sprite));
    sprite->name = keepName;
    logInfo("Metal: Deleted sprite %d\n", spriteIndex);
}

int32_t metalVideoUploadFrame(Renderer* renderer, int32_t width, int32_t height, const uint8_t* rgba) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (width <= 0 || height <= 0 || rgba == nullptr) return -1;
    if (metal->videoSurfaceId < 0 || !metalSurfaceExists(renderer, metal->videoSurfaceId)) {
        metal->videoSurfaceId = metalCreateSurface(renderer, width, height);
    } else if (metal->surfaceWidth[metal->videoSurfaceId] != width ||
               metal->surfaceHeight[metal->videoSurfaceId] != height) {
        metalSurfaceResize(renderer, metal->videoSurfaceId, width, height);
    }
    if (metal->videoSurfaceId < 0) return -1;

    id<MTLTexture> texture = metal->surfaceTextures[metal->videoSurfaceId];
    [texture replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)width, (NSUInteger)height)
               mipmapLevel:0
                 withBytes:rgba
               bytesPerRow:(NSUInteger)width * 4];
    return metal->videoSurfaceId;
}

uint32_t metalSurfaceGetTexture(Renderer* renderer, int32_t surfaceID) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (surfaceID < 0 || (uint32_t)surfaceID >= metal->surfaceCount) return 0;
    if (!metal->surfaceAlive[surfaceID]) return 0;
    return METAL_SURFACE_TEXTURE_FLAG | (uint32_t)surfaceID;
}
