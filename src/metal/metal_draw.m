#import "metal_internal.h"

void metalDrawTexturedVertices(MetalRenderer* metal, const MetalVertex* vertices, uint32_t vertexCount,
                               id<MTLTexture> texture) {
    if (metal->encoder == nil || texture == nil || vertexCount == 0) return;
    metalEnsureEncoder(metal, false, MTLClearColorMake(0, 0, 0, 1));
    metalBindDrawState(metal);

    id<MTLTexture> drawTexture = texture;
    if (metal->base.currentShader < 0 ||
        (uint32_t)metal->base.currentShader >= metal->gmlShaderCount ||
        !metal->gmlShaders[metal->base.currentShader].compiled) {
        if (metal->stagedTextures[0] != nil)
            drawTexture = metal->stagedTextures[0];
        [metal->encoder setFragmentTexture:drawTexture atIndex:0];
    } else {
        // Custom shader: gm_BaseTexture is sampler 0; seed it from the draw texture if unset.
        if (metal->stagedTextures[0] == nil)
            [metal->encoder setFragmentTexture:drawTexture atIndex:0];
    }

    [metal->encoder setVertexBytes:vertices length:sizeof(MetalVertex) * vertexCount atIndex:0];
    [metal->encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:vertexCount];
}

static vector_float4 metalColorToFloat4(uint32_t bgr, float alpha) {
    return (vector_float4){BGR_R(bgr) / 255.0f, BGR_G(bgr) / 255.0f, BGR_B(bgr) / 255.0f, alpha};
}

void metalDrawQuadRaw(MetalRenderer* metal, id<MTLTexture> texture,
                      float x0, float y0, float x1, float y1, float x2, float y2, float x3, float y3,
                      uint32_t c0, uint32_t c1, uint32_t c2, uint32_t c3, float alpha,
                      float u0, float v0, float u1, float v1) {
    MetalVertex vertices[6];
    float positions[8] = {x0, y0, x1, y1, x2, y2, x3, y3};
    float uvs[8] = {u0, v0, u1, v0, u1, v1, u0, v1};
    vector_float4 colors[4] = {
        metalColorToFloat4(c0, alpha),
        metalColorToFloat4(c1, alpha),
        metalColorToFloat4(c2, alpha),
        metalColorToFloat4(c3, alpha)
    };
    const int indices[6] = {0, 1, 2, 2, 3, 0};
    for (int i = 0; i < 6; i++) {
        int source = indices[i];
        vertices[i].position = (vector_float2){positions[source * 2], positions[source * 2 + 1]};
        vertices[i].uv = (vector_float2){uvs[source * 2], uvs[source * 2 + 1]};
        vertices[i].color = colors[source];
    }
    metalDrawTexturedVertices(metal, vertices, 6, texture);
}

void metalDrawSolidQuad(MetalRenderer* metal, float x0, float y0, float x1, float y1,
                        float x2, float y2, float x3, float y3, uint32_t color, float alpha) {
    metalDrawQuadRaw(metal, metal->whiteTexture, x0, y0, x1, y1, x2, y2, x3, y3,
                     color, color, color, color, alpha, 0.5f, 0.5f, 0.5f, 0.5f);
}

void metalDrawSprite(Renderer* renderer, int32_t tpagIndex, float x, float y, float originX,
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
    metalDrawQuadRaw(metal, metal->textures[pageId], x0, y0, x1, y1, x2, y2, x3, y3,
                     color, color, color, color, alpha,
                     tpag->sourceX * invW, tpag->sourceY * invH,
                     (tpag->sourceX + tpag->sourceWidth) * invW,
                     (tpag->sourceY + tpag->sourceHeight) * invH);
}

void metalDrawSpritePart(Renderer* renderer, int32_t tpagIndex, int32_t srcOffX, int32_t srcOffY,
                         int32_t srcW, int32_t srcH, float x, float y, float xscale, float yscale,
                         float angleDeg, float pivotX, float pivotY, uint32_t color, float alpha) {
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
    metalDrawQuadRaw(metal, metal->textures[pageId], px[0], py[0], px[1], py[1], px[2], py[2], px[3], py[3],
                     color, color, color, color, alpha, u0, v0, u1, v1);
}

