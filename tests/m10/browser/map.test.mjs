import test from "node:test";
import assert from "node:assert/strict";
import { renderMap } from "../../../platform/maker/browser/map.mjs";

class Element {
  constructor(tag) { this.tagName = tag; this.children = []; this.listeners = {}; this.dataset = {}; this.textContent = ""; this.captured = new Set(); }
  append(...nodes) { this.children.push(...nodes); }
  setAttribute() {}
  addEventListener(name, callback) { this.listeners[name] = callback; }
  getBoundingClientRect() { return { left: 0, top: 0, width: 320, height: 240 }; }
  getContext() { return context; }
  setPointerCapture(id) { this.captured.add(id); }
  hasPointerCapture(id) { return this.captured.has(id); }
  click() { this.onclick?.(); }
  emit(name, event) { this.listeners[name]?.(event); }
}

const drawFills = [];
const context = new Proxy({
  scale() {}, fillRect() {}, beginPath() {}, moveTo() {}, lineTo() {}, closePath() {}, stroke() {},
  arc() {}, fill() { drawFills.push(this.fillStyle); }, fillText() {},
}, { set(target, key, value) { target[key] = value; return true; } });

function withBrowser(callback) {
  const previous = {
    document: globalThis.document, window: globalThis.window,
    requestAnimationFrame: globalThis.requestAnimationFrame, ResizeObserver: globalThis.ResizeObserver,
  };
  globalThis.document = { createElement: tag => new Element(tag) };
  globalThis.window = { devicePixelRatio: 1 };
  globalThis.requestAnimationFrame = () => 0;
  globalThis.ResizeObserver = class { observe() {} disconnect() {} };
  drawFills.length = 0;
  try { callback(); }
  finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete globalThis[key]; else globalThis[key] = value;
    }
  }
}

function sampleMap(npcs = []) {
  return {
    id: "maker:map-1", name: "Test Map", width: 16, height: 16,
    navigation: {
      vertices: [
        { x: 0, y: 0, z: 0 }, { x: 16384, y: 200, z: 0 },
        { x: 16384, y: 400, z: 16384 }, { x: 0, y: 600, z: 16384 },
      ],
      faces: [[0, 1, 2], [0, 2, 3]], links: [],
    },
    npcs, triggers: [], encounterRegions: [], transitions: [],
  };
}

function setup(map = sampleMap(), start = false) {
  const container = new Element("div"), edits = [], selections = [], starts = [];
  renderMap(container, map, "content/maps/test.json", "test", (...args) => edits.push(args), value => selections.push(value),
            null, null, start ? value => starts.push(value) : null);
  const toolbar = container.children[0], canvas = container.children[2].children[0];
  const button = label => toolbar.children.find(child => child.textContent === label);
  const click = (x, y) => canvas.emit("pointerdown", { clientX: x, clientY: y, pointerId: 1 });
  return { container, edits, selections, starts, toolbar, canvas, button, click };
}

test("starting point can be placed only on the entry map navigation surface", () => withBrowser(() => {
  const ui = setup(sampleMap(), true);
  ui.button("Set starting point").click();
  ui.click(8, 100);
  assert.equal(ui.starts.length, 0);
  ui.click(241, 101);
  assert.equal(ui.starts.length, 1);
  assert.ok(ui.starts[0].x > 0 && ui.starts[0].z > 0);
  assert.equal(ui.starts[0].y, 240);
  assert.equal(ui.edits.length, 0, "the project start is separate from map geometry");
}));

test("navigation tools add bounded vertices and link new faces across shared edges", () => withBrowser(() => {
  const ui = setup();
  ui.button("Add navigation vertex").click();
  ui.click(160, 170);
  const vertexEdit = ui.edits[0][1].navigation;
  assert.equal(vertexEdit.vertices.length, 5);
  assert.deepEqual(vertexEdit.vertices[4], { x: 8192, y: 0, z: 12459 });

  ui.button("Add navigation face").click();
  ui.click(24, 24); ui.click(296, 216); ui.click(160, 170);
  const navigation = ui.edits.at(-1)[1].navigation;
  assert.deepEqual(navigation.faces.at(-1), [0, 2, 4]);
  assert.deepEqual(navigation.links.slice(-2), [
    { from_face: 1, to_face: 2 }, { from_face: 2, to_face: 1 },
  ]);
}));

