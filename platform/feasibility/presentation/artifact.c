#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define FRAME_W 96u
#define FRAME_H 64u
#define RATE 22050u
#define FRAMES 3969u

static void put16(FILE* f, uint16_t x) {
  fputc(x & 255, f); fputc((x >> 8) & 255, f);
}

static void put32(FILE* f, uint32_t x) {
  put16(f, x & 65535); put16(f, x >> 16);
}

static int open_output(int dir, const char* target, char* temp, size_t cap,
  FILE** out) {
  struct stat st;
  int found = fstatat(dir, target, &st, AT_SYMLINK_NOFOLLOW);
  if (found == 0 && S_ISLNK(st.st_mode)) return ELOOP;
  if (found != 0 && errno != ENOENT) return errno;
  int len = snprintf(temp, cap, ".%s.tmp.%ld", target, (long)getpid());
  if (len < 0 || (size_t)len >= cap) return ENAMETOOLONG;
  int fd = openat(dir, temp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0644);
  if (fd < 0) return errno;
  *out = fdopen(fd, "wb");
  if (!*out) { int code = errno; close(fd); unlinkat(dir, temp, 0); return code; }
  return 0;
}

static int finish_output(int dir, const char* temp, const char* target,
  FILE* f, int code) {
  if (!code && (fflush(f) != 0 || ferror(f))) code = errno ? errno : EIO;
  if (!code && fsync(fileno(f)) != 0) code = errno;
  if (fclose(f) != 0 && !code) code = errno;
  if (!code && renameat(dir, temp, dir, target) != 0) code = errno;
  if (!code && fsync(dir) != 0) code = errno;
  if (code) unlinkat(dir, temp, 0);
  return code;
}

static int pixel(FILE* f, uint32_t px, uint32_t py, uint32_t x, uint32_t y,
  uint32_t depth, uint32_t palette) {
  uint8_t r = (uint8_t)(18 + py / 3), g = (uint8_t)(24 + py / 2), b = 42;
  int shadow = py >= y + 12 && py < y + 15 && px + 10 >= x && px <= x + 10;
  int body = px + 6 >= x && px <= x + 6 && py + 10 >= y && py <= y + 10;
  int eye = px + 3 >= x && px <= x + 3 && py + 3 >= y && py <= y + 1;
  int foreground = depth < 3 && py > 38 && px > 43 && px < 91;
  if (shadow) { r = 10; g = 12; b = 18; }
  if (body) {
    r = palette ? 238 : 116; g = palette ? 164 : 210; b = palette ? 82 : 245;
  }
  if (eye) { r = 246; g = 250; b = 220; }
  if (foreground) { r = 30; g = 67; b = 54; }
  return fputc(r, f) == EOF || fputc(g, f) == EOF || fputc(b, f) == EOF;
}

static int write_frame(int dir, uint32_t x, uint32_t y, uint32_t depth,
  uint32_t palette) {
  char temp[96];
  FILE* f = NULL;
  int code = open_output(dir, "frame.ppm", temp, sizeof temp, &f);
  if (code) return code;
  if (fprintf(f, "P6\n%u %u\n255\n", FRAME_W, FRAME_H) < 0)
    code = errno ? errno : EIO;
  for (uint32_t py = 0; py < FRAME_H; py++)
    for (uint32_t px = 0; px < FRAME_W; px++)
      if (!code && pixel(f, px, py, x, y, depth, palette))
        code = errno ? errno : EIO;
  return finish_output(dir, temp, "frame.ppm", f, code);
}

static int write_tone(int dir, uint32_t hz) {
  char temp[96];
  FILE* f = NULL;
  int code = open_output(dir, "tone.wav", temp, sizeof temp, &f);
  if (code) return code;
  uint32_t bytes = FRAMES * 2;
  fwrite("RIFF", 1, 4, f); put32(f, 36 + bytes); fwrite("WAVEfmt ", 1, 8, f);
  put32(f, 16); put16(f, 1); put16(f, 1); put32(f, RATE); put32(f, RATE * 2);
  put16(f, 2); put16(f, 16); fwrite("data", 1, 4, f); put32(f, bytes);
  uint32_t phase = 0, step = (uint32_t)(((uint64_t)hz << 32) / RATE);
  for (uint32_t i = 0; i < FRAMES; i++) {
    phase += step;
    int32_t tri = (phase & 0x80000000u) ? (int32_t)(0xffffffffu - phase) : (int32_t)phase;
    tri = (tri >> 16) - 16384;
    int32_t fade = (int32_t)(FRAMES - i);
    put16(f, (uint16_t)(int16_t)(tri * fade / (int32_t)FRAMES / 3));
  }
  if (ferror(f)) code = errno ? errno : EIO;
  return finish_output(dir, temp, "tone.wav", f, code);
}

Term artifact_emit_run(Env e, Term* f, IoWork* w) {
  size_t n = 0;
  char* out = io_cstr(e, f[0], &n);
  uint32_t x = (uint32_t)f[1], y = (uint32_t)f[2], depth = (uint32_t)f[3];
  uint32_t palette = (uint32_t)f[4], hz = (uint32_t)f[5], tag = (uint32_t)f[6];
  if (n < 2 || n > 4096 || out[0] != '/' || memchr(out, '\0', n) != NULL) {
    free(out); return io_fail(e, EINVAL, "output directory is invalid");
  }
  if (x >= FRAME_W || y >= FRAME_H || depth > 7 || palette > 1 || hz < 80 || hz > 2000) {
    free(out); return io_fail(e, ERANGE, "projected snapshot is outside host bounds");
  }
  uint32_t expected = x + y * 3u + depth * 5u + palette * 7u + hz * 11u;
  if (tag != expected) {
    free(out); return io_fail(e, EINVAL, "projected snapshot state tag mismatch");
  }
  int dir = open(out, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
  free(out);
  if (dir < 0) return io_fail(e, errno, NULL);
  int code = write_frame(dir, x, y, depth, palette);
  if (!code) code = write_tone(dir, hz);
  close(dir);
  if (code) return io_fail(e, code, NULL);
  char report[160];
  int len = snprintf(report, sizeof report,
    "frame.ppm 96x64 depth=%u; tone.wav 22050Hz 180ms; state_tag=%u", depth, tag);
  return io_done(e, io_str(e, report, (size_t)len));
}

static void __attribute__((constructor)) artifact_emit_use(void) {
  io_eff(CID_ARTIFACT_EMIT, artifact_emit_run, 0);
}
