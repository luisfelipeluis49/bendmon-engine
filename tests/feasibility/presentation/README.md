# Presentation feasibility checks

`run.sh` checks the pure projection, compiles and runs the native Bend program,
rejects unsafe host input, verifies both file formats and confirms repeatable
artifact hashes. It writes only beneath a temporary directory it creates.

The live Bend window path is not exercised in this headless gate: it requires a
desktop X11 session. The installed native Bend audio effect cannot compile on
this host because `alsa/asoundlib.h` is absent. The boundary therefore emits a
portable PPM image and PCM WAV tone through a version-coupled custom C effect.
