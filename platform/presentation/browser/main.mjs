import { deliverCues, parseCueCsv, parseSceneCsv, renderScene } from "./renderer.mjs";

const status = document.querySelector("#status");
const canvas = document.querySelector("#scene");
const playButton = document.querySelector("#play");

async function fetchJson(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`Could not load ${path}: HTTP ${response.status}`);
  return response.json();
}

async function fetchText(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`Could not load ${path}: HTTP ${response.status}`);
  return response.text();
}

async function main() {
  const [content, sceneWire, cueWire] = await Promise.all([
    fetchJson("./content.json"), fetchText("./scene.csv"), fetchText("./cues.csv"),
  ]);
  const scene = parseSceneCsv(sceneWire.trim());
  const cues = parseCueCsv(cueWire.trim());
  const imageAssets = {};
  const audioAssets = {};
  await Promise.all(Object.entries(content.assets).map(async ([id, record]) => {
    if (record.image) {
      const image = new Image();
      image.src = record.image;
      await image.decode();
      imageAssets[id] = { image };
    }
    if (record.audio) audioAssets[id] = await fetch(record.audio).then((response) => {
      if (!response.ok) throw new Error(`Could not load ${record.audio}`);
      return response.arrayBuffer();
    });
  }));
  const ctx = canvas.getContext("2d");
  renderScene(ctx, scene, { ...content, assets: imageAssets }, cues);
  status.textContent = `Loaded map ${scene.mapId}; ${scene.npcs.length} visible NPCs; ${cues.length} cues.`;
  playButton.addEventListener("click", async () => {
    const audioContext = new AudioContext();
    await audioContext.resume();
    const bindings = await Promise.all(content.audioBindings.map(async ({ signalKind, assetId }) => ({
      signalKind, buffer: await audioContext.decodeAudioData(audioAssets[assetId].slice(0)),
    })));
    const played = deliverCues(cues, bindings, audioContext);
    status.textContent = `Played ${played} signal cue${played === 1 ? "" : "s"}.`;
  });
}

main().catch((error) => {
  status.textContent = `Preview failed: ${error.message}`;
  console.error(error);
});
