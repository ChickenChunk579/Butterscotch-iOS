#ifndef _BS_METAL_RENDERER_H_
#define _BS_METAL_RENDERER_H_

#include "renderer.h"

Renderer* MetalRenderer_create(void);
void MetalRenderer_presentFrame(void);
void MetalRenderer_waitForPresentedFrame(void);

#endif