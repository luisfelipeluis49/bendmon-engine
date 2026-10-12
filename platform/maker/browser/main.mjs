import { addDocument, createDraftState, markDraftSaved, redoDraft, removeDocument, undoDraft, updatePath } from "./state.mjs";
import { contentKind, newDocument, renderFields } from "./forms.mjs";
import { renderMap } from "./map.mjs";
import { parseCueCsv, parseSceneCsv, renderScene } from "/m9-renderer.mjs";

const $ = selector => document.querySelector(selector);
const CATEGORY = {
  map: { title: "Map", kinds: ["map"] },
  catalog: { title: "Monsters", kinds: ["catalog"] },
  moves: { title: "Moves & mixes", kinds: ["move", "recipe", "result"] },
  encounters: { title: "Encounters", kinds: ["encounter"] },
  trainers: { title: "Trainers & NPCs", kinds: ["trainer", "map"] },
  story: { title: "Dialogue & events", kinds: ["dialogue", "event"] },
  items: { title: "Items & shops", kinds: ["item", "shop"] },
  assets: { title: "Assets & audio", kinds: ["manifest"] },
  project: { title: "Project", kinds: ["project", "manifest"] },
};
const MANIFEST_KEY = { catalog: "catalogs", map: "maps", encounter: "encounters", move: "moves",
                       recipe: "mixRecipes", result: "mixResults", item: "items", shop: "shops", event: "events",
                       trainer: "trainers", dialogue: "dialogues" };
const FOLDER = { catalog: "catalogs", map: "maps", encounter: "encounters", move: "moves",
                 recipe: "mix-recipes", result: "mix-results", item: "items", shop: "shops", event: "events",
                 trainer: "trainers", dialogue: "dialogues" };
let activeProject = null;
let draft = null;
let category = "map";
let selectedFile = null;
let selectedPlacement = null;
let diagnostics = [];
let mapCleanup = null;
let livePlaytest = null;
let playtestBusy = false;

function node(tag, className, label) {
  const item = document.createElement(tag);
  if (className) item.className = className;
  if (label !== undefined) item.textContent = label;
  return item;
}

function toast(message) {
  $("#toast").textContent = message;
  window.clearTimeout(toast.timeout);
  toast.timeout = window.setTimeout(() => { $("#toast").textContent = ""; }, 5000);
}

async function request(path, method = "GET", body = undefined) {
  const response = await fetch(path, { method, headers: body === undefined ? {} : { "Content-Type": "application/json" },
                                       body: body === undefined ? undefined : JSON.stringify(body) });
  let payload;
  try { payload = await response.json(); }
  catch { throw new Error(`Maker server returned HTTP ${response.status} without JSON`); }
  if (!response.ok || !payload.ok) throw new Error(payload.error?.message || `HTTP ${response.status}`);
  return payload;
}

function namespace() {
  return String(draft?.document["project.json"]?.id || "maker:project").split(":")[0];
}

function filesFor(kinds) {
  return Object.keys(draft.document).filter(file => kinds.includes(contentKind(file, draft.document[file]))).sort();
}

function refreshChrome() {
  $("#dirty").textContent = draft?.dirty ? "Unsaved draft" : "Saved";
  $("#undo").disabled = !draft?.canUndo;
  $("#redo").disabled = !draft?.canRedo;
  for (const button of document.querySelectorAll(".sidebar button[data-tool]")) {
    button.classList.toggle("active", button.dataset.tool === category);
  }
  $("#section-title").textContent = CATEGORY[category].title;
}

function commit(parts, value) {
  try {
    draft = updatePath(draft, parts, value);
    diagnostics = [];
    render();
  } catch (error) { toast(error.message); }
}

function renderValidation() {
  const container = $("#validation"); container.replaceChildren();
  if (!diagnostics.length) { container.textContent = "Validate to check the current draft."; return; }
  for (const diagnostic of diagnostics) {
    const button = node("button", "diagnostic", `${diagnostic.file}${diagnostic.pointer}: ${diagnostic.message}`);
    button.type = "button";
    button.onclick = () => { selectedFile = diagnostic.file; selectedPlacement = null; render(); };
    container.append(button);
  }
}

