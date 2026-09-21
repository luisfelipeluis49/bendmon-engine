# Presentation feasibility checks

`run.sh` checks the pure projection, compiles and runs the native Bend program,
rejects unsafe host input, verifies both file formats and confirms repeatable
artifact hashes. It writes only beneath a temporary directory it creates.

`run_live.sh` is the Linux desktop gate. It displays the generated PPM through
a developer-owned X11 adapter, observes a key event delivered by the X server,
and streams the generated WAV through the active PulseAudio/PipeWire server.
It is deliberately separate from the headless verifier because hosted CI has
no physical desktop or audio device. Evidence is written beneath
`build/evidence/live-presentation/`.
