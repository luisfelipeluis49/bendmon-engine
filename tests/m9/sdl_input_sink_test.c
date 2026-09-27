#include "../../platform/presentation/sdl_host.h"

#include <stdint.h>
#include <stdio.h>

typedef struct {
    M9HostCommand commands[2];
    unsigned count;
} CommandRecord;

static void record_command(M9HostCommand command, void *context) {
    CommandRecord *record = context;
    if (record->count < 2) record->commands[record->count] = command;
    ++record->count;
}

int main(void) {
    uint32_t pixels[16 * 9] = {0};
    CommandRecord record = {0};
    int result = m9_sdl_present(pixels, 16, 9, 16 * 4, NULL, 0, 0, 0,
        100, 1, NULL, 0, 0, 0, record_command, &record);
    if (result || record.count != 2 ||
        record.commands[0] != M9_COMMAND_NORTH ||
        record.commands[1] != M9_COMMAND_CANCEL) {
        fprintf(stderr, "SDL command sink mismatch: result=%d count=%u\n",
            result, record.count);
        return 1;
    }
    puts("M9 command sink receives canonical input");
    return 0;
}
