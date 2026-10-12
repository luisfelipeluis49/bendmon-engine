import test from "node:test";
import assert from "node:assert/strict";
import {
  addDocument,
  createDraftState,
  markDraftSaved,
  moveMapPlacement,
  placeMapItem,
  redoDraft,
  removeDocument,
  undoDraft,
  updatePath,
} from "../../../platform/maker/browser/state.mjs";

const path = "content/maps/field.json";
const starter = () => createDraftState({
  [path]: { placements: [{ id: "a", x: 1 }, { id: "b", x: 2 }], title: "Field" },
  "content/story/start.json": { lines: ["Hello"] },
});

test("path edits are immutable, dirty, and undo/redo restores the whole project", () => {
  const initial = starter();
  const edited = updatePath(initial, [path, "title"], "New field");
  assert.equal(initial.dirty, false);
  assert.equal(edited.dirty, true);
  assert.equal(edited.document[path].title, "New field");
  assert.deepEqual(undoDraft(edited).document, initial.document);
  assert.deepEqual(redoDraft(undoDraft(edited)).document, edited.document);
});

test("equal writes are no-ops and a new edit after undo clears redo", () => {
  const initial = starter();
  const edited = updatePath(initial, [path, "title"], "Changed");
  assert.equal(updatePath(edited, [path, "title"], "Changed"), edited);
  const undone = undoDraft(edited);
  assert.equal(undone.canRedo, true);
  const branched = updatePath(undone, [path, "title"], "Other");
  assert.equal(branched.canRedo, false);
  assert.equal(redoDraft(branched), branched);
});

test("map placement and drag are each a single reversible snapshot", () => {
  const initial = starter();
  const placed = placeMapItem(initial, [path, "placements"], { id: "c", x: 3 }, 1);
  assert.deepEqual(placed.document[path].placements.map(item => item.id), ["a", "c", "b"]);
  const moved = moveMapPlacement(placed, [path, "placements"], 0, 2);
  assert.deepEqual(moved.document[path].placements.map(item => item.id), ["c", "b", "a"]);
  assert.deepEqual(undoDraft(moved).document, placed.document);
  assert.deepEqual(undoDraft(placed).document, initial.document);
});

test("document additions and removals are undoable whole-project edits", () => {
  const initial = starter();
  const added = addDocument(initial, "content/maps/cave.json", { title: "Cave", placements: [] });
  assert.equal(added.document["content/maps/cave.json"].title, "Cave");
  assert.deepEqual(undoDraft(added).document, initial.document);
  assert.deepEqual(redoDraft(undoDraft(added)).document, added.document);

  const removed = removeDocument(added, path);
  assert.equal(Object.hasOwn(removed.document, path), false);
  assert.deepEqual(undoDraft(removed).document, added.document);
  assert.throws(() => addDocument(added, path, {}), /already exists/);
  assert.throws(() => removeDocument(removed, path), /does not exist/);
  assert.throws(() => addDocument(initial, "content/../escape.json", {}), /invalid project path/);
});

test("history stays within the configured cap and save resets dirty state", () => {
  let state = createDraftState({ [path]: { title: "0" } }, { historyLimit: 2 });
  for (const title of ["1", "2", "3"]) state = updatePath(state, [path, "title"], title);
  assert.equal(state.past.length, 2);
  assert.equal(undoDraft(undoDraft(state)).document[path].title, "1");
  assert.equal(undoDraft(undoDraft(undoDraft(state))).document[path].title, "1");
  const saved = markDraftSaved(state);
  assert.equal(saved.dirty, false);
  assert.equal(saved.canUndo, false);
  assert.deepEqual(saved.baseline, saved.document);
});

test("invalid paths, project paths, values, indices, and history limits are rejected", () => {
  const state = starter();
  assert.throws(() => updatePath(state, [path, "__proto__"], {}), /invalid path segment/);
  assert.throws(() => updatePath(state, [path, "missing"], 1), /path does not exist/);
  assert.throws(() => updatePath(state, [path, "title"], { constructor: "bad" }), /forbidden key/);
  assert.throws(() => createDraftState({ "../escape.json": {} }), /invalid project path/);
  assert.throws(() => createDraftState({}, { historyLimit: 1001 }), /historyLimit/);
  assert.throws(() => placeMapItem(state, [path, "placements"], {}, 3), /placement index/);
  assert.throws(() => moveMapPlacement(state, [path, "placements"], 0, 8), /drag indices/);
});

test("snapshots and nested JSON records cannot be mutated", () => {
  const state = starter();
  assert.equal(Object.isFrozen(state.document[path].placements[0]), true);
  assert.throws(() => { state.document[path].title = "mutated"; }, TypeError);
});

test("field history shares untouched records instead of copying every document", () => {
  const initial = starter();
  const changed = updatePath(initial, [path, "title"], "Changed");
  assert.equal(changed.document["content/story/start.json"], initial.document["content/story/start.json"]);
  assert.equal(changed.document[path].placements, initial.document[path].placements);
  assert.notEqual(changed.document[path], initial.document[path]);
});
