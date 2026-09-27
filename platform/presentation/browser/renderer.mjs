/* Canvas2D host adapter for validated M9 scene projections.
 * It consumes numeric CSV only; content and decoded media must come from the
 * trusted Content-0 loader. It never emits simulation commands. */

const MAX_U32 = 0xffffffff;
const MAX_COORD = 524288;
const MAX_NPCS = 64;
const MAX_ACTORS = 64;
const MAX_MAPS = 256;
const MAX_FACES = 256;

function fail(message) { throw new TypeError(`invalid presentation input: ${message}`); }

function token(raw) {
  if (!/^(0|[1-9][0-9]*)$/.test(raw)) fail("CSV fields must be unsigned decimal integers");
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value > MAX_U32) fail("CSV integer exceeds U32");
  return value;
}

function coordinate(sign, magnitude) {
  if (sign > 1 || magnitude > MAX_COORD) fail("coordinate is outside Q10 world bounds");
  if (sign && magnitude === 0) fail("noncanonical negative zero coordinate");
  return sign ? -magnitude : magnitude;
}

function readPoint(values, at) {
  return {
    x: coordinate(values[at], values[at + 1]) / 1024,
    y: coordinate(values[at + 2], values[at + 3]) / 1024,
    z: coordinate(values[at + 4], values[at + 5]) / 1024,
  };
}

/** Parse the exact M9-A version-1 numeric CSV scene wire, with hard count bounds. */
export function parseSceneCsv(csv) {
  if (typeof csv !== "string" || csv.length > 16384 || csv.length === 0) fail("scene wire byte limit");
  const values = csv.split(",").map(token);
  let i = 0;
  const take = () => {
    if (i >= values.length) fail("truncated scene wire");
    return values[i++];
  };
  const takePoint = () => {
    if (i + 6 > values.length) fail("truncated point");
    const result = readPoint(values, i); i += 6; return result;
  };
  if (take() !== 1) fail("unsupported scene wire version");
  const contentIdentity = take();
  const mapId = take();
  const position = takePoint();
  const facing = take();
  if (facing > 3) fail("unknown facing code");
  const cameraAnchor = takePoint();
  const npcCount = take();
  if (npcCount > MAX_NPCS) fail("visible NPC count exceeds 64");
  const npcs = [];
  const npcIds = new Set();
  for (let n = 0; n < npcCount; n++) {
    const id = take();
    if (npcIds.has(id)) fail("duplicate visible NPC ID");
    npcIds.add(id);
    const point = takePoint();
    const eventPresent = take();
    const eventId = take();
    if (eventPresent > 1 || (!eventPresent && eventId !== 0)) fail("invalid optional event ID");
    npcs.push({ id, point, eventId: eventPresent ? eventId : null });
  }
  const battlePresent = take();
  if (battlePresent > 1) fail("invalid battle presence flag");
  let battle = null;
  if (battlePresent) {
    const tick = take(), status = take(), actorCount = take();
    if (status > 7 || actorCount > MAX_ACTORS) fail("battle field exceeds bounds");
    const actors = [];
    const actorIds = new Set();
    for (let n = 0; n < actorCount; n++) {
      const id = take(), side = take(), hp = take(), phase = take();
      if (side > 1 || phase > 4 || actorIds.has(id)) fail("unknown or duplicate battle actor code");
      actorIds.add(id);
      actors.push({ id, side, hp, phase });
    }
    battle = { tick, status, actors };
  }
  if (i !== values.length) fail("trailing scene fields");
  return Object.freeze({ contentIdentity, mapId, position, facing, cameraAnchor, npcs, battle });
}

/** Parse the M9-A cue-list CSV: version,count, then five U32 fields per cue. */
export function parseCueCsv(csv) {
  if (typeof csv !== "string" || csv.length > 16384 || csv.length === 0) fail("cue wire byte limit");
  const values = csv.split(",").map(token);
  if (values.length < 2 || values[0] !== 1 || values[1] > 256 || values.length !== 2 + values[1] * 5) fail("invalid cue wire shape");
  const cues = [];
  let previousOrdinal = -1, previousIndex = -1;
  for (let at = 2; at < values.length; at += 5) {
    const [acceptedOrdinal, cueIndex, kindCode, payload, aux] = values.slice(at, at + 5);
    if (kindCode > 3 || cueIndex > 255 || acceptedOrdinal < previousOrdinal ||
        (acceptedOrdinal === previousOrdinal && cueIndex !== previousIndex + 1) ||
        (acceptedOrdinal > previousOrdinal && cueIndex !== 0)) fail("invalid cue order or code");
    if (((kindCode === 0 || kindCode === 1 || kindCode === 2) && aux !== 0) ||
        (kindCode === 3 && (payload > 2 || (payload === 2 && aux !== 0)))) fail("invalid cue payload");
    const kinds = ["signal", "waited", "asked", "yielded"];
    cues.push(Object.freeze({ acceptedOrdinal, cueIndex, kind: kinds[kindCode], payload, aux }));
    previousOrdinal = acceptedOrdinal; previousIndex = cueIndex;
  }
  return cues;
}