void metalDrawSpritePos(Renderer* renderer, int32_t tpagIndex, float x1, float y1, float x2, float y2,
                        float x3, float y3, float x4, float y4, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    uint32_t pageId;

    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId) ||
        !metalEnsureTextureLoaded(metal, pageId))
        return;

    float invW = 1.0f / (float)metal->textureWidths[pageId];
    float invH = 1.0f / (float)metal->textureHeights[pageId];

    uint32_t color = metal->base.drawColor;

    metalDrawQuadRaw(
        metal,
        metal->textures[pageId],
        x1, y1, x2, y2, x3, y3, x4, y4,
        color, color, color, color,
        alpha,
        tpag->sourceX * invW,
        tpag->sourceY * invH,
        (tpag->sourceX + tpag->sourceWidth) * invW,
        (tpag->sourceY + tpag->sourceHeight) * invH
    );
}

void metalDrawSpriteTiled(Renderer* renderer, int32_t tpagIndex, float originX, float originY,
                          float x, float y, float xscale, float yscale, bool tileX, bool tileY,
                          float roomW, float roomH, uint32_t color, float alpha) {
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

void metalDrawTiledPart(Renderer* renderer, int32_t tpagIndex, int32_t srcX, int32_t srcY,
                        int32_t srcW, int32_t srcH, float dstX, float dstY, float dstW, float dstH,
                        uint32_t color, float alpha) {
    if (srcW <= 0 || srcH <= 0 || dstW <= 0.0f || dstH <= 0.0f) return;
    float cursorY = dstY;
    float remH = dstH;
    while (remH > 0.0f) {
        int32_t drawH = ((float)srcH > remH) ? (int32_t)remH : srcH;
        float cursorX = dstX;
        float remW = dstW;
        while (remW > 0.0f) {
            int32_t drawW = ((float)srcW > remW) ? (int32_t)remW : srcW;
            metalDrawSpritePart(renderer, tpagIndex, srcX, srcY, drawW, drawH,
                                cursorX, cursorY, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f, color, alpha);
            cursorX += (float)drawW;
            remW -= (float)drawW;
        }
        cursorY += (float)drawH;
        remH -= (float)drawH;
    }
}

void metalDrawRectangle(Renderer* renderer, float x1, float y1, float x2, float y2,
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

void metalDrawRectangleColor(Renderer* renderer, float x1, float y1, float x2, float y2,
                             uint32_t color1, uint32_t color2, uint32_t color3, uint32_t color4,
                             float alpha, bool outline) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (outline) {
        metalDrawRectangle(renderer, x1, y1, x2, y2, color1, alpha, true);
        return;
    }
    metalDrawQuadRaw(metal, metal->whiteTexture, x1, y1, x2 + 1, y1, x2 + 1, y2 + 1, x1, y2 + 1,
                     color1, color2, color3, color4, alpha, 0.5f, 0.5f, 0.5f, 0.5f);
}

void metalDrawLine(Renderer* renderer, float x1, float y1, float x2, float y2,
                   float width, uint32_t color, float alpha) {
    metalDrawLineColor(renderer, x1, y1, x2, y2, width, color, color, alpha);
}

void metalDrawLineColor(Renderer* renderer, float x1, float y1, float x2, float y2,
                        float width, uint32_t color1, uint32_t color2, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    float dx = x2 - x1, dy = y2 - y1;
    float length = sqrtf(dx * dx + dy * dy);
    if (length <= 0.0001f) return;
    float px = -dy / length * width * 0.5f;
    float py = dx / length * width * 0.5f;
    metalDrawQuadRaw(metal, metal->whiteTexture,
                     x1 + px, y1 + py, x1 - px, y1 - py, x2 - px, y2 - py, x2 + px, y2 + py,
                     color1, color1, color2, color2, alpha, 0.5f, 0.5f, 0.5f, 0.5f);
}

void metalDrawTriangle(Renderer* renderer, float x1, float y1, float x2, float y2, float x3, float y3,
                       uint32_t color1, uint32_t color2, uint32_t color3, float alpha, bool outline) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (outline) {
        metalDrawLine(renderer, x1, y1, x2, y2, 1.0f, color1, alpha);
        metalDrawLine(renderer, x2, y2, x3, y3, 1.0f, color2, alpha);
        metalDrawLine(renderer, x3, y3, x1, y1, 1.0f, color3, alpha);
        return;
    }
    MetalVertex vertices[3];
    vertices[0].position = (vector_float2){x1, y1};
    vertices[1].position = (vector_float2){x2, y2};
    vertices[2].position = (vector_float2){x3, y3};
    vertices[0].uv = vertices[1].uv = vertices[2].uv = (vector_float2){0.5f, 0.5f};
    vertices[0].color = metalColorToFloat4(color1, alpha);
    vertices[1].color = metalColorToFloat4(color2, alpha);
    vertices[2].color = metalColorToFloat4(color3, alpha);
    metalDrawTexturedVertices(metal, vertices, 3, metal->whiteTexture);
}

