import test from "node:test";
import assert from "node:assert/strict";
import { addMoveEffects, contentKind, eventNodeForOperation, fieldLabel, newArrayItem, newDocument, nextEventNodeId, renderFields } from "../../../platform/maker/browser/forms.mjs";

test("map template has a connected, bounded flat navigation surface", () => {
  const map = newDocument("map", "maker", 1);
  assert.equal(map.id, "maker:map-1");
  assert.equal(map.navigation.vertices.length, 4);
  assert.deepEqual(map.navigation.faces, [[0, 1, 2], [0, 2, 3]]);
  assert.deepEqual(map.navigation.links, [{ from_face: 0, to_face: 1 }, { from_face: 1, to_face: 0 }]);
  assert.equal(contentKind("maps/map-1.json"), "map");
});

test("imported project documents are classified by their validated shape", () => {
  assert.equal(contentKind("data/grove.json", { navigation: { vertices: [], faces: [] } }), "map");
  assert.equal(contentKind("data/greeting.json", { nodes: [] }), "event");
  assert.equal(contentKind("data/catalog.json", { species: [] }), "catalog");
});

test("maker templates provide bounded schema fields for the small section", () => {
  for (const kind of ["catalog", "encounter", "move", "item", "shop", "event", "recipe", "result", "trainer", "dialogue"]) {
    const doc = newDocument(kind, "maker", 2);
    assert.equal(doc.schemaVersion, "content-0");
    assert.equal(doc.id, `maker:${kind}-2`);
  }
  assert.deepEqual(newArrayItem("nodes", 3, "maker"), { id: 3, op: "stop", next: [] });
  assert.equal(contentKind("dialogues/dialogue-1.json"), "dialogue");
  assert.deepEqual(newArrayItem("npcs", 1, "maker"), {
    id: "maker:npc-1", name: "NPC 1", x: 1024, y: 0, z: 1024,
  });
  assert.deepEqual(Object.fromEntries(["power", "damageCategory", "components"]
    .map(key => [key, newDocument("move", "maker", 2)[key]])),
    { power: 40, damageCategory: "physical", components: [0] });
});

test("field labels make schema names readable without changing their stored keys", () => {
  assert.equal(fieldLabel("baseXpYield"), "Base XP yield");
  assert.equal(fieldLabel("targetMap"), "Target map");
  assert.equal(fieldLabel("from_face"), "From face");
  assert.equal(fieldLabel("recovery"), "Recovery");
});

test("adding authored effects migrates the existing damage without duplicate authority", () => {
  const move = { ...newDocument("move", "maker", 1), power: 85,
    damageCategory: "special" };
  const converted = addMoveEffects(move);
  assert.equal(converted.power, undefined);
  assert.equal(converted.damageCategory, undefined);
  assert.deepEqual(converted.effects, [{ kind: "damage", target: "target",
    category: "special", power: 85 }]);
});

test("move templates expose optional authored effects with bounded no-code row presets", () => {
  const move = newDocument("move", "maker", 3);
  assert.equal(Object.hasOwn(move, "effects"), false);
  assert.equal(contentKind("imports/custom.json", {
    schemaVersion: "content-0", id: "maker:custom", windup: 0, recovery: 30,
    cooldown: 60, animation: "maker:sprite", effects: [],
  }), "move");
  assert.deepEqual(newArrayItem("effects", 1, "maker"), {
    kind: "damage", target: "target", category: "physical", power: 40,
  });
  assert.deepEqual(newArrayItem("then", 1, "maker"), {
    kind: "damage", target: "target", category: "physical", power: 40,
  });
});