function renderInspector() {
  const panel = $("#inspector-content"); panel.replaceChildren();
  if (!selectedFile || !draft.document[selectedFile]) { panel.textContent = "Select a document or map placement."; return; }
  const doc = draft.document[selectedFile];
  panel.append(node("p", "json-note", selectedFile));
  if (selectedPlacement?.file === selectedFile && doc[selectedPlacement.kind]?.[selectedPlacement.index]) {
    panel.append(node("h3", "", `${selectedPlacement.kind} ${selectedPlacement.index + 1}`));
    renderFields(panel, doc[selectedPlacement.kind][selectedPlacement.index],
                 [selectedFile, selectedPlacement.kind, selectedPlacement.index], commit, diagnostics, namespace());
  } else panel.append(node("p", "json-note", "Select a placement on the map to inspect it. Edit document fields in the center panel."));
}

function selectFile(file) { selectedFile = file; selectedPlacement = null; render(); }

function documentRow(file) {
  const row = node("div", "list-row");
  const doc = draft.document[file];
  const title = node("button", "", doc.name || doc.id || file);
  title.type = "button"; title.title = file; title.onclick = () => selectFile(file);
  row.append(title, node("span", "json-note", file));
  if (!["project.json", "manifest.json"].includes(file)) {
    const remove = node("button", "", "Delete"); remove.type = "button";
    remove.onclick = () => {
      const manifest = draft.document["manifest.json"];
      const kind = contentKind(file, doc), key = MANIFEST_KEY[kind];
      draft = removeDocument(draft, file);
      if (key && Array.isArray(manifest[key])) draft = updatePath(draft, ["manifest.json", key], manifest[key].filter(path => path !== file));
      if (selectedFile === file) selectedFile = null;
      render();
    };
    row.append(remove);
  }
  return row;
}

function addContent(kind) {
  const existing = Object.keys(draft.document);
  let serial = 1, file;
  do { file = `${FOLDER[kind]}/${kind}-${serial}.json`; serial++; } while (existing.includes(file));
  const doc = newDocument(kind, namespace(), serial - 1);
  try {
    draft = addDocument(draft, file, doc);
    const key = MANIFEST_KEY[kind], manifest = draft.document["manifest.json"];
    if (!Array.isArray(manifest[key])) commit(["manifest.json"], { ...manifest, [key]: [file] });
    else draft = updatePath(draft, ["manifest.json", key], [...manifest[key], file]);
    selectedFile = file;
    render();
  } catch (error) { toast(error.message); }
}

function renderDocumentCards(container, kinds) {
  const files = filesFor(kinds);
  const list = node("div", "list");
  for (const file of files) list.append(documentRow(file));
  container.append(list);
  const toolbar = node("div", "toolbar");
  for (const kind of kinds.filter(item => FOLDER[item])) {
    const add = node("button", "", `Add ${kind}`); add.type = "button"; add.onclick = () => addContent(kind);
    toolbar.append(add);
  }
  container.prepend(toolbar);
  if (selectedFile && kinds.includes(contentKind(selectedFile, draft.document[selectedFile])) && draft.document[selectedFile]) {
    const card = node("div", "card"); card.append(node("h2", "", draft.document[selectedFile].name || draft.document[selectedFile].id || selectedFile));
    renderFields(card, draft.document[selectedFile], [selectedFile], commit, diagnostics, namespace());
    container.append(card);
  }
}

function renderMapEditor(container) {
  renderDocumentCards(container, ["map"]);
  const mapFile = selectedFile && contentKind(selectedFile, draft.document[selectedFile]) === "map" ? selectedFile : filesFor(["map"])[0];
  if (!mapFile) return;
  const map = draft.document[mapFile];
  const card = node("div", "card"); card.append(node("h2", "", `${map.name} canvas`));
  const project = draft.document["project.json"];
  const entryMap = project?.entryMap === map.id;
  mapCleanup = renderMap(card, map, mapFile, namespace(), commit,
                         selection => { selectedFile = mapFile; selectedPlacement = selection; renderInspector(); }, selectedPlacement,
                         entryMap ? project.entryPoint : null,
                         entryMap ? point => commit(["project.json"], { ...project, entryPoint: point }) : null);
  container.prepend(card);
}

function renderTrainers(container) {
  const note = node("div", "card");
  note.append(node("h2", "", "NPC placement"));
  note.append(node("p", "", "Place characters on the Map canvas, then assign an event and sprite in the inspector. Trainer battle and training data need a versioned content contract before this editor can expose them."));
  const open = node("button", "", "Open map canvas"); open.type = "button";
  open.onclick = () => { category = "map"; render(); };
  note.append(open); container.append(note);
  renderDocumentCards(container, ["trainer", "map"]);
}

