#ifndef BENDMON_M9_SDL_HOST_H
#define BENDMON_M9_SDL_HOST_H

#include <stdint.h>
#include <stddef.h>

typedef enum {
    M9_COMMAND_NONE = 0,
    M9_COMMAND_NORTH = 1,
    M9_COMMAND_EAST = 2,
    M9_COMMAND_SOUTH = 3,
    M9_COMMAND_WEST = 4,
    M9_COMMAND_CONFIRM = 5,
    M9_COMMAND_CANCEL = 6,
} M9HostCommand;

typedef void (*M9CommandSink)(M9HostCommand command, void *context);

/* Present caller-owned RGBA32 pixels; a sequence is streamed one bounded frame
   at a time and never enters or changes simulation state. */
int m9_sdl_present(const uint32_t *rgba, unsigned width, unsigned height,
                   unsigned pitch, const uint8_t *pcm_s16le,
                   size_t pcm_bytes, unsigned pcm_channels,
                   unsigned pcm_rate, unsigned duration_ms, int self_test,
                   const char *const *sequence_paths, size_t sequence_count,
                   unsigned sequence_interval_ms, size_t cue_frame_index,
                   M9CommandSink command_sink, void *command_context);

#endif