test("navigation can be added to a legacy map with no navigation field", () => withBrowser(() => {
  const map = sampleMap();
  delete map.navigation;
  const ui = setup(map);
  ui.button("Add navigation vertex").click();
  ui.click(24, 24);
  assert.deepEqual(ui.edits[0][0], ["content/maps/test.json"]);
  assert.equal(ui.edits[0][1].navigation.vertices.length, 1);
}));

test("NPC placement requires a navigation face and interpolates its surface height", () => withBrowser(() => {
  const ui = setup();
  ui.button("Place NPC").click();
  ui.click(8, 100);
  assert.equal(ui.edits.length, 0, "outside the navigation surface is ignored");
  ui.click(241, 101);
  assert.equal(ui.edits.length, 1);
  const npc = ui.edits[0][1].npcs[0];
  assert.ok(npc.x > 0 && npc.z > 0 && npc.x < 16384 && npc.z < 16384);
  assert.equal(npc.y, 240);
  assert.deepEqual(ui.selections.at(-1), { file: "content/maps/test.json", kind: "npcs", index: 0 });
}));

test("trigger placement picks three distinct vertices and highlights selected geometry", () => withBrowser(() => {
  const ui = setup();
  ui.button("Place trigger").click();
  ui.click(24, 24); ui.click(24, 24); ui.click(296, 24);
  assert.equal(ui.edits.length, 0, "duplicate vertices do not complete the trigger");
  ui.click(296, 216);
  assert.deepEqual(ui.edits[0][1].triggers[0].vertices, [0, 1, 2]);
  assert.deepEqual(ui.selections.at(-1), { file: "content/maps/test.json", kind: "triggers", index: 0 });
  assert.ok(drawFills.includes("#ffd18c"), "picked and selected vertices use the highlight color");
}));

test("region and transition tools bind picks to the clicked navigation face", () => withBrowser(() => {
  const ui = setup();
  ui.button("Place encounter region").click();
  ui.click(80, 140);
  assert.deepEqual(ui.edits[0][1].encounterRegions[0].faces, [1]);
  assert.ok(drawFills.includes("#9a7145"), "selected encounter face is highlighted");

  ui.button("Place transition").click();
  ui.click(241, 101); // pick face 0
  assert.equal(ui.edits.length, 1);
  ui.click(80, 140); // a point on face 1 cannot complete the transition
  assert.equal(ui.edits.length, 1);
  ui.click(180, 100);
  const transition = ui.edits[1][1].transitions[0];
  assert.deepEqual(transition.vertices, [0, 1, 2]);
  assert.ok(transition.x > 0 && transition.z > 0 && transition.y >= 0 && transition.y <= 400);
}));

test("select tool selects and highlights existing face and vertex placements", () => withBrowser(() => {
  const map = sampleMap();
  map.encounterRegions.push({ id: "region", faces: [1] });
  map.triggers.push({ id: "trigger", vertices: [0, 1, 2] });
  const ui = setup(map);
  ui.click(80, 140);
  assert.deepEqual(ui.selections.at(-1), { file: "content/maps/test.json", kind: "encounterRegions", index: 0 });
  assert.ok(drawFills.includes("#9a7145"));
  ui.click(24, 24);
  assert.deepEqual(ui.selections.at(-1), { file: "content/maps/test.json", kind: "triggers", index: 0 });
  assert.ok(drawFills.includes("#ffd18c"));
}));

test("dragging edits an NPC once and ignores locations outside the navigation surface", () => withBrowser(() => {
  const ui = setup(sampleMap([{ id: "test:npc-1", name: "Guard", x: 1000, y: 0, z: 1000 }]));
  ui.click(41, 36);
  ui.canvas.emit("pointermove", { clientX: 8, clientY: 100, pointerId: 1 });
  ui.canvas.emit("pointerup", {});
  assert.equal(ui.edits.length, 0, "an invalid drag location does not alter coordinates");

  ui.click(41, 36);
  ui.canvas.emit("pointermove", { clientX: 180, clientY: 100, pointerId: 1 });
  ui.canvas.emit("pointerup", {});
  assert.equal(ui.edits.length, 1, "a completed drag is one reversible edit");
  assert.deepEqual(ui.edits[0][0], ["content/maps/test.json", "npcs"]);
  assert.ok(ui.edits[0][1][0].x > 0 && ui.edits[0][1][0].z > 0);
}));
