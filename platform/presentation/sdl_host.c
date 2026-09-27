#include "sdl_host.h"
#include "raster.h"

#include <SDL3/SDL.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LOGICAL_WIDTH 1280
#define LOGICAL_HEIGHT 720
#define MAX_FRAME_WIDTH 1920u
#define MAX_FRAME_HEIGHT 1080u
#define MAX_AUDIO_BYTES (10u * 44100u * 2u * 2u)
#define MAX_SEQUENCE_FRAMES 32u

static bool load_frame(const char *path, unsigned width, unsigned height,
                       uint32_t **pixels);

static M9HostCommand map_event(const SDL_Event *event) {
    if (event->type == SDL_EVENT_KEY_DOWN) {
        switch (event->key.key) {
            case SDLK_UP: case SDLK_W: return M9_COMMAND_NORTH;
            case SDLK_RIGHT: case SDLK_D: return M9_COMMAND_EAST;
            case SDLK_DOWN: case SDLK_S: return M9_COMMAND_SOUTH;
            case SDLK_LEFT: case SDLK_A: return M9_COMMAND_WEST;
            case SDLK_RETURN: case SDLK_SPACE: return M9_COMMAND_CONFIRM;
            case SDLK_ESCAPE: return M9_COMMAND_CANCEL;
            default: return M9_COMMAND_NONE;
        }
    }
    if (event->type == SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
        switch (event->gbutton.button) {
            case SDL_GAMEPAD_BUTTON_DPAD_UP: return M9_COMMAND_NORTH;
            case SDL_GAMEPAD_BUTTON_DPAD_RIGHT: return M9_COMMAND_EAST;
            case SDL_GAMEPAD_BUTTON_DPAD_DOWN: return M9_COMMAND_SOUTH;
            case SDL_GAMEPAD_BUTTON_DPAD_LEFT: return M9_COMMAND_WEST;
            case SDL_GAMEPAD_BUTTON_SOUTH: return M9_COMMAND_CONFIRM;
            case SDL_GAMEPAD_BUTTON_EAST: return M9_COMMAND_CANCEL;
            default: return M9_COMMAND_NONE;
        }
    }
    return M9_COMMAND_NONE;
}

static bool play_smoke_tone(SDL_AudioStream *stream) {
    enum { FRAMES = 4800 };
    float samples[FRAMES * 2];
    for (unsigned frame = 0; frame < FRAMES; ++frame) {
        float value = 0.12f * sinf((float)frame * 0.057595865f);
        samples[frame * 2] = value;
        samples[frame * 2 + 1] = value;
    }
    return SDL_PutAudioStreamData(stream, samples, sizeof(samples)) &&
           SDL_ResumeAudioStreamDevice(stream);
}

static int fail_sdl(const char *operation) {
    fprintf(stderr, "SDL3 %s failed: %s\n", operation, SDL_GetError());
    return 1;
}