function validateContent(content, scene) {
  if (!content || content.contentIdentity !== scene.contentIdentity || !Array.isArray(content.maps)) fail("content identity mismatch");
  if (content.maps.length > MAX_MAPS || !content.assets || Object.keys(content.assets).length > 256) fail("map or asset count exceeds bounds");
  const map = content.maps.find((row) => row.runtimeId === scene.mapId);
  if (!map || !Array.isArray(map.vertices) || !Array.isArray(map.faces) || !Array.isArray(map.npcs)) fail("scene map is absent from validated content");
  if (!Number.isInteger(map.runtimeId) || map.runtimeId < 1 || map.runtimeId > MAX_MAPS ||
      map.vertices.length > MAX_FACES || map.faces.length > MAX_FACES || map.npcs.length > 256) fail("map presentation count exceeds bounds");
  for (const vertex of map.vertices) q10Point(vertex);
  for (const face of map.faces) {
    if (!Array.isArray(face) || face.length !== 3 || face.some((v) => !Number.isInteger(v) || v < 0 || v >= map.vertices.length)) fail("invalid validated terrain face");
  }
  const npcIds = new Set();
  for (const npc of map.npcs) {
    if (!Number.isInteger(npc.runtimeId) || npc.runtimeId < 1 || npc.runtimeId > 256 || npcIds.has(npc.runtimeId)) fail("invalid NPC runtime ID");
    npcIds.add(npc.runtimeId);
  }
  const profile = map.cameraProfile ?? map.resolvedCameraProfile ?? { fovDegrees: 60, nearQ10: 16, farQ10: 524288 };
  if (!Number.isInteger(profile.fovDegrees) || profile.fovDegrees < 30 || profile.fovDegrees > 90 ||
      !Number.isInteger(profile.nearQ10) || profile.nearQ10 < 1 || profile.nearQ10 > 524287 ||
      !Number.isInteger(profile.farQ10) || profile.farQ10 <= profile.nearQ10 || profile.farQ10 > 524288) fail("invalid camera profile");
  return { map, profile };
}

function cameraAxes(facing) {
  const [dx, dz] = [[0, 1], [1, 0], [0, -1], [-1, 0]][facing];
  const unit = 1 / Math.sqrt(5);
  return { dx, dz, right: [dz, 0, -dx],
    forward: [dx * 2 * unit, -unit, dz * 2 * unit],
    up: [dx * unit, 2 * unit, dz * unit] };
}

function cameraPosition(scene, axes) {
  const anchor = scene.cameraAnchor ?? scene.position;
  return { x: anchor.x - axes.dx * 5, y: anchor.y + 4,
    z: anchor.z - axes.dz * 5 };
}

function cameraDepth(point, scene, axes) {
  const camera = cameraPosition(scene, axes);
  return (point.x - camera.x) * axes.forward[0]
    + (point.y - camera.y) * axes.forward[1]
    + (point.z - camera.z) * axes.forward[2];
}

function clipPlane(points, depthOf, plane, keepFar) {
  const clipped = [];
  for (let index = 0; index < points.length; index++) {
    const a = points[index], b = points[(index + 1) % points.length];
    const da = depthOf(a), db = depthOf(b);
    const insideA = keepFar ? da <= plane : da >= plane;
    const insideB = keepFar ? db <= plane : db >= plane;
    if (insideA) clipped.push(a);
    if (insideA !== insideB && da !== db) {
      const fraction = (plane - da) / (db - da);
      clipped.push({ x: a.x + (b.x - a.x) * fraction,
                     y: a.y + (b.y - a.y) * fraction,
                     z: a.z + (b.z - a.z) * fraction });
    }
  }
  return clipped;
}

