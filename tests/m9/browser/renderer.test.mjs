import test from "node:test";
import assert from "node:assert/strict";
import { deliverCues, parseCueCsv, parseSceneCsv, renderScene } from "../../../platform/presentation/browser/renderer.mjs";

function fakeContext(width = 640, height = 360) {
  const calls = [];
  const ctx = { canvas: { width, height }, calls, fillStyle: "", strokeStyle: "", font: "",
    fillRect(...args) { calls.push(["fillRect", ...args]); }, beginPath() { calls.push(["beginPath"]); },
    moveTo(...args) { calls.push(["moveTo", ...args]); }, lineTo(...args) { calls.push(["lineTo", ...args]); },
    closePath() { calls.push(["closePath"]); }, fill() { calls.push(["fill"]); }, stroke() { calls.push(["stroke"]); },
    arc(...args) { calls.push(["arc", ...args]); }, drawImage(...args) { calls.push(["drawImage", ...args]); },
    fillText(...args) { calls.push(["fillText", ...args]); },
  };
  return ctx;
}

const noNpcScene = "1,99,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0";
const content = { contentIdentity: 99, maps: [{ runtimeId: 1,
  vertices: [{ x: -1024, y: 0, z: 5120 }, { x: 1024, y: 0, z: 5120 }, { x: 0, y: 0, z: 7168 }],
  faces: [[0, 1, 2]], npcs: [{ runtimeId: 1, spriteAssetId: "demo:npc" }],
  cameraProfile: { fovDegrees: 60, nearQ10: 16, farQ10: 262144 } }], assets: {} };

test("parses and renders the same bounded scene wire on a Canvas2D host", () => {
  const scene = parseSceneCsv(noNpcScene);
  assert.equal(scene.contentIdentity, 99);
  const ctx = fakeContext();
  renderScene(ctx, scene, content);
  assert.ok(ctx.calls.some((call) => call[0] === "lineTo"));
});

test("renders validated visible billboards with deterministic fallback", () => {
  const scene = [1, 99, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 5120, 0, 0, 0].join(",");
  const ctx = fakeContext();
  renderScene(ctx, scene, content);
  assert.ok(ctx.calls.some((call) => call[0] === "arc"));
});

test("draws a player and event cue without changing parsed scene data", () => {
  const ctx = fakeContext();
  const scene = renderScene(ctx, noNpcScene, content, "1,1,2,0,0,7,0");
  assert.equal(scene.position.x, 0);
  assert.ok(ctx.calls.filter((call) => call[0] === "arc").length >= 2);
});

test("draws bounded battle state in the preview", () => {
  const scene = `${noNpcScene.slice(0, -1)}1,42,1,2,1,0,30,0,2,1,20,1`;
  const ctx = fakeContext();
  renderScene(ctx, scene, content);
  assert.ok(ctx.calls.some((call) => call[0] === "fillText"));
});

test("rejects malformed, excessive, or mismatched scene input", () => {
  for (const wire of ["1,99", "1,099,1,0,0,0,0,0,0,0,0,0", "2,99,1,0,0,0,0,0,0,0,0,0",
    "1,99,1,0,0,0,0,0,0,0,65,0,0"]) {
    assert.throws(() => parseSceneCsv(wire), TypeError);
  }
  assert.throws(() => renderScene(fakeContext(), noNpcScene, { ...content, contentIdentity: 100 }), /identity mismatch/);
});

test("parses ordered semantic cues and only plays signal-bound audio", () => {
  const cues = parseCueCsv("1,2,5,0,0,4,0,5,1,1,8,0");
  assert.deepEqual(cues.map((cue) => cue.kind), ["signal", "waited"]);
  let starts = 0;
  const audio = { destination: {}, createBufferSource() { return { connect() {}, start() { starts++; } }; } };
  const played = deliverCues(cues, [{ signalKind: 4, buffer: { sampleRate: 22050 } }], audio);
  assert.equal(played, 1);
  assert.equal(starts, 1);
  assert.throws(() => parseCueCsv("1,2,5,0,0,4,0"), TypeError);
});