static void metalDrawTextCommon(Renderer* renderer, const char* text, float x, float y,
                                float xscale, float yscale, float angleDeg, float lineSeparation,
                                uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    DataWin* dataWin = renderer->dataWin;
    if (renderer->drawFont < 0 || (uint32_t)renderer->drawFont >= dataWin->font.count || text == nullptr)
        return;

    Font* font = &dataWin->font.fonts[renderer->drawFont];
    TexturePageItem* tpag = nullptr;
    uint32_t pageId = 0;
    Sprite* spriteFont = nullptr;
    if (font->isSpriteFont) {
        if (font->spriteIndex < 0 || (uint32_t)font->spriteIndex >= dataWin->sprt.count) return;
        spriteFont = &dataWin->sprt.sprites[font->spriteIndex];
    } else {
        if (font->tpagIndex < 0 || !metalResolveTpag(metal, font->tpagIndex, &tpag, &pageId) ||
            !metalEnsureTextureLoaded(metal, pageId)) return;
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
                float invW = 1.0f / (float)metal->textureWidths[glyphPageId];
                float invH = 1.0f / (float)metal->textureHeights[glyphPageId];
                float localX0 = cursorX + glyph->offset;
                float localY0 = cursorY;
                if (spriteFont != nullptr)
                    localY0 += (float)(int32_t)glyphTpag->targetY - (float)font->spriteOriginYAdjust;
                float localX1 = localX0 + glyph->sourceWidth;
                float localY1 = localY0 + glyph->sourceHeight;
                float gx0, gy0, gx1, gy1, gx2, gy2, gx3, gy3;
                Matrix4f_transformPoint(&transform, localX0, localY0, &gx0, &gy0);
                Matrix4f_transformPoint(&transform, localX1, localY0, &gx1, &gy1);
                Matrix4f_transformPoint(&transform, localX1, localY1, &gx2, &gy2);
                Matrix4f_transformPoint(&transform, localX0, localY1, &gx3, &gy3);
                metalDrawQuadRaw(metal, metal->textures[glyphPageId], gx0, gy0, gx1, gy1, gx2, gy2, gx3, gy3,
                                 color, color, color, color, alpha,
                                 (glyphTpag->sourceX + glyph->sourceX) * invW,
                                 (glyphTpag->sourceY + glyph->sourceY) * invH,
                                 (glyphTpag->sourceX + glyph->sourceX + glyph->sourceWidth) * invW,
                                 (glyphTpag->sourceY + glyph->sourceY + glyph->sourceHeight) * invH);
                cursorX += glyph->shift;
            }
        }
        cursorY += lineStride;
        lineStart = lineEnd < textLen ? TextUtils_skipNewline(text, lineEnd, textLen) : lineEnd;
    }
}

void metalDrawText(Renderer* renderer, const char* text, float x, float y, float xscale, float yscale,
                   float angleDeg, float lineSeparation) {
    metalDrawTextCommon(renderer, text, x, y, xscale, yscale, angleDeg, lineSeparation,
                        renderer->drawColor, renderer->drawAlpha);
}

void metalDrawTextColor(Renderer* renderer, const char* text, float x, float y, float xscale, float yscale,
                        float angleDeg, int32_t c1, MAYBE_UNUSED int32_t c2, MAYBE_UNUSED int32_t c3,
                        MAYBE_UNUSED int32_t c4, float alpha, float lineSeparation) {
    metalDrawTextCommon(renderer, text, x, y, xscale, yscale, angleDeg, lineSeparation, (uint32_t)c1, alpha);
}

void metalClearScreen(Renderer* renderer, uint32_t color, float alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (metal->currentTarget == nil && metal->currentSurfaceId < 0) return;
    MTLClearColor clear = MTLClearColorMake(BGR_R(color) / 255.0, BGR_G(color) / 255.0,
                                            BGR_B(color) / 255.0, alpha);
    int32_t surfaceId = metal->currentSurfaceId;
    id<MTLTexture> target = metal->currentTarget;
    metalEndEncoder(metal);
    if (surfaceId >= 0 && (uint32_t)surfaceId < metal->surfaceCount && metal->surfaceAlive[surfaceId]) {
        metalBindSurfaceTarget(metal, surfaceId, true, clear);
        // Keep full-surface viewport after clear; do not re-apply room CPort (may exceed surface size).
    } else if (target != nil) {
        metal->currentTarget = target;
        metalEnsureEncoder(metal, true, clear);
    }
}
