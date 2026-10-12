const SCHEMA = "content-0";
const EVENT_NODES = {
  setValue: { key: 1, value: 1, next: [1] },
  addEntity: { entity: 1, bytes: 1, next: [1] },
  emitSignal: { kind: 1, bytes: 1, next: [1] },
  wait: { ticks: 30, next: [1] },
  choice: { prompt: 1, next: [1, 2] },
  stop: { next: [] },
};

const OPTIONAL = {
  project: { entryPoint: { x: 1024, y: 0, z: 1024 }, starter: null, capacityTiers: [] },
  manifest: { moves: [], mixRecipes: [], mixResults: [], items: [], shops: [], events: [], trainers: [], dialogues: [], cameraProfiles: [], audioBindings: [] },
  map: { navigation: { vertices: [{ x: 0, y: 0, z: 0 }, { x: 16384, y: 0, z: 0 }, { x: 16384, y: 0, z: 16384 }, { x: 0, y: 0, z: 16384 }], faces: [[0, 1, 2], [0, 2, 3]], links: [{ from_face: 0, to_face: 1 }, { from_face: 1, to_face: 0 }] }, npcs: [], triggers: [], encounterRegions: [], transitions: [] },
  species: { progression: { baseStats: { hp: 45, attack: 45, defense: 45, specialAttack: 45, specialDefense: 45, speed: 45 }, captureRate: 4500, baseXpYield: 40, baseCurrencyYield: 10 }, types: [0], levelMoves: [], evolutions: [] },
  npc: { event: "", sprite: "", trainer: "", dialogue: "" },
  move: { components: [0], power: 40, damageCategory: "physical", accuracy: 10000,
    effects: [{ kind: "damage", target: "target", category: "physical", power: 40 }] },
  item: { unsellable: false, captureMultiplier: { numerator: 1, denominator: 1 } },
};

const LABELS = {
  id: "ID", schemaVersion: "Schema version", targetMap: "Target map",
  entryMap: "Starting map", entryPoint: "Starting point (Q10)",
  op: "Operation", entry: "Entry node", next: "Next node",
  targetSpecies: "Target species", encounterRegions: "Encounter regions",
  capacityTiers: "Capacity tiers", fovDegrees: "Field of view (degrees)",
  nearQ10: "Near distance (Q10)", farQ10: "Far distance (Q10)",
  signalKind: "Signal kind", baseXpYield: "Base XP yield",
  baseCurrencyYield: "Base currency yield", captureRate: "Capture rate",
  captureMultiplier: "Capture multiplier", buyPrice: "Buy price",
  itemStack: "Item stack limit", inventoryEntries: "Inventory entry limit",
  from_face: "From face", to_face: "To face", encounter: "Encounter",
  event: "Event", sprite: "Sprite asset", animation: "Animation asset",
};

const ARRAY_LIMITS = {
  nodes: { min: 1, max: 256 },
  next: { max: 2 },
  components: { min: 1, max: 4 },
  effects: { min: 1, max: 16 },
  then: { max: 64 },
  else: { max: 64 },
  species: { max: 256 },
};

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function slug(value) {
  return (value || "new").toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 28) || "new";
}

export function contentKind(file, value) {
  if (file === "project.json" || file === "manifest.json") return file.slice(0, -5);
  // Imported projects may use arbitrary document filenames. Classify their
  // validated record shape before falling back to maker-generated paths.
  if (value && typeof value === "object") {
    if (value.navigation) return "map";
    if (Array.isArray(value.nodes)) return "event";
    if ("windup" in value && "recovery" in value && "cooldown" in value && "animation" in value) return "move";
    if (Array.isArray(value.entries)) return "encounter";
    if (Array.isArray(value.species)) return "catalog";
    if (Array.isArray(value.lines)) return "dialogue";
  }
  if (/catalog/.test(file)) return "catalog";
  if (/map/.test(file)) return "map";
  if (/encounter/.test(file)) return "encounter";
  if (/move/.test(file)) return "move";
  if (/item/.test(file)) return "item";
  if (/shop/.test(file)) return "shop";
  if (/trainer/.test(file)) return "trainer";
  if (/dialogue/.test(file)) return "dialogue";
  if (/event/.test(file)) return "event";
  if (/recipe/.test(file)) return "recipe";
  if (/result/.test(file)) return "result";
  return "document";
}

