#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <unistd.h>

#define FRAME_W 96
#define FRAME_H 64
#define SCALE 4

static int read_frame(const char *path, unsigned char pixels[FRAME_H][FRAME_W][3]) {
  FILE *file = fopen(path, "rb");
  if (!file) return errno;
  char magic[3] = {0};
  unsigned width = 0, height = 0, maximum = 0;
  int valid = fscanf(file, "%2s %u %u %u", magic, &width, &height, &maximum) == 4
    && strcmp(magic, "P6") == 0 && width == FRAME_W && height == FRAME_H
    && maximum == 255 && fgetc(file) == '\n';
  if (!valid) { fclose(file); return EINVAL; }
  size_t wanted = sizeof(unsigned char) * FRAME_W * FRAME_H * 3;
  size_t got = fread(pixels, 1, wanted, file);
  int extra = fgetc(file);
  int code = ferror(file) ? EIO : 0;
  fclose(file);
  if (code) return code;
  return got == wanted && extra == EOF ? 0 : EINVAL;
}

static unsigned long channel(unsigned value, unsigned long mask) {
  if (!mask) return 0;
  unsigned shift = 0;
  while (((mask >> shift) & 1ul) == 0) shift++;
  unsigned long maximum = mask >> shift;
  return (((unsigned long)value * maximum + 127ul) / 255ul) << shift;
}

static void draw(Display *display, Window window, GC gc, Visual *visual,
  unsigned char pixels[FRAME_H][FRAME_W][3]) {
  for (unsigned y = 0; y < FRAME_H; y++) {
    for (unsigned x = 0; x < FRAME_W; x++) {
      unsigned long color = channel(pixels[y][x][0], visual->red_mask)
        | channel(pixels[y][x][1], visual->green_mask)
        | channel(pixels[y][x][2], visual->blue_mask);
      XSetForeground(display, gc, color);
      XFillRectangle(display, window, gc, (int)x * SCALE, (int)y * SCALE,
        SCALE, SCALE);
    }
  }
  XFlush(display);
}

static int wait_event(Display *display, Window window, GC gc, Visual *visual,
  unsigned char pixels[FRAME_H][FRAME_W][3]) {
  int mapped = 0, exposed = 0, input = 0, sent = 0;
  for (unsigned attempt = 0; attempt < 50 && !(mapped && exposed && input); attempt++) {
    while (XPending(display)) {
      XEvent event;
      XNextEvent(display, &event);
      if (event.type == MapNotify) mapped = 1;
      if (event.type == Expose) {
        draw(display, window, gc, visual, pixels);
        exposed = 1;
      }
      if (event.type == KeyPress) input = 1;
    }
    if (mapped && exposed && !sent) {
      XEvent key;
      memset(&key, 0, sizeof key);
      key.xkey.type = KeyPress;
      key.xkey.display = display;
      key.xkey.window = window;
      key.xkey.root = DefaultRootWindow(display);
      key.xkey.same_screen = True;
      key.xkey.keycode = 9;
      if (!XSendEvent(display, window, False, KeyPressMask, &key)) return EIO;
      XFlush(display);
      sent = 1;
    }
    if (!(mapped && exposed && input)) usleep(20000);
  }
  return mapped && exposed && input ? 0 : ETIMEDOUT;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: live_x11 <frame.ppm>\n");
    return 64;
  }
  unsigned char pixels[FRAME_H][FRAME_W][3];
  int code = read_frame(argv[1], pixels);
  if (code) {
    fprintf(stderr, "frame read failed: %s\n", strerror(code));
    return 1;
  }
  Display *display = XOpenDisplay(NULL);
  if (!display) {
    fprintf(stderr, "XOpenDisplay failed\n");
    return 1;
  }
  int screen = DefaultScreen(display);
  Window window = XCreateSimpleWindow(display, RootWindow(display, screen),
    40, 40, FRAME_W * SCALE, FRAME_H * SCALE, 0,
    BlackPixel(display, screen), BlackPixel(display, screen));
  XStoreName(display, window, "Bend M0 live presentation probe");
  XSelectInput(display, window,
    StructureNotifyMask | ExposureMask | KeyPressMask);
  GC gc = XCreateGC(display, window, 0, NULL);
  XMapWindow(display, window);
  code = wait_event(display, window, gc, DefaultVisual(display, screen), pixels);
  XFreeGC(display, gc);
  XDestroyWindow(display, window);
  XCloseDisplay(display);
  if (code) {
    fprintf(stderr, "live event loop failed: %s\n", strerror(code));
    return 1;
  }
  puts("live X11 frame and input event: PASS");
  return 0;
}