int m9_sdl_present(const uint32_t *rgba, unsigned width, unsigned height,
                   unsigned pitch, const uint8_t *pcm_s16le, size_t pcm_bytes,
                   unsigned pcm_channels, unsigned pcm_rate,
                   unsigned duration_ms, int self_test,
                   const char *const *sequence_paths, size_t sequence_count,
                   unsigned sequence_interval_ms, size_t cue_frame_index,
                   M9CommandSink command_sink, void *command_context) {
    if (!rgba || !width || !height || width > MAX_FRAME_WIDTH ||
        height > MAX_FRAME_HEIGHT || pitch < width * 4u || pitch % 4u) {
        fprintf(stderr, "invalid RGBA frame: %ux%u pitch=%u\n", width, height, pitch);
        return 1;
    }
    if (pcm_bytes && (!pcm_s16le || (pcm_channels != 1 && pcm_channels != 2) ||
        (pcm_rate != 22050 && pcm_rate != 44100) ||
        pcm_bytes > MAX_AUDIO_BYTES || pcm_bytes % (pcm_channels * 2u))) {
        fprintf(stderr, "invalid bounded PCM cue: bytes=%zu channels=%u rate=%u\n",
            pcm_bytes, pcm_channels, pcm_rate);
        return 1;
    }
    if ((sequence_count && (!sequence_paths || sequence_count > MAX_SEQUENCE_FRAMES ||
         sequence_interval_ms < 16 || sequence_interval_ms > 60000)) ||
        (!sequence_count && sequence_interval_ms) ||
        (cue_frame_index && (!pcm_bytes || !sequence_count ||
                             cue_frame_index >= sequence_count))) {
        fprintf(stderr, "invalid frame sequence: count=%zu interval=%u ms\n",
            sequence_count, sequence_interval_ms);
        return 1;
    }
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD))
        return fail_sdl("initialization");
    int result = 1;
    SDL_Window *window = SDL_CreateWindow("Bend M9 SDL3 host smoke",
        LOGICAL_WIDTH, LOGICAL_HEIGHT, SDL_WINDOW_RESIZABLE);
    if (!window) { fail_sdl("window creation"); goto done; }
    SDL_Renderer *renderer = SDL_CreateRenderer(window, "software");
    if (!renderer) { fail_sdl("software renderer creation"); goto destroy_window; }
    if (!SDL_SetRenderLogicalPresentation(renderer, LOGICAL_WIDTH, LOGICAL_HEIGHT,
            SDL_LOGICAL_PRESENTATION_LETTERBOX)) {
        fail_sdl("logical presentation setup"); goto destroy_renderer;
    }
    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32,
        SDL_TEXTUREACCESS_STREAMING, (int)width, (int)height);
    if (!texture) { fail_sdl("texture creation"); goto destroy_renderer; }
    if (!SDL_UpdateTexture(texture, NULL, rgba, (int)pitch) ||
        !SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)) {
        fail_sdl("frame upload"); goto destroy_texture;
    }
    const char *audio_status = "unavailable";
    SDL_AudioStream *audio = NULL;
    bool cue_started = false;
    uint64_t cue_started_at = 0;
    if (SDL_InitSubSystem(SDL_INIT_AUDIO)) {
        SDL_AudioSpec audio_spec = pcm_bytes
            ? (SDL_AudioSpec){SDL_AUDIO_S16, (int)pcm_channels, (int)pcm_rate}
            : (SDL_AudioSpec){SDL_AUDIO_F32, 2, 48000};
        audio = SDL_OpenAudioDeviceStream(
            SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio_spec, NULL, NULL);
        if (audio) {
            bool delayed_cue = pcm_bytes && sequence_count && cue_frame_index;
            bool played = delayed_cue || (pcm_bytes
                ? SDL_PutAudioStreamData(audio, pcm_s16le, (int)pcm_bytes) &&
                  SDL_ResumeAudioStreamDevice(audio)
                : play_smoke_tone(audio));
            if (played) {
                audio_status = delayed_cue ? "pending-cue" :
                    (pcm_bytes ? "cue" : "smoke-tone");
                if (pcm_bytes && !delayed_cue) {
                    cue_started = true;
                    cue_started_at = SDL_GetTicks();
                }
            } else {
                fprintf(stderr, "SDL3 audio playback unavailable: %s\n", SDL_GetError());
                SDL_DestroyAudioStream(audio);
                audio = NULL;
            }
        } else {
            fprintf(stderr, "SDL3 audio device unavailable: %s\n", SDL_GetError());
        }
    } else {
        fprintf(stderr, "SDL3 audio subsystem unavailable: %s\n", SDL_GetError());
    }

    SDL_Gamepad *gamepads[16] = {0};
    int gamepad_count = 0;
    SDL_JoystickID *gamepad_ids = SDL_GetGamepads(&gamepad_count);
    if (gamepad_ids) {
        for (int index = 0; index < gamepad_count && index < 16; ++index)
            gamepads[index] = SDL_OpenGamepad(gamepad_ids[index]);
        SDL_free(gamepad_ids);
    }
    uint32_t *sequence_pixels = NULL;
    M9HostCommand command = M9_COMMAND_NONE;
    unsigned input_events = 0;
    if (self_test) {
        SDL_Event synthetic = {0};
        synthetic.type = SDL_EVENT_KEY_DOWN;
        synthetic.key.key = SDLK_UP;
        if (!SDL_PushEvent(&synthetic)) { fail_sdl("input event injection"); goto destroy_audio; }
        synthetic = (SDL_Event){0};
        synthetic.type = SDL_EVENT_GAMEPAD_BUTTON_DOWN;
        synthetic.gbutton.button = SDL_GAMEPAD_BUTTON_EAST;
        if (!SDL_PushEvent(&synthetic)) { fail_sdl("gamepad event injection"); goto destroy_audio; }
    }
    uint64_t started = SDL_GetTicks();
    bool running = true;
    size_t sequence_index = 0;