function renderStory(container) {
  const note = node("div", "card");
  note.append(node("h2", "", "Event graph"));
  note.append(node("p", "", "Write dialogue lines and bounded event nodes. NPCs may reference a dialogue and an event."));
  container.append(note); renderDocumentCards(container, ["dialogue", "event"]);
}

async function importAsset(file, assetId) {
  if (draft.dirty) await saveDraft();
  const bytes = new Uint8Array(await file.arrayBuffer());
  let binary = ""; for (const byte of bytes) binary += String.fromCharCode(byte);
  const extension = file.name.split(".").at(-1).toLowerCase();
  const mediaType = { png: "image/png", ppm: "image/x-portable-pixmap", wav: "audio/wav" }[extension];
  if (!mediaType) throw new Error("Import a PNG, PPM, or WAV file");
  const safeName = file.name.replace(/[^A-Za-z0-9_.-]/g, "-");
  const payload = await request(`/api/projects/${activeProject}/assets`, "POST", {
    path: `assets/${safeName}`, mediaType, contentBase64: btoa(binary), assetId,
  });
  draft = createDraftState(payload.project.documents);
  toast(`Imported ${file.name} as ${payload.assetId}`); render();
}

function renderAssets(container) {
  const card = node("div", "card"); card.append(node("h2", "", "Import image or audio"));
  const id = node("input"); id.placeholder = `${namespace()}:asset-name`;
  const input = node("input"); input.type = "file"; input.accept = ".png,.ppm,.wav";
  const button = node("button", "", "Import asset"); button.type = "button";
  button.onclick = () => {
    if (!input.files?.length) { toast("Choose an asset first"); return; }
    importAsset(input.files[0], id.value.trim() || undefined).catch(error => toast(error.message));
  };
  card.append(id, input, button); container.append(card);
  renderDocumentCards(container, ["manifest"]);
}

function render() {
  if (!draft) return;
  mapCleanup?.(); mapCleanup = null;
  refreshChrome(); renderValidation(); renderInspector();
  const editor = $("#editor"); editor.replaceChildren();
  if (category === "map") renderMapEditor(editor);
  else if (category === "trainers") renderTrainers(editor);
  else if (category === "story") renderStory(editor);
  else if (category === "assets") renderAssets(editor);
  else renderDocumentCards(editor, CATEGORY[category].kinds);
}

async function listProjects(preferred = null) {
  const payload = await request("/api/projects");
  const select = $("#projects"); select.replaceChildren();
  for (const project of payload.projects) {
    const option = node("option", "", project.name || project.projectId); option.value = project.id; select.append(option);
  }
  if (preferred && payload.projects.some(row => row.id === preferred)) select.value = preferred;
  if (select.value) await openProject(select.value);
  else { $("#editor").textContent = "Create a project to begin."; $("#inspector-content").textContent = "No project open."; }
}

async function openProject(id) {
  if (activeProject && id !== activeProject && draft?.dirty) await saveDraft();
  const payload = await request(`/api/projects/${id}`);
  activeProject = id; draft = createDraftState(payload.project.documents);
  selectedFile = filesFor(["map"])[0] || "project.json";
  selectedPlacement = null; diagnostics = []; render();
}

async function saveDraft() {
  if (!activeProject || !draft) throw new Error("Open a project first");
  const payload = await request(`/api/projects/${activeProject}/documents`, "PUT", { documents: draft.document });
  draft = markDraftSaved(createDraftState(payload.project.documents));
  toast("Draft saved"); render();
}

async function validateDraft() {
  if (draft.dirty) await saveDraft();
  const payload = await request(`/api/projects/${activeProject}/validate`, "POST", {});
  diagnostics = payload.valid ? [] : payload.diagnostics;
  render();
  if (payload.valid) toast(`Valid content ${payload.contentHash.slice(0, 12)}`);
  else toast(`${diagnostics.length} validation issue${diagnostics.length === 1 ? "" : "s"}`);
  return payload;
}