function clipTerrain(points, scene, axes, profile) {
  const near = profile.nearQ10 / 1024, far = profile.farQ10 / 1024;
  const depthOf = (point) => cameraDepth(point, scene, axes);
  return clipPlane(clipPlane(points, depthOf, near, false), depthOf, far, true);
}

function project(point, scene, axes, width, height, profile) {
  const camera = cameraPosition(scene, axes);
  const dx = point.x - camera.x, dy = point.y - camera.y,
    dz = point.z - camera.z;
  const depth = cameraDepth(point, scene, axes);
  const side = dx * axes.right[0] + dz * axes.right[2];
  const vertical = dx * axes.up[0] + dy * axes.up[1] + dz * axes.up[2];
  const near = profile.nearQ10 / 1024, far = profile.farQ10 / 1024;
  if (depth < near || depth > far) return null;
  const focal = height * 0.5 / Math.tan(profile.fovDegrees * Math.PI / 360);
  return { x: width / 2 + side * focal / depth,
           y: height / 2 - vertical * focal / depth,
           depth };
}

function q10Point(point) {
  if (!point || ![point.x, point.y, point.z].every((value) => Number.isInteger(value) && Math.abs(value) <= MAX_COORD)) fail("invalid Q10 content coordinate");
  return { x: point.x / 1024, y: point.y / 1024, z: point.z / 1024 };
}

function drawBillboard(ctx, projected, npc, content, size) {
  const row = npc.spriteAssetId == null ? null : content.assets?.[npc.spriteAssetId];
  if (row?.image && typeof ctx.drawImage === "function") {
    ctx.drawImage(row.image, projected.x - size / 2, projected.y - size, size, size);
  } else {
    ctx.fillStyle = "#f4c95d";
    ctx.beginPath(); ctx.arc(projected.x, projected.y - size * 0.55, size * 0.35, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#34291b"; ctx.fillRect(projected.x - size * 0.12, projected.y - size * 0.2, size * 0.24, size * 0.45);
  }
}

/** Draw one frame to a CanvasRenderingContext2D using read-only validated content. */
export function renderScene(ctx, sceneOrCsv, content, cues = []) {
  if (!ctx || typeof ctx.fillRect !== "function") fail("Canvas2D context required");
  const scene = typeof sceneOrCsv === "string" ? parseSceneCsv(sceneOrCsv) : sceneOrCsv;
  if (typeof cues === "string") cues = parseCueCsv(cues);
  if (!Array.isArray(cues) || cues.length > 256) fail("visual cue count exceeds bounds");
  const { map, profile } = validateContent(content, scene);
  const canvas = ctx.canvas;
  const width = canvas.width, height = canvas.height;
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 || width > 4096 || height > 4096) fail("canvas dimensions exceed bounds");
  ctx.fillStyle = "#8bc7df"; ctx.fillRect(0, 0, width, height * 0.56);
  ctx.fillStyle = "#1d2925"; ctx.fillRect(0, height * 0.56, width, height * 0.44);
  const backgroundId = map.backgroundAssetId ?? map.presentation?.background;
  const bg = backgroundId == null ? null : content.assets?.[backgroundId]?.image;
  if (bg && typeof ctx.drawImage === "function") ctx.drawImage(bg, 0, 0, width, height * 0.56);
  const axes = cameraAxes(scene.facing);
  const triangles = map.faces.map((face, order) => {
    const world = clipTerrain(face.map((index) => q10Point(map.vertices[index])), scene, axes, profile);
    const points = world.map((point) => project(point, scene, axes, width, height, profile));
    return { points, order, depth: points.length >= 3 && points.every(Boolean)
      ? points.reduce((sum, p) => sum + p.depth, 0) / points.length : -1 };
  }).filter((item) => item.depth >= 0).sort((a, b) => b.depth - a.depth || a.order - b.order);
  for (const triangle of triangles) {
    ctx.beginPath(); ctx.moveTo(triangle.points[0].x, triangle.points[0].y);
    for (const point of triangle.points.slice(1)) ctx.lineTo(point.x, point.y);
    ctx.closePath();
    ctx.fillStyle = "#527d49"; ctx.fill(); ctx.strokeStyle = "#75975c"; ctx.stroke();
  }
  const boundNpcs = new Map(map.npcs.map((npc) => [npc.runtimeId, npc]));
  const visible = scene.npcs.map((row) => {
    const authored = boundNpcs.get(row.id);
    if (!authored) fail("visible NPC ID is absent from active map");
    const point = project(row.point, scene, axes, width, height, profile);
    return point ? { authored, point } : null;
  }).filter(Boolean).sort((a, b) => b.point.depth - a.point.depth || a.authored.runtimeId - b.authored.runtimeId);
  for (const { authored, point } of visible) drawBillboard(ctx, point, authored, content, Math.max(8, Math.min(72, height * 1.2 / point.depth)));
  // The camera follows the player, so their world point projects behind the
  // near plane. Draw an anchored avatar that cannot affect movement or hits.
  ctx.fillStyle = "#182d42";
  ctx.fillRect(width / 2 - 9, height * 0.82, 18, 34);
  ctx.fillStyle = "#82c7f7";
  ctx.beginPath(); ctx.arc(width / 2, height * 0.79, 12, 0, Math.PI * 2); ctx.fill();
  for (const cue of cues) {
    if (cue.kind !== "signal") continue;
    ctx.strokeStyle = "#ffe46b";
    ctx.beginPath(); ctx.arc(width / 2, height * 0.8, 28, 0, Math.PI * 2); ctx.stroke();
  }
  if (scene.battle) {
    ctx.fillStyle = "rgba(18, 22, 31, 0.82)"; ctx.fillRect(12, 12, Math.min(width - 24, 220), 20 + scene.battle.actors.length * 16);
    ctx.fillStyle = "#ffffff"; ctx.font = "12px sans-serif"; ctx.fillText(`Battle ${scene.battle.tick}`, 20, 27);
    scene.battle.actors.forEach((actor, index) => {
      ctx.fillStyle = actor.side === 0 ? "#83c8ff" : "#ff9b87";
      ctx.fillText(`Actor ${actor.id}  HP ${actor.hp}`, 20, 43 + index * 16);
    });
  }
  return scene;
}