#ifdef M9_TESTING
    bool injected_slow_frame = false;
#endif
    if (sequence_count) {
        printf("frame-index=0\n");
        fflush(stdout);
    }
    while (running && (sequence_count || !duration_ms ||
                       SDL_GetTicks() - started < duration_ms)) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) running = false;
            if (event.type == SDL_EVENT_GAMEPAD_ADDED) {
                for (unsigned index = 0; index < 16; ++index) {
                    if (!gamepads[index]) {
                        gamepads[index] = SDL_OpenGamepad(event.gdevice.which);
                        break;
                    }
                }
            } else if (event.type == SDL_EVENT_GAMEPAD_REMOVED) {
                for (unsigned index = 0; index < 16; ++index) {
                    if (gamepads[index] &&
                        SDL_GetGamepadID(gamepads[index]) == event.gdevice.which) {
                        SDL_CloseGamepad(gamepads[index]);
                        gamepads[index] = NULL;
                        break;
                    }
                }
            }
            M9HostCommand mapped = map_event(&event);
            if (mapped != M9_COMMAND_NONE) {
                command = mapped;
                ++input_events;
                if (command_sink) command_sink(mapped, command_context);
                printf("command=%d\n", mapped);
                fflush(stdout);
            }
        }
        bool sequence_complete = false;
        if (sequence_count) {
            uint64_t elapsed = SDL_GetTicks() - started;
            size_t target_index = (size_t)(elapsed / sequence_interval_ms);
            sequence_complete = target_index >= sequence_count;
            if (sequence_complete) {
                target_index = sequence_count - 1;
                printf("sequence-overrun=1\n");
                fflush(stdout);
            }
            if (target_index > sequence_index) {
                size_t previous_index = sequence_index;
                uint32_t *next_pixels = NULL;
                if (!load_frame(sequence_paths[target_index], width, height,
                        &next_pixels)) {
                    fprintf(stderr, "frame sequence entry %zu is invalid: %s\n",
                        target_index, sequence_paths[target_index]);
                    free(sequence_pixels);
                    goto destroy_audio;
                }
                if (!SDL_UpdateTexture(texture, NULL, next_pixels, (int)pitch)) {
                    fail_sdl("sequence frame upload");
                    free(next_pixels);
                    free(sequence_pixels);
                    goto destroy_audio;
                }
                free(sequence_pixels);
                sequence_pixels = next_pixels;
                sequence_index = target_index;
                printf("frame-index=%zu\n", sequence_index);
                fflush(stdout);
                /* Drop late visual frames, but never drop an event cue crossed
                   during a slow frame or scheduler pause. */
                if (audio && pcm_bytes && previous_index < cue_frame_index &&
                    cue_frame_index <= sequence_index) {
                    if (SDL_PutAudioStreamData(audio, pcm_s16le,
                            (int)pcm_bytes) && SDL_ResumeAudioStreamDevice(audio)) {
                        audio_status = "cue";
                        cue_started = true;
                        cue_started_at = SDL_GetTicks();
                        printf("cue-frame-index=%zu played-at-frame=%zu\n",
                            cue_frame_index, sequence_index);
                        fflush(stdout);
                    } else {
                        fprintf(stderr, "SDL3 cue playback unavailable: %s\n",
                            SDL_GetError());
                        SDL_DestroyAudioStream(audio);
                        audio = NULL;
                        audio_status = "unavailable";
                    }
                }
            }
        }
        if (!SDL_RenderClear(renderer) ||
            !SDL_RenderTexture(renderer, texture, NULL, NULL) ||
            !SDL_RenderPresent(renderer)) {
            fail_sdl("frame presentation"); goto destroy_audio;
        }
        SDL_Delay(16);
        if (sequence_complete) {
            if (audio && pcm_bytes && cue_started) {
                size_t frames = pcm_bytes / (pcm_channels * 2u);
                uint64_t duration = frames * 1000u / pcm_rate + 20u;
                uint64_t elapsed = SDL_GetTicks() - cue_started_at;
                if (elapsed < duration) {
                    printf("cue-tail-ms=%llu\n",
                        (unsigned long long)(duration - elapsed));
                    fflush(stdout);
                    SDL_Delay((uint32_t)(duration - elapsed));
                }
            }
            break;
        }