async function exportDraft() {
  const checked = await validateDraft();
  if (!checked.valid) return;
  const result = await request(`/api/projects/${activeProject}/export`, "POST", {});
  if (!result.valid) { diagnostics = result.diagnostics; render(); return; }
  toast(`Exported frozen content ${result.contentHash.slice(0, 12)}`);
}

async function startPlaytest() {
  $("#playtest-panel").hidden = false;
  $("#playtest-content").textContent = "A playtest uses the current validated draft; choose the canonical RNG words above.";
}

function playtestCueText(cues) {
  return cues.length ? cues.map(cue => `${cue.kind} #${cue.acceptedOrdinal}.${cue.cueIndex}`).join(" · ")
    : "No new presentation cues.";
}

function renderPlaytest(result) {
  const scene = parseSceneCsv(result.sceneCsv);
  const cues = parseCueCsv(result.cuesCsv);
  const content = result.presentation || livePlaytest?.presentation;
  renderScene($("#playtest-scene").getContext("2d"), scene, content, cues);
  const npcs = $("#playtest-npc"); npcs.replaceChildren();
  for (const npc of scene.npcs) {
    const option = node("option", "", `Character ${npc.id}`); option.value = String(npc.id); npcs.append(option);
  }
  $("#playtest-status").textContent = result.status === "battle"
    ? `Encounter ${result.encounterId} · battle tick ${scene.battle?.tick ?? 0}. Choose a command when your monster is ready, then advance.`
    : result.status === "encounter"
      ? `Encounter ${result.encounterId} needs a starter before battle can begin.`
      : `Map ${scene.mapId} · position ${scene.position.x.toFixed(2)}, ${scene.position.z.toFixed(2)} · ${result.acceptedCommands} commands`;
  const dialogue = result.dialogue;
  $("#playtest-dialogue").hidden = !dialogue;
  if (dialogue) {
    $("#playtest-speaker").textContent = dialogue.speaker;
    $("#playtest-line").textContent = dialogue.text;
  }
  $("#playtest-cues").textContent = playtestCueText(cues);
  $("#playtest-live").hidden = false;
  const battle = result.status === "battle";
  const moveSelect = $("#playtest-battle-move"); moveSelect.replaceChildren();
  for (const move of content?.starterMoves || []) {
    const option = node("option", "", move.name); option.value = String(move.runtimeId);
    moveSelect.append(option);
  }
  moveSelect.disabled = !battle || !moveSelect.options.length;
  const playerReady = scene.battle?.actors?.some(actor => actor.id === 0 && actor.phase === 0) ?? false;
  for (const button of $("#playtest-live").querySelectorAll("button")) {
    if (button.dataset.playtestBattle !== undefined) {
      button.disabled = !battle || (button.id !== "playtest-battle-advance" && !playerReady);
      if (button.id === "playtest-battle-attack") button.disabled ||= !moveSelect.options.length;
    } else {
      button.disabled = ["encounter", "battle"].includes(result.status) ||
        (dialogue ? button.id !== "playtest-advance-dialogue"
          : button.id === "playtest-advance-dialogue") ||
        (button.id === "playtest-interact" && !scene.npcs.length);
    }
  }
  livePlaytest = { ...result, presentation: content, scene };
}

async function sendPlaytestCommand(command) {
  if (!livePlaytest || playtestBusy || livePlaytest.status === "encounter") return;
  playtestBusy = true;
  try {
    const result = await request(`/api/playtests/${livePlaytest.sessionId}/commands`, "POST", {
      command, expectedCommands: livePlaytest.acceptedCommands,
    });
    if (result.rejected) {
      $("#playtest-status").textContent = "That command has no effect in the current state.";
      return;
    }
    renderPlaytest(result);
  } catch (error) { $("#playtest-status").textContent = error.message; }
  finally { playtestBusy = false; }
}

function interactCommand() {
  const npcId = Number($("#playtest-npc").value);
  const npc = livePlaytest?.scene.npcs.find(row => row.id === npcId);
  if (!npc) return null;
  const dx = npc.point.x - livePlaytest.scene.position.x;
  const dz = npc.point.z - livePlaytest.scene.position.z;
  return { kind: "interact", npcId,
           facingX: Math.sign(dx) * 1024, facingZ: Math.sign(dz) * 1024 };
}

