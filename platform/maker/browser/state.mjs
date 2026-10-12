const DEFAULT_HISTORY_LIMIT = 100;
const MAX_HISTORY_LIMIT = 1000;
const FORBIDDEN_KEYS = new Set(["__proto__", "prototype", "constructor"]);

function cloneJson(value, where = "document") {
  if (value === null || typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (Array.isArray(value)) return value.map((entry, index) => cloneJson(entry, `${where}[${index}]`));
  if (typeof value !== "object" || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new TypeError(`${where} must contain only plain JSON values`);
  }
  const copy = {};
  for (const key of Object.keys(value)) {
    if (FORBIDDEN_KEYS.has(key)) throw new TypeError(`${where} contains forbidden key ${key}`);
    copy[key] = cloneJson(value[key], `${where}.${key}`);
  }
  return copy;
}

function pathParts(path) {
  const parts = Array.isArray(path) ? path.map(String) : typeof path === "string"
    ? (path === "" ? [] : path.startsWith("/")
      ? path.slice(1).split("/").map(part => part.replaceAll("~1", "/").replaceAll("~0", "~"))
      : path.split("."))
    : null;
  if (!parts) throw new TypeError("path must be a string or array of path segments");
  for (const part of parts) {
    if (!part || FORBIDDEN_KEYS.has(part)) throw new TypeError(`invalid path segment ${JSON.stringify(part)}`);
  }
  return parts;
}

function validateDocumentPath(filePath) {
  if (typeof filePath !== "string" || !filePath || filePath.startsWith("/") ||
      filePath.split(/[\\/]/).some(part => !part || part === "." || part === ".." || FORBIDDEN_KEYS.has(part))) {
    throw new TypeError(`invalid project path ${JSON.stringify(filePath)}`);
  }
}

function readAt(root, parts) {
  let node = root;
  for (const part of parts) {
    if (node === null || typeof node !== "object" || !Object.hasOwn(node, part)) {
      throw new RangeError(`path does not exist: ${parts.join("/")}`);
    }
    node = node[part];
  }
  return node;
}

function writeAt(root, parts, value) {
  const update = (node, index) => {
    const part = parts[index];
    if (node === null || typeof node !== "object" || !Object.hasOwn(node, part)) {
      throw new RangeError(`path does not exist: ${parts.join("/")}`);
    }
    const copy = Array.isArray(node) ? [...node] : { ...node };
    copy[part] = index === parts.length - 1
      ? cloneJson(value, `value at ${parts.join("/")}`)
      : update(node[part], index + 1);
    return copy;
  };
  return update(root, 0);
}

function freezeSnapshot(snapshot) {
  if (snapshot && typeof snapshot === "object") {
    if (Object.isFrozen(snapshot)) return snapshot;
    Object.freeze(snapshot);
    for (const value of Object.values(snapshot)) freezeSnapshot(value);
  }
  return snapshot;
}

function makeState(state, document, past, future) {
  return freezeSnapshot({
    document,
    baseline: state.baseline,
    past,
    future,
    historyLimit: state.historyLimit,
    dirty: JSON.stringify(document) !== state.baselineJson,
    canUndo: past.length > 0,
    canRedo: future.length > 0,
    revision: state.revision + 1,
    baselineJson: state.baselineJson,
  });
}

function record(state, document) {
  if (JSON.stringify(document) === JSON.stringify(state.document)) return state;
  const past = [...state.past, state.document].slice(-state.historyLimit);
  return makeState(state, document, past, []);
}

/** Create an immutable draft editor state from a Content-0 path-to-document map. */
export function createDraftState(project, { historyLimit = DEFAULT_HISTORY_LIMIT } = {}) {
  if (!Number.isInteger(historyLimit) || historyLimit < 1 || historyLimit > MAX_HISTORY_LIMIT) {
    throw new RangeError(`historyLimit must be an integer from 1 to ${MAX_HISTORY_LIMIT}`);
  }
  const document = cloneJson(project);
  if (!document || Array.isArray(document) || typeof document !== "object") {
    throw new TypeError("project must be an object keyed by relative Content-0 paths");
  }
  for (const filePath of Object.keys(document)) {
    validateDocumentPath(filePath);
  }
  const baselineJson = JSON.stringify(document);
  return freezeSnapshot({ document, baseline: document, baselineJson, past: [], future: [], historyLimit, dirty: false, canUndo: false, canRedo: false, revision: 0 });
}

/** Replace an existing field addressed by JSON Pointer, dotted path, or segments. */
export function updatePath(state, path, value) {
  const parts = pathParts(path);
  if (!parts.length) throw new TypeError("path must identify an existing field");
  return record(state, writeAt(state.document, parts, value));
}

/** Add a new relative Content-0 file as one undoable project edit. */
export function addDocument(state, filePath, document) {
  validateDocumentPath(filePath);
  if (Object.hasOwn(state.document, filePath)) throw new RangeError(`project document already exists: ${filePath}`);
  const next = { ...state.document };
  next[filePath] = cloneJson(document, `document ${filePath}`);
  return record(state, next);
}

/** Remove an existing project document as one undoable project edit. */
export function removeDocument(state, filePath) {
  validateDocumentPath(filePath);
  if (!Object.hasOwn(state.document, filePath)) throw new RangeError(`project document does not exist: ${filePath}`);
  const next = { ...state.document };
  delete next[filePath];
  return record(state, next);
}

/** Insert a placement at an array index; one call is one undoable map edit. */
export function placeMapItem(state, arrayPath, item, index) {
  const parts = pathParts(arrayPath);
  const current = readAt(state.document, parts);
  if (!Array.isArray(current)) throw new TypeError("map placement target must be an array");
  if (!Number.isInteger(index) || index < 0 || index > current.length) throw new RangeError("placement index is outside the map array");
  const next = [...current.slice(0, index), cloneJson(item, "placement"), ...current.slice(index)];
  return record(state, writeAt(state.document, parts, next));
}

/** Move an existing map placement to its drop index as one reversible edit. */
export function moveMapPlacement(state, arrayPath, fromIndex, toIndex) {
  const parts = pathParts(arrayPath);
  const current = readAt(state.document, parts);
  if (!Array.isArray(current)) throw new TypeError("map placement target must be an array");
  if (![fromIndex, toIndex].every(Number.isInteger) || fromIndex < 0 || fromIndex >= current.length || toIndex < 0 || toIndex >= current.length) {
    throw new RangeError("drag indices are outside the map array");
  }
  if (fromIndex === toIndex) return state;
  const next = [...current];
  const [placement] = next.splice(fromIndex, 1);
  next.splice(toIndex, 0, placement);
  return record(state, writeAt(state.document, parts, next));
}

/** Undo or redo a complete document snapshot; return the same state at an edge. */
export function undoDraft(state) {
  if (!state.past.length) return state;
  const document = state.past.at(-1);
  return makeState(state, document, state.past.slice(0, -1), [state.document, ...state.future].slice(0, state.historyLimit));
}

export function redoDraft(state) {
  if (!state.future.length) return state;
  const document = state.future[0];
  return makeState(state, document, [...state.past, state.document].slice(-state.historyLimit), state.future.slice(1));
}

/** Mark the current immutable snapshot as saved, clearing dirty and history. */
export function markDraftSaved(state) {
  const document = state.document;
  return freezeSnapshot({ ...state, document, baseline: document, baselineJson: JSON.stringify(document), past: [], future: [], dirty: false, canUndo: false, canRedo: false });
}