#ifdef M9_TESTING
        if (sequence_count && !injected_slow_frame &&
            (getenv("M9_TEST_SKIP_FRAME") ||
             getenv("M9_TEST_END_OVERRUN"))) {
            injected_slow_frame = true;
            unsigned skipped = getenv("M9_TEST_END_OVERRUN")
                ? (unsigned)sequence_count + 1u : 2u;
            SDL_Delay(sequence_interval_ms * skipped + 10u);
        }
#endif
    }
    if (self_test && (command != M9_COMMAND_CANCEL || input_events != 2)) {
        fprintf(stderr, "input smoke failed: command=%d events=%u\n", command, input_events);
        goto destroy_audio;
    }
    printf("SDL3 %u.%u.%u software-window=%dx%d frame=%ux%u input=%d audio=%s\n",
        SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION,
        LOGICAL_WIDTH, LOGICAL_HEIGHT, width, height, command,
        audio_status);
    result = 0;

destroy_audio:
    free(sequence_pixels);
    if (audio) SDL_DestroyAudioStream(audio);
    for (unsigned index = 0; index < 16; ++index)
        if (gamepads[index]) SDL_CloseGamepad(gamepads[index]);
destroy_texture:
    SDL_DestroyTexture(texture);
destroy_renderer:
    SDL_DestroyRenderer(renderer);
destroy_window:
    SDL_DestroyWindow(window);
done:
    SDL_Quit();
    return result;
}

static void fixture_scene(M9Scene *scene) {
    static const M9Terrain ground[] = {
        {{-8, -2, 8}, {8, -2, 8}, {8, -2, 24}, M9_RGBA(64, 130, 80, 255)},
        {{-8, -2, 8}, {8, -2, 24}, {-8, -2, 24}, M9_RGBA(52, 110, 68, 255)},
    };
    static const M9Pulse pulse[] = {
        {{1.4f, -0.3f, 5.5f}, 0.65f, M9_RGBA(255, 198, 45, 180)},
    };
    *scene = (M9Scene){
        .camera = {{0, 3.8f, -3.5f}, {0, -0.8f, 10}, 60, 0.1f, 80},
        .background = M9_RGBA(26, 40, 69, 255),
        .terrain = ground, .terrain_count = sizeof(ground) / sizeof(ground[0]),
        .pulses = pulse, .pulse_count = sizeof(pulse) / sizeof(pulse[0]),
        .background_image = NULL,
    };
}

static bool load_frame(const char *path, unsigned width, unsigned height,
                       uint32_t **pixels) {
    if (!width || !height || width > MAX_FRAME_WIDTH || height > MAX_FRAME_HEIGHT)
        return false;
    size_t bytes = (size_t)width * height * 4u;
    FILE *file = fopen(path, "rb");
    if (!file) return false;
    uint32_t *buffer = malloc(bytes);
    bool valid = buffer && fread(buffer, 1, bytes, file) == bytes &&
        fgetc(file) == EOF && !ferror(file);
    fclose(file);
    if (!valid) { free(buffer); return false; }
    *pixels = buffer;
    return true;
}

