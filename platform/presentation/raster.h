#ifndef BENDMON_M9_RASTER_H
#define BENDMON_M9_RASTER_H

#include <stddef.h>
#include <stdint.h>

/* RGBA32 is byte ordered R,G,B,A on the supported little-endian host. */
#define M9_RGBA(r, g, b, a) ((uint32_t)(r) | ((uint32_t)(g) << 8) | \
                            ((uint32_t)(b) << 16) | ((uint32_t)(a) << 24))
#define M9_MAX_TERRAIN 256u
#define M9_MAX_BILLBOARDS 64u
#define M9_MAX_PULSES 64u

typedef struct { float x, y, z; } M9Vec3;
typedef struct { M9Vec3 a, b, c; uint32_t rgba; } M9Terrain;
typedef struct {
    const uint8_t *rgba;
    unsigned width, height, pitch;
} M9Image;
typedef struct {
    M9Vec3 foot;
    float width, height;
    const M9Image *image;
    uint32_t tint;
} M9Billboard;
typedef struct {
    M9Vec3 center;
    float radius;
    uint32_t rgba;
} M9Pulse;
typedef struct {
    M9Vec3 position, target;
    float vertical_fov_degrees, near_plane, far_plane;
} M9Camera;
typedef struct {
    M9Camera camera;
    uint32_t background;
    const M9Terrain *terrain;
    size_t terrain_count;
    const M9Billboard *billboards;
    size_t billboard_count;
    const M9Pulse *pulses;
    size_t pulse_count;
    const M9Image *background_image;
} M9Scene;
typedef struct {
    uint32_t *rgba;
    float *depth;
    unsigned width, height, pitch;
} M9Canvas;

/* All buffers are caller-owned. Returns zero for invalid bounds or geometry. */
int m9_render_scene(const M9Scene *scene, M9Canvas *canvas);

#endif