export function newDocument(kind, namespace, serial) {
  const id = `${slug(namespace)}:${kind}-${serial}`;
  const asset = `${slug(namespace)}:sprite`;
  const base = { schemaVersion: SCHEMA, id };
  switch (kind) {
    case "catalog": return { ...base, species: [] };
    case "map": return { ...base, name: `Map ${serial}`, width: 16, height: 16, encounters: [], navigation: {
      vertices: [{ x: 0, y: 0, z: 0 }, { x: 16384, y: 0, z: 0 }, { x: 16384, y: 0, z: 16384 }, { x: 0, y: 0, z: 16384 }],
      faces: [[0, 1, 2], [0, 2, 3]], links: [{ from_face: 0, to_face: 1 }, { from_face: 1, to_face: 0 }],
    }, npcs: [], triggers: [], encounterRegions: [], transitions: [] };
    case "encounter": return { ...base, entries: [] };
    case "move": return { ...base, name: `Move ${serial}`, windup: 0, recovery: 30, cooldown: 60, animation: asset, components: [0], power: 40, damageCategory: "physical", accuracy: 10000 };
    case "item": return { ...base, name: `Item ${serial}`, buyPrice: 0 };
    case "shop": return { ...base, name: `Shop ${serial}`, items: [] };
    case "trainer": return { ...base, name: `Trainer ${serial}` };
    case "dialogue": return { ...base, lines: [{ speaker: "Guide", text: "Welcome to this route." }] };
    case "event": return { ...base, entry: 0, nodes: [{ id: 0, op: "stop", next: [] }] };
    case "recipe": return { ...base, sourceA: `${slug(namespace)}:move-a`, sourceB: `${slug(namespace)}:move-b`, result: `${slug(namespace)}:result` };
    case "result": return { ...base, name: `Mix ${serial}`, components: [0, 1], power: 50, accuracy: 10000, windup: 0, recovery: 30, cooldown: 60, animation: asset };
    default: throw new Error(`Unknown document type ${kind}`);
  }
}

export function newArrayItem(key, nextId, namespace) {
  const ns = slug(namespace);
  switch (key) {
    case "species": return { id: `${ns}:species-${nextId}`, name: `Species ${nextId}`, sprite: `${ns}:sprite` };
    case "entries": return { species: `${ns}:species-1`, level: 1 };
    case "itemRewards": return { item: `${ns}:item-1`, quantity: 1 };
    case "npcs": return { id: `${ns}:npc-${nextId}`, name: `NPC ${nextId}`, x: 1024, y: 0, z: 1024 };
    case "triggers": return { id: `${ns}:trigger-${nextId}`, event: `${ns}:event-1`, vertices: [0, 1, 2] };
    case "encounterRegions": return { id: `${ns}:region-${nextId}`, encounter: `${ns}:encounter-1`, faces: [0] };
    case "transitions": return { id: `${ns}:gate-${nextId}`, targetMap: `${ns}:map-1`, vertices: [0, 1, 2], x: 1024, y: 0, z: 1024 };
    case "vertices": return { x: 0, y: 0, z: 0 };
    case "faces": return [0, 1, 2];
    case "links": return { from_face: 0, to_face: 1 };
    case "nodes": return { id: nextId, op: "stop", next: [] };
    case "cameraProfiles": return { id: `${ns}:camera-${nextId}`, fovDegrees: 60, nearQ10: 16, farQ10: 262144 };
    case "audioBindings": return { signalKind: nextId, asset: `${ns}:sound-${nextId}` };
    case "levelMoves": return { level: 1, move: `${ns}:move-1` };
    case "evolutions": return { id: `${ns}:evolution-${nextId}`, targetSpecies: `${ns}:species-1`, automatic: true, predicates: [] };
    case "lines": return { speaker: "Guide", text: "New line" };
    case "predicates": return { kind: "minimumLevel", value: 10 };
    case "effects": case "then": case "else": return { kind: "damage", target: "target", category: "physical", power: 40 };
    case "capacityTiers": return { party: 6, moves: 4, storage: 1000, itemStack: 999, inventoryEntries: 512, currency: 9999999 };
    default: return ["encounters", "items", "catalogs", "maps", "moves", "mixRecipes", "mixResults", "shops", "events", "trainers", "dialogues"].includes(key)
      ? (key === "items" || key === "encounters" ? `${ns}:${key.slice(0, -1)}-1` : `data/${key}-${nextId}.json`)
      : 0;
  }
}