/** Play only semantic Signal cues. Audio buffers are host-decoded from validated WAV assets. */
export function deliverCues(cues, audioBindings, audioContext) {
  if (typeof cues === "string") cues = parseCueCsv(cues);
  if (!Array.isArray(cues) || cues.length > 256 || !Array.isArray(audioBindings) || audioBindings.length > 256) fail("cue/binding count exceeds bounds");
  let lastOrdinal = -1, lastIndex = -1;
  for (const cue of cues) {
    if (!Number.isInteger(cue.acceptedOrdinal) || cue.acceptedOrdinal < lastOrdinal || cue.acceptedOrdinal > MAX_U32 ||
        !Number.isInteger(cue.cueIndex) || cue.cueIndex < 0 || cue.cueIndex > 255 ||
        (cue.acceptedOrdinal === lastOrdinal && cue.cueIndex !== lastIndex + 1) ||
        (cue.acceptedOrdinal > lastOrdinal && cue.cueIndex !== 0) ||
        !["signal", "waited", "asked", "yielded"].includes(cue.kind) ||
        !Number.isInteger(cue.payload) || cue.payload < 0 || cue.payload > MAX_U32 ||
        !Number.isInteger(cue.aux ?? 0) || (cue.aux ?? 0) < 0 || (cue.aux ?? 0) > MAX_U32) fail("invalid cue record");
    lastOrdinal = cue.acceptedOrdinal; lastIndex = cue.cueIndex;
  }
  const bindingIds = new Set();
  for (const binding of audioBindings) {
    if (!Number.isInteger(binding.signalKind) || binding.signalKind < 0 || binding.signalKind > 999999999 || bindingIds.has(binding.signalKind)) fail("invalid audio binding");
    bindingIds.add(binding.signalKind);
  }
  if (!audioContext || typeof audioContext.createBufferSource !== "function") return 0;
  const bySignal = new Map(audioBindings.map((row) => [row.signalKind, row.buffer]));
  let played = 0;
  for (const cue of cues) {
    if (!Number.isInteger(cue.acceptedOrdinal) || cue.acceptedOrdinal < 0 || cue.acceptedOrdinal > MAX_U32 ||
        !Number.isInteger(cue.cueIndex) || cue.cueIndex < 0 || cue.cueIndex > 255) fail("invalid cue occurrence ID");
    if (cue.kind !== "signal") continue;
    const buffer = bySignal.get(cue.payload);
    if (!buffer) continue;
    const source = audioContext.createBufferSource();
    source.buffer = buffer; source.connect(audioContext.destination); source.start(); played++;
  }
  return played;
}
