# Browser presentation adapter

`renderer.mjs` is a Canvas2D/Web Audio host for the M9-A scene and cue CSV
records. It has no simulation callbacks and does not accept commands. The host
must first load Content-0 through `platform/content/loader.py`, verify the
project digest against the scene `contentIdentity`, and pass an immutable view
with this shape:

```js
{
  contentIdentity: 123, // first 32 digest bits, as used by the M8 binder
  maps: [{
    runtimeId: 1, // MapId lexical order, 1-based (M8 binder contract)
    vertices: [{x: 0, y: 0, z: 0}], // validated signed Q10 coordinates
    faces: [[0, 1, 2]],
    npcs: [{runtimeId: 1, spriteAssetId: "demo:guide"}], // sorted NpcId, 1-based
    cameraProfile: {fovDegrees: 60, nearQ10: 16, farQ10: 524288},
    backgroundAssetId: "demo:background"
  }],
  assets: {"demo:guide": {image: HTMLImageElement}}
}
```

Camera profiles and media in this view must come from validated immutable
records. `image` values are decoded host resources for already validated PPM or
PNG bytes. Audio bindings passed to `deliverCues` map validated WAV signal kinds
to host-decoded `AudioBuffer`s. Cue delivery starts sound effects; it never
changes the accepted command sequence or logical tick.

The wire parsers cap scene bytes at 16 KiB, cue bytes at 8 KiB, visible NPCs and
battle actors at 64, and all IDs, counters, coordinates, faces, and media table
joins before drawing. On systems without a browser automation runtime, run the
Node smoke suite with `node --test tests/m9/browser/renderer.test.mjs`.