function effectPreset(kind) {
  const target = "target";
  switch (kind) {
    case "damage": return { kind, target, category: "physical", power: 40 };
    case "heal": return { kind, target, amount: 20 };
    case "drain": case "recoil": return { kind, target, fromNode: 0, numerator: 1, denominator: 2 };
    case "applyStatus": case "removeStatus": return { kind, target, status: "burn" };
    case "clearStatuses": return { kind, target };
    case "modifyStat": return { kind, target, stat: "attack", direction: "raise", magnitude: 1 };
    case "conditional": return { kind, predicate: { kind: "hpBelowHalf", target }, then: [], else: [] };
    default: return { kind: "damage", target, category: "physical", power: 40 };
  }
}

export function addMoveEffects(value) {
  const { power, damageCategory, ...rest } = value;
  return { ...rest, effects: [{ ...effectPreset("damage"), power: power ?? 40,
    category: damageCategory ?? "physical" }] };
}

function predicatePreset(kind) {
  if (kind === "hasStatus") return { kind, target: "target", status: "burn" };
  if (kind === "priorDamagePositive") return { kind, node: 0 };
  return { kind: "hpBelowHalf", target: "target" };
}

function enumOptions(label, parts) {
  if (label === "target") return ["source", "target"];
  if (label === "category") return ["physical", "special"];
  if (label === "status") return ["burn", "poison", "sleep", "stun", "blind"];
  if (label === "stat") return ["attack", "defense", "specialAttack", "specialDefense", "speed", "accuracy", "evasion"];
  if (label === "direction") return ["raise", "lower"];
  if (label === "kind" && parts.includes("predicate")) return ["hpBelowHalf", "hasStatus", "priorDamagePositive"];
  if (label === "kind" && (parts.includes("effects") || parts.includes("then") || parts.includes("else"))) return ["damage", "heal", "drain", "recoil", "applyStatus", "removeStatus", "clearStatuses", "modifyStat", ...(parts.includes("effects") ? ["conditional"] : [])];
  return null;
}

export function fieldLabel(key) {
  if (LABELS[key]) return LABELS[key];
  return String(key).replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replaceAll("_", " ").replace(/^./, letter => letter.toUpperCase());
}

export function eventNodeForOperation(node, operation, nodes = []) {
  const id = Number(node?.id ?? 0);
  const preset = EVENT_NODES[operation];
  if (!preset) return node;
  const targets = nodes.map(item => Number(item.id)).filter(Number.isInteger);
  const forward = targets.find(target => target !== id) ?? id;
  const next = operation === "stop" ? []
    : operation === "choice" ? [forward, targets.find(target => target !== id && target !== forward) ?? forward]
      : [forward];
  return { id, op: operation, ...Object.fromEntries(Object.entries(preset).filter(([key]) => key !== "next")), next };
}

export function nextEventNodeId(nodes = []) {
  const used = new Set(nodes.map(node => Number(node.id)));
  for (let id = 0; id <= 255; id++) if (!used.has(id)) return id;
  return 255;
}

function arrayLimit(key, parent) {
  if (key === "next" && parent?.op) {
    return parent.op === "stop" ? { min: 0, max: 0 }
      : parent.op === "choice" ? { min: 2, max: 2 } : { min: 1, max: 1 };
  }
  return ARRAY_LIMITS[key] || {};
}

function itemLabel(key) {
  const labels = { species: "Species", entries: "Entry", vertices: "Vertex", faces: "Face", links: "Link", nodes: "Node", lines: "Line", evolutions: "Evolution", predicates: "Predicate" };
  return labels[key] || fieldLabel(String(key).replace(/s$/, ""));
}

function fieldPointer(parts) {
  return "/" + parts.slice(1).map(part => String(part).replaceAll("~", "~0").replaceAll("/", "~1")).join("/");
}