test("effect controls add rows, change variants, and edit conditional branch leaves", () => {
  class FakeElement {
    constructor(tag) { this.tagName = tag; this.children = []; this.classList = { add() {} }; this.dataset = {}; }
    append(...nodes) { this.children.push(...nodes); }
    set textContent(value) { this.label = value; }
    get textContent() { return this.label || ""; }
  }
  const previousDocument = globalThis.document;
  globalThis.document = { createElement: tag => new FakeElement(tag) };
  let move = newDocument("move", "maker", 4);
  const update = (object, path, replacement) => {
    if (!path.length) return replacement;
    const [head, ...tail] = path;
    const copy = Array.isArray(object) ? [...object] : { ...object };
    copy[head] = tail.length ? update(object[head], tail, replacement) : replacement;
    return copy;
  };
  const render = () => {
    const root = new FakeElement("main");
    renderFields(root, move, ["imports/move.json"], (path, value) => {
      const documentPath = path.slice(1);
      move = documentPath.length ? update(move, documentPath, value) : value;
    });
    return root;
  };
  const all = (node, predicate) => [ ...(predicate(node) ? [node] : []), ...node.children.flatMap(child => all(child, predicate)) ];
  const findButton = (root, label) => all(root, node => node.tagName === "button" && node.textContent === label)[0];

  try {
    let root = render();
    const addField = findButton(root, "Add field");
    const optional = all(root, node => node.tagName === "select").find(node => node.children.some(option => option.value === "effects"));
    optional.value = "effects";
    addField.onclick();
    assert.deepEqual(move.effects, [{ kind: "damage", target: "target", category: "physical", power: 40 }]);

    root = render();
    const enumFields = all(root, node => node.tagName === "label" &&
      node.children.some(child => child.tagName === "select"));
    assert.ok(enumFields.length > 0);
    assert.ok(enumFields.every(node => !node.children.some(child => child.tagName === "input")));
    let effectPicker = all(root, node => node.tagName === "select" && node.children.some(option => option.value === "conditional")).at(-1);
    effectPicker.value = "heal";
    findButton(root, "Add effect").onclick();
    assert.deepEqual(move.effects.at(-1), { kind: "heal", target: "target", amount: 20 });

    root = render();
    effectPicker = all(root, node => node.tagName === "select" && node.children.some(option => option.value === "conditional")).at(-1);
    effectPicker.value = "conditional";
    findButton(root, "Add effect").onclick();
    assert.deepEqual(move.effects.at(-1), {
      kind: "conditional", predicate: { kind: "hpBelowHalf", target: "target" }, then: [], else: [],
    });

    root = render();
    const predicatePicker = all(root, node => node.tagName === "select" && node.children.some(option => option.value === "priorDamagePositive"))[0];
    predicatePicker.value = "hasStatus";
    predicatePicker.onchange();
    assert.deepEqual(move.effects.at(-1).predicate, { kind: "hasStatus", target: "target", status: "burn" });

    root = render();
    findButton(root, "Add then").onclick();
    assert.deepEqual(move.effects.at(-1).then, [{ kind: "damage", target: "target", category: "physical", power: 40 }]);
    root = render();
    findButton(root, "Add else").onclick();
    assert.deepEqual(move.effects.at(-1).else, [{ kind: "damage", target: "target", category: "physical", power: 40 }]);
  } finally {
    globalThis.document = previousDocument;
  }
});

test("event operation presets replace incompatible fields and keep successors resolvable", () => {
  const nodes = [{ id: 0, op: "stop", next: [] }, { id: 4, op: "stop", next: [] }];
  assert.deepEqual(eventNodeForOperation({ id: 0, op: "stop", next: [] }, "wait", nodes), {
    id: 0, op: "wait", ticks: 30, next: [4],
  });
  assert.deepEqual(eventNodeForOperation({ id: 0, op: "wait", ticks: 2, next: [4] }, "choice", nodes), {
    id: 0, op: "choice", prompt: 1, next: [4, 4],
  });
  assert.deepEqual(eventNodeForOperation({ id: 0, op: "choice", prompt: 2, next: [4, 4] }, "stop", nodes), {
    id: 0, op: "stop", next: [],
  });
});

test("event node IDs remain unique after earlier nodes are removed", () => {
  assert.equal(nextEventNodeId([{ id: 0 }, { id: 1 }, { id: 3 }]), 2);
  assert.equal(nextEventNodeId([{ id: 0 }, { id: 1 }]), 2);
});