async function launchPlaytest() {
  const words = [...document.querySelectorAll("#rng-fields input")].map(input => Number(input.value));
  if (words.length !== 4 || words.some(word => !Number.isInteger(word) || word < 0 || word > 4294967295) || !words.some(Boolean)) {
    $("#playtest-content").textContent = "Enter four whole RNG words in 0..4294967295, with at least one nonzero.";
    return;
  }
  const checked = await validateDraft();
  if (!checked.valid) return;
  $("#playtest-content").textContent = "Starting validated playtest…";
  try {
    const result = await request(`/api/projects/${activeProject}/playtest`, "POST", {
      rngState: words, waitTicks: Number($("#playtest-wait").value), contentHash: checked.contentHash,
    });
    renderPlaytest(result);
    $("#playtest-content").textContent = `Playing frozen content ${result.contentHash.slice(0, 12)}.`;
  } catch (error) { $("#playtest-content").textContent = `Playtest unavailable: ${error.message}`; }
}

function setupControls() {
  for (const button of document.querySelectorAll(".sidebar button[data-tool]")) {
    button.onclick = () => { category = button.dataset.tool; selectedPlacement = null; render(); };
  }
  $("#projects").onchange = event => openProject(event.target.value).catch(error => {
    event.target.value = activeProject;
    toast(error.message);
  });
  $("#create").onclick = () => {
    $("#new-project-field").hidden = false;
    $("#create-action").hidden = false;
    $("#new-project-name").focus();
  };
  $("#create-action").onclick = async () => {
    const name = $("#new-project-name").value.trim();
    if (!name) { toast("Enter a project name"); return; }
    try {
      if (draft?.dirty) await saveDraft();
      const payload = await request("/api/projects", "POST", { name });
      $("#new-project-field").hidden = true; $("#create-action").hidden = true;
      await listProjects(payload.project.id);
    } catch (error) { toast(error.message); }
  };
  $("#undo").onclick = () => { draft = undoDraft(draft); render(); };
  $("#redo").onclick = () => { draft = redoDraft(draft); render(); };
  $("#save").onclick = () => saveDraft().catch(error => toast(error.message));
  $("#validate").onclick = () => validateDraft().catch(error => toast(error.message));
  $("#export").onclick = () => exportDraft().catch(error => toast(error.message));
  $("#playtest").onclick = () => startPlaytest().catch(error => toast(error.message));
  $("#launch-playtest").onclick = () => launchPlaytest().catch(error => { $("#playtest-content").textContent = error.message; });
  $("#close-playtest").onclick = () => { $("#playtest-panel").hidden = true; };
  for (const button of document.querySelectorAll("[data-playtest-move]")) {
    button.onclick = () => {
      const direction = { north: [0, 1024], south: [0, -1024],
                          east: [1024, 0], west: [-1024, 0] }[button.dataset.playtestMove];
      sendPlaytestCommand({ kind: "move", x: direction[0], z: direction[1],
                            analog: false, sprint: $("#playtest-sprint").checked });
    };
  }
  $("#playtest-interact").onclick = () => { const command = interactCommand(); if (command) sendPlaytestCommand(command); };
  $("#playtest-continue").onclick = () => sendPlaytestCommand({ kind: "continueEvent" });
  $("#playtest-advance-dialogue").onclick = () => sendPlaytestCommand({ kind: "advanceDialogue" });
  $("#playtest-yes").onclick = () => sendPlaytestCommand({ kind: "chooseEvent", yes: true });
  $("#playtest-no").onclick = () => sendPlaytestCommand({ kind: "chooseEvent", yes: false });
  $("#playtest-battle-wait").onclick = () => sendPlaytestCommand({ kind: "battleWait", actorId: 0 });
  $("#playtest-battle-attack").onclick = () => sendPlaytestCommand({ kind: "battleMove", actorId: 0,
    targetId: 1, moveId: Number($("#playtest-battle-move").value) });
  $("#playtest-battle-escape").onclick = () => sendPlaytestCommand({ kind: "battleEscape", actorId: 0 });
  $("#playtest-battle-advance").onclick = () => sendPlaytestCommand({ kind: "advanceBattle" });
  document.addEventListener("keydown", event => {
    if (!(event.ctrlKey || event.metaKey) || event.key.toLowerCase() !== "z" || !draft) return;
    event.preventDefault(); draft = event.shiftKey ? redoDraft(draft) : undoDraft(draft); render();
  });
}

setupControls();
listProjects().catch(error => toast(error.message));