function errorFor(errors, parts) {
  const file = parts[0], pointer = fieldPointer(parts);
  return errors.find(row => row.file === file && (row.pointer === pointer || row.pointer.startsWith(pointer + "/")));
}

function addOptional(container, kind, value, parts, commit, namespace) {
  const candidates = OPTIONAL[kind] || {};
  const missing = Object.keys(candidates).filter(key => !Object.hasOwn(value, key));
  if (!missing.length) return;
  const row = element("div", "row");
  const select = element("select");
  for (const key of missing) { const option = element("option", "", fieldLabel(key)); option.value = key; select.append(option); }
  const button = element("button", "", "Add field");
  button.type = "button";
  button.onclick = () => {
    if (kind === "move" && select.value === "effects") {
      commit(parts, addMoveEffects(value));
      return;
    }
    const preset = select.value === "starter"
      ? { species: `${namespace}:species-1`, level: 5 }
      : structuredClone(candidates[select.value]);
    commit(parts, { ...value, [select.value]: preset });
  };
  row.append(select, button);
  container.append(row);
}

function scalarField(value, label, parts, commit, errors, rootValue) {
  const wrapper = element("label", "field");
  wrapper.append(element("span", "", fieldLabel(label)));
  const isEventSuccessor = Array.isArray(rootValue?.nodes) && parts.at(-2) === "next" && typeof value === "number";
  const isEventEntry = Array.isArray(rootValue?.nodes) && parts.at(-1) === "entry" && typeof value === "number";
  const input = element(isEventSuccessor || isEventEntry ? "select" : "input");
  const options = enumOptions(label, parts);
  if (options) {
    const select = element("select");
    for (const item of options) { const option = element("option", "", fieldLabel(item)); option.value = item; select.append(option); }
    select.value = value;
    select.onchange = () => {
      if (label !== "kind") commit(parts, select.value);
      else if (parts.includes("predicate")) commit(parts.slice(0, -1), predicatePreset(select.value));
      else commit(parts.slice(0, -1), effectPreset(select.value));
    };
    wrapper.append(select);
    const error = errorFor(errors, parts);
    if (error) { wrapper.classList.add("error"); wrapper.append(element("span", "error-text", error.message)); }
    return wrapper;
  } else if (isEventSuccessor || isEventEntry) {
    const nodeIds = rootValue.nodes.map(node => Number(node.id));
    if (!nodeIds.includes(value)) {
      const missing = element("option", "", `Missing node ${value}`); missing.value = String(value); input.append(missing);
    }
    for (const node of rootValue.nodes) {
      const option = element("option", "", `Node ${node.id}`); option.value = String(node.id); input.append(option);
    }
    input.value = String(value);
    input.onchange = () => commit(parts, Number(input.value));
    wrapper.append(input);
  }
  else if (typeof value === "boolean") { input.type = "checkbox"; input.checked = value; }
  else if (typeof value === "number") { input.type = "number"; input.step = "1"; input.value = String(value); }
  else { input.type = "text"; input.value = value === null ? "" : String(value); }
  if (label === "op") {
    const select = element("select");
    for (const op of Object.keys(EVENT_NODES)) { const option = element("option", "", fieldLabel(op)); option.value = op; select.append(option); }
    select.value = value;
    select.onchange = () => {
      const nodePath = parts.slice(0, -1);
      const current = rootValue?.nodes?.[Number(parts.at(-2))] || { id: 0 };
      commit(nodePath, eventNodeForOperation(current, select.value, rootValue?.nodes || []));
    };
    wrapper.append(select);
  } else if (Array.isArray(rootValue?.nodes) && parts.at(-3) === "nodes" && label === "id") {
    input.onchange = () => {
      if (!/^-?\d+$/.test(input.value)) { input.setCustomValidity("Enter a whole number"); input.reportValidity(); return; }
      const id = Number(input.value), index = Number(parts.at(-2));
      if (rootValue.nodes.some((node, current) => current !== index && Number(node.id) === id)) {
        input.setCustomValidity(`Node ID ${id} is already used`); input.reportValidity(); return;
      }
      input.setCustomValidity(""); commit(parts, id);
    };
    wrapper.append(input);
  } else if (!isEventSuccessor && !isEventEntry) {
    input.onchange = () => {
      if (input.type === "number") {
        if (!/^-?\d+$/.test(input.value)) { input.setCustomValidity("Enter a whole number"); input.reportValidity(); return; }
        commit(parts, Number(input.value));
      } else commit(parts, input.type === "checkbox" ? input.checked : input.value);
    };
    wrapper.append(input);
  }
  const error = errorFor(errors, parts);
  if (error) { wrapper.classList.add("error"); wrapper.append(element("span", "error-text", error.message)); }
  return wrapper;
}

