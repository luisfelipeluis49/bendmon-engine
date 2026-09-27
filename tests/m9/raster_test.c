#include "../../platform/presentation/raster.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static uint32_t frame[128 * 128];
static float depth[128 * 128];

static M9Canvas canvas(void) {
    return (M9Canvas){frame, depth, 128, 128, 128 * 4};
}

static M9Camera camera(void) {
    return (M9Camera){{0, 0, 0}, {0, 0, 1}, 60, 0.1f, 100};
}

static uint32_t pixel(unsigned x, unsigned y) {
    return frame[y * 128 + x];
}

static void write_ppm(const char *path) {
    FILE *file = fopen(path, "wb");
    assert(file);
    fprintf(file, "P6\n128 128\n255\n");
    for (size_t i = 0; i < 128 * 128; ++i) {
        uint32_t rgba = frame[i];
        uint8_t rgb[] = {rgba & 255u, (rgba >> 8) & 255u,
                         (rgba >> 16) & 255u};
        assert(fwrite(rgb, 1, 3, file) == 3);
    }
    assert(fclose(file) == 0);
}

int main(int argc, char **argv) {
    M9Terrain backdrop[] = {
        {{-3, -2, 8}, {3, -2, 8}, {0, 3, 8}, M9_RGBA(0, 0, 255, 255)}
    };
    uint8_t sprite_rgba[] = {255, 0, 0, 255};
    M9Image image = {sprite_rgba, 1, 1, 4};
    M9Billboard sprites[] = {
        {{0, 0, 10}, 2, 2, &image, M9_RGBA(255, 255, 255, 255)},
        {{0, 0, 5}, 2, 2, &image, M9_RGBA(255, 255, 255, 255)}
    };
    M9Pulse pulse[] = {{{1.4f, 0.2f, 4}, 0.55f, M9_RGBA(255, 215, 0, 200)}};
    M9Scene scene = {camera(), M9_RGBA(15, 25, 35, 255), backdrop, 1,
                     sprites, 2, pulse, 1, NULL};
    M9Canvas target = canvas();
    assert(m9_render_scene(&scene, &target));
    assert(pixel(64, 45) == M9_RGBA(255, 0, 0, 255));
    assert(fabsf(depth[45 * 128 + 64] - 5.0f) < 0.001f);
    assert(pixel(0, 0) == scene.background);
    assert(pixel(93, 60) != scene.background);
    if (argc == 2) write_ppm(argv[1]);

    uint8_t background_rgba[] = {20, 60, 100, 255};
    M9Image background = {background_rgba, 1, 1, 4};
    scene.terrain_count = scene.billboard_count = scene.pulse_count = 0;
    scene.background_image = &background;
    assert(m9_render_scene(&scene, &target));
    assert(pixel(0, 0) == M9_RGBA(20, 60, 100, 255));
    scene.terrain_count = scene.billboard_count = scene.pulse_count = 1;
    scene.background_image = NULL;

    M9Terrain clipped[] = {
        {{-1, -1, 0.5f}, {1, -1, 2}, {0, 1, 2}, M9_RGBA(40, 180, 90, 255)}
    };
    scene.camera.near_plane = 1;
    scene.terrain = clipped;
    scene.billboard_count = scene.pulse_count = 0;
    assert(m9_render_scene(&scene, &target));
    assert(pixel(64, 64) != scene.background);

    uint8_t translucent[] = {255, 0, 0, 128};
    uint8_t solid[] = {0, 0, 255, 255};
    M9Image red = {translucent, 1, 1, 4};
    M9Image blue = {solid, 1, 1, 4};
    M9Billboard layered[] = {
        {{0, 0, 5}, 2, 2, &red, M9_RGBA(255, 255, 255, 255)},
        {{0, 0, 6}, 2, 2, &blue, M9_RGBA(255, 255, 255, 255)}
    };
    scene.terrain_count = 0;
    scene.billboards = layered;
    scene.billboard_count = 2;
    assert(m9_render_scene(&scene, &target));
    assert((pixel(64, 45) & 255u) > 100u);
    assert(((pixel(64, 45) >> 16) & 255u) > 100u);
    scene.billboards = sprites;
    scene.terrain = backdrop;
    scene.terrain_count = scene.billboard_count = scene.pulse_count = 1;

    scene.camera.vertical_fov_degrees = NAN;
    assert(!m9_render_scene(&scene, &target));
    scene.camera = camera();
    sprites[0].foot.x = NAN;
    assert(!m9_render_scene(&scene, &target));
    sprites[0].foot.x = 0;
    target.pitch = 4;
    assert(!m9_render_scene(&scene, &target));
    puts("M9 raster depth, VFX and bounds pass");
    return 0;
}