static bool load_pcm(const char *path, uint8_t **pcm, size_t *pcm_bytes) {
    FILE *file = fopen(path, "rb");
    if (!file) return false;
    bool valid = fseek(file, 0, SEEK_END) == 0;
    long length = valid ? ftell(file) : -1;
    valid = valid && length > 0 && (unsigned long)length <= MAX_AUDIO_BYTES &&
        fseek(file, 0, SEEK_SET) == 0;
    uint8_t *buffer = valid ? malloc((size_t)length) : NULL;
    valid = valid && buffer && fread(buffer, 1, (size_t)length, file) == (size_t)length;
    fclose(file);
    if (!valid) { free(buffer); return false; }
    *pcm = buffer;
    *pcm_bytes = (size_t)length;
    return true;
}

static bool parse_unsigned(const char *text, unsigned *value) {
    char *end = NULL;
    unsigned long parsed = strtoul(text, &end, 10);
    if (!text[0] || !end || *end || parsed > UINT32_MAX) return false;
    *value = (unsigned)parsed;
    return true;
}

static int run_sequence_cue(int argc, char **argv) {
    unsigned width, height, interval_ms, cue_index, channels, rate;
    size_t count = (size_t)argc - 9;
    const char *paths[MAX_SEQUENCE_FRAMES];
    uint32_t *pixels = NULL;
    uint8_t *pcm = NULL;
    size_t pcm_bytes = 0;
    bool valid = count >= 1 && count <= MAX_SEQUENCE_FRAMES &&
        parse_unsigned(argv[2], &width) && parse_unsigned(argv[3], &height) &&
        parse_unsigned(argv[4], &interval_ms) &&
        parse_unsigned(argv[5], &cue_index) &&
        parse_unsigned(argv[7], &channels) && parse_unsigned(argv[8], &rate) &&
        interval_ms >= 16 && interval_ms <= 60000 && cue_index < count;
    for (size_t index = 0; valid && index < count; ++index)
        paths[index] = argv[index + 9];
    valid = valid && load_frame(paths[0], width, height, &pixels) &&
        load_pcm(argv[6], &pcm, &pcm_bytes);
    if (!valid) {
        free(pixels); free(pcm);
        fprintf(stderr, "usage: sdl_host --sequence-cue WIDTH HEIGHT INTERVAL_MS CUE_INDEX PCM_FILE CHANNELS RATE FRAME_RGBA...\n");
        return 64;
    }
    int result = m9_sdl_present(pixels, width, height, width * 4u,
        pcm, pcm_bytes, channels, rate, (unsigned)(count * interval_ms), 0,
        paths, count, interval_ms, cue_index, NULL, NULL);
    free(pixels); free(pcm);
    return result;
}

