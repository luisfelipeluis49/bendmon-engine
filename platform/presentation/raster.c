#include "raster.h"

#include <math.h>
#include <stdbool.h>

typedef struct { float x, y, z; } Projected;
typedef struct { M9Vec3 right, up, forward; float scale; } CameraBasis;

static M9Vec3 subtract(M9Vec3 a, M9Vec3 b) {
    return (M9Vec3){a.x - b.x, a.y - b.y, a.z - b.z};
}

static M9Vec3 cross(M9Vec3 a, M9Vec3 b) {
    return (M9Vec3){a.y * b.z - a.z * b.y,
                    a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x};
}

static float dot(M9Vec3 a, M9Vec3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

static bool normalize(M9Vec3 *value) {
    float length = sqrtf(dot(*value, *value));
    if (!isfinite(length) || length < 0.00001f) return false;
    value->x /= length; value->y /= length; value->z /= length;
    return true;
}

static bool camera_basis(const M9Camera *camera, unsigned height,
                         CameraBasis *basis) {
    if (!isfinite(camera->vertical_fov_degrees) ||
        camera->vertical_fov_degrees < 30.0f ||
        camera->vertical_fov_degrees > 90.0f ||
        !isfinite(camera->near_plane) || camera->near_plane <= 0.0f ||
        !isfinite(camera->far_plane) ||
        camera->far_plane <= camera->near_plane) return false;
    basis->forward = subtract(camera->target, camera->position);
    if (!normalize(&basis->forward)) return false;
    basis->right = cross((M9Vec3){0, 1, 0}, basis->forward);
    if (!normalize(&basis->right)) return false;
    basis->up = cross(basis->forward, basis->right);
    basis->scale = (float)height * 0.5f /
        tanf(camera->vertical_fov_degrees * 0.00872664626f);
    return isfinite(basis->scale);
}

static bool project(const M9Camera *camera, CameraBasis basis,
                    M9Canvas *canvas, M9Vec3 point, Projected *out) {
    M9Vec3 delta = subtract(point, camera->position);
    float z = dot(delta, basis.forward);
    if (!isfinite(z) || z < camera->near_plane ||
        z > camera->far_plane) return false;
    out->x = (float)canvas->width * 0.5f + dot(delta, basis.right) * basis.scale / z;
    out->y = (float)canvas->height * 0.5f - dot(delta, basis.up) * basis.scale / z;
    out->z = z;
    return isfinite(out->x) && isfinite(out->y);
}

static uint8_t channel(uint32_t rgba, unsigned shift) {
    return (uint8_t)(rgba >> shift);
}

static uint32_t shade(uint32_t rgba, float light) {
    return M9_RGBA((uint8_t)(channel(rgba, 0) * light),
                   (uint8_t)(channel(rgba, 8) * light),
                   (uint8_t)(channel(rgba, 16) * light), channel(rgba, 24));
}

static float terrain_light(M9Terrain triangle) {
    M9Vec3 normal = cross(subtract(triangle.b, triangle.a),
                          subtract(triangle.c, triangle.a));
    M9Vec3 sun = {-0.35f, 0.85f, 0.4f};
    if (!normalize(&normal) || !normalize(&sun)) return 0.3f;
    return fminf(1.0f, 0.3f + 0.7f * fabsf(dot(normal, sun)));
}

static float edge(Projected a, Projected b, float x, float y) {
    return (x - a.x) * (b.y - a.y) - (y - a.y) * (b.x - a.x);
}

static int pixel_bound(float value, int high) {
    if (value <= 0.0f) return 0;
    if (value >= (float)high) return high;
    return (int)value;
}

static void paint_triangle(M9Canvas *canvas, Projected a, Projected b,
                           Projected c, uint32_t color) {
    float area = edge(a, b, c.x, c.y);
    if (fabsf(area) < 0.00001f) return;
    float left = fminf(a.x, fminf(b.x, c.x));
    float top = fminf(a.y, fminf(b.y, c.y));
    float right = fmaxf(a.x, fmaxf(b.x, c.x));
    float bottom = fmaxf(a.y, fmaxf(b.y, c.y));
    if (right < 0 || bottom < 0 || left >= canvas->width ||
        top >= canvas->height) return;
    int x0 = pixel_bound(floorf(left), (int)canvas->width - 1);
    int y0 = pixel_bound(floorf(top), (int)canvas->height - 1);
    int x1 = pixel_bound(ceilf(right), (int)canvas->width - 1);
    int y1 = pixel_bound(ceilf(bottom), (int)canvas->height - 1);
    for (int y = y0; y <= y1; ++y) for (int x = x0; x <= x1; ++x) {
        float w0 = edge(b, c, x + 0.5f, y + 0.5f) / area;
        float w1 = edge(c, a, x + 0.5f, y + 0.5f) / area;
        float w2 = 1.0f - w0 - w1;
        if (w0 < 0.0f || w1 < 0.0f || w2 < 0.0f) continue;
        float reciprocal = w0 / a.z + w1 / b.z + w2 / c.z;
        float depth = 1.0f / reciprocal;
        size_t index = (size_t)y * canvas->width + (size_t)x;
        if (depth < canvas->depth[index]) {
            canvas->depth[index] = depth;
            canvas->rgba[(size_t)y * (canvas->pitch / 4) + (size_t)x] = color;
        }
    }
}

static M9Vec3 interpolate(M9Vec3 a, M9Vec3 b, float fraction) {
    return (M9Vec3){a.x + (b.x - a.x) * fraction,
                    a.y + (b.y - a.y) * fraction,
                    a.z + (b.z - a.z) * fraction};
}

static size_t clip_depth(const M9Camera *camera, CameraBasis basis,
                         const M9Vec3 *input, size_t count, M9Vec3 *output,
                         float plane, bool keep_far) {
    size_t written = 0;
    for (size_t i = 0; i < count; ++i) {
        M9Vec3 a = input[i], b = input[(i + 1) % count];
        float da = dot(subtract(a, camera->position), basis.forward);
        float db = dot(subtract(b, camera->position), basis.forward);
        bool a_inside = keep_far ? da <= plane : da >= plane;
        bool b_inside = keep_far ? db <= plane : db >= plane;
        if (a_inside) output[written++] = a;
        if (a_inside != b_inside && da != db) {
            float fraction = (plane - da) / (db - da);
            output[written++] = interpolate(a, b, fraction);
        }
    }
    return written;
}

static void render_terrain(const M9Scene *scene, CameraBasis basis,
                           M9Canvas *canvas) {
    for (size_t i = 0; i < scene->terrain_count; ++i) {
        M9Terrain triangle = scene->terrain[i];
        M9Vec3 source[6] = {triangle.a, triangle.b, triangle.c}, clipped[6];
        size_t count = clip_depth(&scene->camera, basis, source, 3, clipped,
                                  scene->camera.near_plane, false);
        if (count < 3) continue;
        count = clip_depth(&scene->camera, basis, clipped, count, source,
                           scene->camera.far_plane, true);
        if (count < 3) continue;
        Projected first, previous;
        if (!project(&scene->camera, basis, canvas, source[0], &first)) continue;
        if (!project(&scene->camera, basis, canvas, source[1], &previous)) continue;
        uint32_t color = shade(triangle.rgba, terrain_light(triangle));
        for (size_t vertex = 2; vertex < count; ++vertex) {
            Projected next;
            if (!project(&scene->camera, basis, canvas, source[vertex], &next)) break;
            paint_triangle(canvas, first, previous, next, color);
            previous = next;
        }
    }
}

static uint32_t blend(uint32_t back, uint32_t front) {
    unsigned alpha = channel(front, 24);
    if (alpha == 255) return front;
    unsigned inverse = 255 - alpha;
    unsigned r = (channel(front, 0) * alpha + channel(back, 0) * inverse) / 255;
    unsigned g = (channel(front, 8) * alpha + channel(back, 8) * inverse) / 255;
    unsigned b = (channel(front, 16) * alpha + channel(back, 16) * inverse) / 255;
    return M9_RGBA(r, g, b, 255);
}

static uint32_t sample(const M9Billboard *sprite, float u, float v) {
    if (!sprite->image) return sprite->tint;
    const M9Image *image = sprite->image;
    unsigned x = (unsigned)(u * image->width);
    unsigned y = (unsigned)(v * image->height);
    if (x >= image->width) x = image->width - 1;
    if (y >= image->height) y = image->height - 1;
    const uint8_t *pixel = image->rgba + (size_t)y * image->pitch + 4u * x;
    return M9_RGBA(pixel[0] * channel(sprite->tint, 0) / 255,
                   pixel[1] * channel(sprite->tint, 8) / 255,
                   pixel[2] * channel(sprite->tint, 16) / 255,
                   pixel[3] * channel(sprite->tint, 24) / 255);
}

static void paint_billboard(M9Canvas *canvas, Projected foot,
                            const M9Billboard *sprite, float scale) {
    float tall = sprite->height * scale / foot.z;
    float wide = sprite->width * scale / foot.z;
    if (!isfinite(tall) || !isfinite(wide) || tall <= 0 || wide <= 0) return;
    float left = foot.x - wide * 0.5f, top = foot.y - tall;
    if (left + wide < 0 || foot.y < 0 || left >= canvas->width ||
        top >= canvas->height) return;
    int x0 = pixel_bound(floorf(left), (int)canvas->width - 1);
    int y0 = pixel_bound(floorf(top), (int)canvas->height - 1);
    int x1 = pixel_bound(ceilf(left + wide), (int)canvas->width - 1);
    int y1 = pixel_bound(ceilf(foot.y), (int)canvas->height - 1);
    for (int y = y0; y <= y1; ++y) for (int x = x0; x <= x1; ++x) {
        size_t index = (size_t)y * canvas->width + (size_t)x;
        if (foot.z >= canvas->depth[index]) continue;
        float u = (x + 0.5f - left) / wide, v = (y + 0.5f - top) / tall;
        if (u < 0 || u >= 1 || v < 0 || v >= 1) continue;
        uint32_t color = sample(sprite, u, v);
        if (!channel(color, 24)) continue;
        size_t pixel = (size_t)y * (canvas->pitch / 4) + (size_t)x;
        canvas->rgba[pixel] = blend(canvas->rgba[pixel], color);
        canvas->depth[index] = foot.z;
    }
}

static void render_billboards(const M9Scene *scene, CameraBasis basis,
                              M9Canvas *canvas) {
    Projected positions[M9_MAX_BILLBOARDS];
    size_t order[M9_MAX_BILLBOARDS], count = 0;
    for (size_t i = 0; i < scene->billboard_count; ++i) {
        const M9Billboard *sprite = &scene->billboards[i];
        Projected foot;
        if (!project(&scene->camera, basis, canvas, sprite->foot, &foot)) continue;
        positions[i] = foot;
        size_t at = count++;
        while (at && positions[order[at - 1]].z < foot.z) {
            order[at] = order[at - 1];
            --at;
        }
        order[at] = i;
    }
    for (size_t i = 0; i < count; ++i) {
        size_t index = order[i];
        paint_billboard(canvas, positions[index], &scene->billboards[index],
                        basis.scale);
    }
}

static void render_pulses(const M9Scene *scene, CameraBasis basis,
                          M9Canvas *canvas) {
    for (size_t i = 0; i < scene->pulse_count; ++i) {
        const M9Pulse *pulse = &scene->pulses[i];
        Projected center;
        if (!project(&scene->camera, basis, canvas, pulse->center, &center)) continue;
        float radius = pulse->radius * basis.scale / center.z;
        if (!isfinite(radius) || radius <= 0) continue;
        if (center.x + radius < 0 || center.y + radius < 0 ||
            center.x - radius >= canvas->width ||
            center.y - radius >= canvas->height) continue;
        int x0 = pixel_bound(floorf(center.x - radius), (int)canvas->width - 1);
        int y0 = pixel_bound(floorf(center.y - radius), (int)canvas->height - 1);
        int x1 = pixel_bound(ceilf(center.x + radius), (int)canvas->width - 1);
        int y1 = pixel_bound(ceilf(center.y + radius), (int)canvas->height - 1);
        for (int y = y0; y <= y1; ++y) for (int x = x0; x <= x1; ++x) {
            float dx = (x + 0.5f - center.x) / radius;
            float dy = (y + 0.5f - center.y) / radius;
            float distance = dx * dx + dy * dy;
            size_t index = (size_t)y * canvas->width + (size_t)x;
            if (distance >= 1.0f || center.z > canvas->depth[index]) continue;
            uint32_t color = pulse->rgba;
            unsigned alpha = (unsigned)(channel(color, 24) * (1.0f - distance));
            color = (color & 0x00ffffffu) | ((uint32_t)alpha << 24);
            size_t pixel = (size_t)y * (canvas->pitch / 4) + (size_t)x;
            canvas->rgba[pixel] = blend(canvas->rgba[pixel], color);
        }
    }
}

static bool valid_scene(const M9Scene *scene, const M9Canvas *canvas) {
    if (!scene || !canvas || !canvas->rgba || !canvas->depth ||
        !canvas->width || !canvas->height || canvas->width > 1920 ||
        canvas->height > 1080 || canvas->pitch < canvas->width * 4u ||
        canvas->pitch % 4u || scene->terrain_count > M9_MAX_TERRAIN ||
        scene->billboard_count > M9_MAX_BILLBOARDS ||
        scene->pulse_count > M9_MAX_PULSES) return false;
    if ((scene->terrain_count && !scene->terrain) ||
        (scene->billboard_count && !scene->billboards) ||
        (scene->pulse_count && !scene->pulses)) return false;
    if (scene->background_image && (!scene->background_image->rgba ||
        !scene->background_image->width || !scene->background_image->height ||
        scene->background_image->width > 256 ||
        scene->background_image->height > 256 ||
        scene->background_image->pitch < scene->background_image->width * 4u))
        return false;
    for (size_t i = 0; i < scene->terrain_count; ++i) {
        M9Terrain terrain = scene->terrain[i];
        if (!isfinite(terrain.a.x) || !isfinite(terrain.a.y) ||
            !isfinite(terrain.a.z) || !isfinite(terrain.b.x) ||
            !isfinite(terrain.b.y) || !isfinite(terrain.b.z) ||
            !isfinite(terrain.c.x) || !isfinite(terrain.c.y) ||
            !isfinite(terrain.c.z) || fabsf(terrain.a.x) > 512 ||
            fabsf(terrain.a.y) > 512 || fabsf(terrain.a.z) > 512 ||
            fabsf(terrain.b.x) > 512 || fabsf(terrain.b.y) > 512 ||
            fabsf(terrain.b.z) > 512 || fabsf(terrain.c.x) > 512 ||
            fabsf(terrain.c.y) > 512 || fabsf(terrain.c.z) > 512) return false;
    }
    for (size_t i = 0; i < scene->billboard_count; ++i) {
        const M9Billboard *sprite = &scene->billboards[i];
        if (!isfinite(sprite->width) || !isfinite(sprite->height) ||
            sprite->width <= 0 || sprite->height <= 0 ||
            sprite->width > 64 || sprite->height > 64 ||
            !isfinite(sprite->foot.x) || !isfinite(sprite->foot.y) ||
            !isfinite(sprite->foot.z)) return false;
        if (sprite->image && (!sprite->image->rgba || !sprite->image->width ||
            !sprite->image->height || sprite->image->width > 256 ||
            sprite->image->height > 256 ||
            sprite->image->pitch < sprite->image->width * 4u)) return false;
    }
    for (size_t i = 0; i < scene->pulse_count; ++i) {
        M9Pulse pulse = scene->pulses[i];
        if (!isfinite(pulse.center.x) || !isfinite(pulse.center.y) ||
            !isfinite(pulse.center.z) || !isfinite(pulse.radius) ||
            pulse.radius <= 0 || pulse.radius > 64) return false;
    }
    return true;
}

int m9_render_scene(const M9Scene *scene, M9Canvas *canvas) {
    if (!valid_scene(scene, canvas)) return 0;
    CameraBasis basis;
    if (!camera_basis(&scene->camera, canvas->height, &basis)) return 0;
    for (unsigned y = 0; y < canvas->height; ++y) {
        for (unsigned x = 0; x < canvas->width; ++x) {
            size_t index = (size_t)y * canvas->width + x;
            uint32_t color = scene->background;
            if (scene->background_image) {
                const M9Image *image = scene->background_image;
                unsigned sx = (unsigned)((uint64_t)x * image->width / canvas->width);
                unsigned sy = (unsigned)((uint64_t)y * image->height / canvas->height);
                const uint8_t *pixel = image->rgba + (size_t)sy * image->pitch + sx * 4u;
                color = blend(color, M9_RGBA(pixel[0], pixel[1], pixel[2], pixel[3]));
            }
            canvas->rgba[(size_t)y * (canvas->pitch / 4) + x] = color;
            canvas->depth[index] = INFINITY;
        }
    }
    render_terrain(scene, basis, canvas);
    render_billboards(scene, basis, canvas);
    render_pulses(scene, basis, canvas);
    return 1;
}