/** Render validated-shape controls for a draft JSON record; all updates remain draft-only. */
export function renderFields(container, value, parts, commit, errors = [], namespace = "demo", rootValue) {
  const kind = parts.length === 1 ? contentKind(parts[0], value)
    : parts.at(-2) === "species" ? "species"
      : parts.at(-2) === "npcs" ? "npc" : "";
  if (parts.length === 1) rootValue = value;
  if (value === null || typeof value !== "object") { container.append(scalarField(value, String(parts.at(-1)), parts, commit, errors, rootValue)); return; }
  if (Array.isArray(value)) {
    const list = element("div", "list");
    const parent = parts.at(-1) === "next" && Array.isArray(rootValue?.nodes)
      ? rootValue.nodes[Number(parts.at(-2))] : undefined;
    const limits = arrayLimit(String(parts.at(-1)), parent);
    value.forEach((entry, index) => {
      const row = element("div", "card");
      const heading = element("div", "row");
      heading.append(element("strong", "", parts.at(-1) === "nodes" ? `Node ${entry?.id ?? index}` : `${itemLabel(parts.at(-1))} ${index + 1}`));
      const remove = element("button", "", `Remove ${itemLabel(parts.at(-1)).toLowerCase()}`); remove.type = "button";
      remove.disabled = value.length <= (limits.min || 0);
      remove.onclick = () => commit(parts, value.filter((_, i) => i !== index));
      heading.append(remove); row.append(heading);
      if (entry && typeof entry === "object" && !Array.isArray(entry) && entry.op) row.dataset.nodeId = entry.id;
      renderFields(row, entry, [...parts, index], commit, errors, namespace, rootValue);
      list.append(row);
    });
    const isEffectList = ["effects", "then", "else"].includes(String(parts.at(-1)));
    let kindSelect;
    const add = element("button", "", `Add ${itemLabel(parts.at(-1)).toLowerCase()}`);
    add.type = "button";
    add.disabled = value.length >= (limits.max ?? Infinity);
    add.onclick = () => {
      const key = String(parts.at(-1));
      const id = key === "nodes" ? nextEventNodeId(value)
        : key === "next" ? Number(rootValue?.nodes?.[0]?.id ?? 0) : value.length + 1;
      const selectedKind = isEffectList ? kindSelect.value : null;
      const entry = key === "next" ? id : isEffectList ? effectPreset(selectedKind) : newArrayItem(key, id, namespace);
      commit(parts, [...value, entry]);
    };
    if (isEffectList) {
      kindSelect = element("select");
      const kinds = parts.at(-1) === "effects"
        ? ["damage", "heal", "drain", "recoil", "applyStatus", "removeStatus", "clearStatuses", "modifyStat", "conditional"]
        : ["damage", "heal", "drain", "recoil", "applyStatus", "removeStatus", "clearStatuses", "modifyStat"];
      for (const kind of kinds) { const option = element("option", "", fieldLabel(kind)); option.value = kind; kindSelect.append(option); }
      container.append(list, kindSelect, add);
    } else container.append(list, add);
    return;
  }
  const grid = element("div", "grid");
  for (const [key, child] of Object.entries(value)) {
    if (key === "schemaVersion") continue;
    const field = element("div");
    if (child && typeof child === "object") field.append(element("h3", "", fieldLabel(key)));
    renderFields(field, child, [...parts, key], commit, errors, namespace, rootValue);
    if (Object.hasOwn(OPTIONAL[kind] || {}, key)) {
      const remove = element("button", "", `Remove ${fieldLabel(key)}`); remove.type = "button";
      remove.onclick = () => { const next = { ...value }; delete next[key]; commit(parts, next); };
      field.append(remove);
    }
    grid.append(field);
  }
  container.append(grid);
  addOptional(container, kind, value, parts, commit, namespace);
}