int main(int argc, char **argv) {
    unsigned width = 320, height = 180, duration_ms = 0;
    int self_test = 1;
    uint32_t *pixels = NULL;
    M9Scene scene;
    float *depth = NULL;
    if (argc >= 10 && argc <= (int)(9 + MAX_SEQUENCE_FRAMES) &&
        strcmp(argv[1], "--sequence-cue") == 0)
        return run_sequence_cue(argc, argv);
    if (argc == 2 && strcmp(argv[1], "--smoke") == 0) {
        pixels = calloc((size_t)width * height, sizeof(*pixels));
        depth = malloc((size_t)width * height * sizeof(*depth));
        if (!pixels || !depth) { fprintf(stderr, "frame allocation failed\n"); return 1; }
        fixture_scene(&scene);
        M9Canvas canvas = {pixels, depth, width, height, width * 4u};
        if (!m9_render_scene(&scene, &canvas)) {
            fprintf(stderr, "fixture rasterization failed\n"); free(depth); free(pixels); return 1;
        }
        duration_ms = 180;
    } else if (argc >= 6 && argc <= (int)(5 + MAX_SEQUENCE_FRAMES) &&
               strcmp(argv[1], "--sequence") == 0) {
        unsigned parsed_width, parsed_height, interval_ms;
        size_t sequence_count = (size_t)argc - 5;
        const char *sequence_paths[MAX_SEQUENCE_FRAMES];
        bool valid = parse_unsigned(argv[2], &parsed_width) &&
            parse_unsigned(argv[3], &parsed_height) &&
            parse_unsigned(argv[4], &interval_ms) &&
            sequence_count <= MAX_SEQUENCE_FRAMES &&
            interval_ms >= 16 && interval_ms <= 60000;
        for (size_t index = 0; valid && index < sequence_count; ++index)
            sequence_paths[index] = argv[index + 5];
        valid = valid && load_frame(sequence_paths[0], parsed_width,
            parsed_height, &pixels);
        if (!valid) {
            free(pixels);
            fprintf(stderr, "usage: sdl_host --sequence WIDTH HEIGHT INTERVAL_MS FRAME_RGBA... (1-%u frames; 16-60000 ms)\n",
                MAX_SEQUENCE_FRAMES);
            return 64;
        }
        width = parsed_width;
        height = parsed_height;
        duration_ms = (unsigned)(sequence_count * interval_ms);
        self_test = 0;
        int result = m9_sdl_present(pixels, width, height, width * 4u,
            NULL, 0, 0, 0, duration_ms, self_test, sequence_paths,
            sequence_count, interval_ms, 0, NULL, NULL);
        free(pixels);
        return result;
    } else if ((argc == 5 || argc == 6 || argc == 9) &&
               strcmp(argv[1], "--frame") == 0) {
        unsigned parsed_width, parsed_height, parsed_duration = 0;
        unsigned pcm_channels = 0, pcm_rate = 0;
        uint8_t *pcm = NULL;
        size_t pcm_bytes = 0;
        bool valid = parse_unsigned(argv[3], &parsed_width) &&
            parse_unsigned(argv[4], &parsed_height) &&
            (argc == 5 || parse_unsigned(argv[5], &parsed_duration)) &&
            load_frame(argv[2], parsed_width, parsed_height, &pixels);
        if (valid && argc == 9) {
            valid = parse_unsigned(argv[7], &pcm_channels) &&
                parse_unsigned(argv[8], &pcm_rate) &&
                load_pcm(argv[6], &pcm, &pcm_bytes) &&
                (pcm_channels == 1 || pcm_channels == 2) &&
                (pcm_rate == 22050 || pcm_rate == 44100) &&
                pcm_bytes % (pcm_channels * 2u) == 0;
        }
        if (!valid) {
            free(pcm);
            free(pixels);
            fprintf(stderr, "usage: sdl_host --frame RGBA_FILE WIDTH HEIGHT [DURATION_MS [PCM_S16LE_FILE CHANNELS SAMPLE_RATE]]\n");
            return 64;
        }
        width = parsed_width; height = parsed_height;
        duration_ms = parsed_duration; self_test = 0;
        int result = m9_sdl_present(pixels, width, height, width * 4u,
            pcm, pcm_bytes, pcm_channels, pcm_rate, duration_ms, self_test,
            NULL, 0, 0, 0, NULL, NULL);
        free(pcm);
        free(pixels);
        return result;
    } else {
        fprintf(stderr, "usage: sdl_host --smoke | --frame RGBA_FILE WIDTH HEIGHT [DURATION_MS [PCM_S16LE_FILE CHANNELS SAMPLE_RATE]] | --sequence WIDTH HEIGHT INTERVAL_MS FRAME_RGBA... | --sequence-cue WIDTH HEIGHT INTERVAL_MS CUE_INDEX PCM_FILE CHANNELS RATE FRAME_RGBA...\n");
        return 64;
    }
    int result = m9_sdl_present(pixels, width, height, width * 4u,
                                NULL, 0, 0, 0, duration_ms, self_test,
                                NULL, 0, 0, 0, NULL, NULL);
    free(depth);
    free(pixels);
    return result;
}
