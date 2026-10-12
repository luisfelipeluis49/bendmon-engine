function el(tag, className, label) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (label !== undefined) node.textContent = label;
  return node;
}

function mapPoint(map, x, z, width, height) {
  return { x: 24 + x * (width - 48) / Math.max(1024, map.width * 1024),
           y: 24 + z * (height - 48) / Math.max(1024, map.height * 1024) };
}

function triangleWeights(point, a, b, c) {
  const denominator = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
  if (Math.abs(denominator) < 1e-8) return null;
  const first = ((b.y - c.y) * (point.x - c.x) + (c.x - b.x) * (point.y - c.y)) / denominator;
  const second = ((c.y - a.y) * (point.x - c.x) + (a.x - c.x) * (point.y - c.y)) / denominator;
  const third = 1 - first - second;
  return first >= -1e-7 && second >= -1e-7 && third >= -1e-7 ? [first, second, third] : null;
}

function screenPoint(canvas, event) {
  const box = canvas.getBoundingClientRect();
  return { x: event.clientX - box.left, y: event.clientY - box.top, width: box.width, height: box.height };
}

function surfaceAt(map, point, width, height) {
  const vertices = map.navigation?.vertices || [];
  for (const [index, face] of (map.navigation?.faces || []).entries()) {
    if (face.length !== 3 || face.some(vertexIndex => !vertices[vertexIndex])) continue;
    const points = face.map(vertexIndex => {
      const vertex = vertices[vertexIndex];
      return mapPoint(map, vertex.x, vertex.z, width, height);
    });
    const weights = triangleWeights(point, ...points);
    if (!weights) continue;
    const world = ["x", "y", "z"].map(axis => Math.round(face.reduce((sum, vertexIndex, i) =>
      sum + vertices[vertexIndex][axis] * weights[i], 0)));
    return { face: index, vertices: [...face], x: world[0], y: world[1], z: world[2] };
  }
  return null;
}

function nearestNpc(canvas, map, event) {
  const cursor = screenPoint(canvas, event);
  let nearest = -1, distance = 14;
  (map.npcs || []).forEach((npc, index) => {
    const point = mapPoint(map, npc.x, npc.z, cursor.width, cursor.height);
    const current = Math.hypot(point.x - cursor.x, point.y - cursor.y);
    if (current < distance) { nearest = index; distance = current; }
  });
  return nearest;
}

function nearestVertex(canvas, map, event) {
  const cursor = screenPoint(canvas, event);
  let nearest = -1, distance = 13;
  (map.navigation?.vertices || []).forEach((vertex, index) => {
    const point = mapPoint(map, vertex.x, vertex.z, cursor.width, cursor.height);
    const current = Math.hypot(point.x - cursor.x, point.y - cursor.y);
    if (current < distance) { nearest = index; distance = current; }
  });
  return nearest;
}

function hasSameFace(faces, vertices) {
  const candidate = [...vertices].sort((a, b) => a - b).join(":");
  return faces.some(face => [...face].sort((a, b) => a - b).join(":") === candidate);
}

function linksForFace(faces, links, newFaceIndex) {
  const linksOut = [...links];
  const face = faces[newFaceIndex];
  for (let index = 0; index < newFaceIndex; index++) {
    const shared = faces[index].filter(vertex => face.includes(vertex));
    if (shared.length >= 2) {
      linksOut.push({ from_face: index, to_face: newFaceIndex },
                    { from_face: newFaceIndex, to_face: index });
    }
  }
  return linksOut;
}

function nearestPlacement(canvas, map, event) {
  const point = screenPoint(canvas, event);
  const surface = surfaceAt(map, point, point.width, point.height);
  if (surface) {
    const index = (map.encounterRegions || []).findIndex(region => (region.faces || []).includes(surface.face));
    if (index >= 0) return { kind: "encounterRegions", index };
  }
  const vertex = nearestVertex(canvas, map, event);
  if (vertex < 0) return null;
  for (const kind of ["triggers", "transitions"]) {
    const index = (map[kind] || []).findIndex(item => (item.vertices || []).includes(vertex));
    if (index >= 0) return { kind, index };
  }
  return null;
}

function selectedGeometry(map, selected) {
  if (!selected) return { faces: [], vertices: [] };
  const item = map[selected.kind]?.[selected.index];
  if (!item) return { faces: [], vertices: [] };
  if (selected.kind === "encounterRegions") return { faces: item.faces || [], vertices: [] };
  if (selected.kind === "triggers" || selected.kind === "transitions") return { faces: [], vertices: item.vertices || [] };
  return { faces: [], vertices: [] };
}

function drawScene(canvas, map, selected, preview, pending, startPoint) {
  const box = canvas.getBoundingClientRect();
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.max(320, Math.round(box.width * ratio));
  canvas.height = Math.max(240, Math.round(box.height * ratio));
  const context = canvas.getContext("2d");
  context.scale(ratio, ratio);
  const width = canvas.width / ratio, height = canvas.height / ratio;
  context.fillStyle = "#142a2c"; context.fillRect(0, 0, width, height);
  context.strokeStyle = "#34544d"; context.lineWidth = 1;
  for (let step = 0; step <= 8; step++) {
    const x = 24 + step * (width - 48) / 8, y = 24 + step * (height - 48) / 8;
    context.beginPath(); context.moveTo(x, 24); context.lineTo(x, height - 24); context.stroke();
    context.beginPath(); context.moveTo(24, y); context.lineTo(width - 24, y); context.stroke();
  }
  const vertices = map.navigation?.vertices || [];
  const selectedBits = selectedGeometry(map, selected);
  const highlightedFaces = new Set([...selectedBits.faces, ...(pending.face === undefined ? [] : [pending.face])]);
  const highlightedVertices = new Set([...selectedBits.vertices, ...pending.vertices]);
  for (const [index, face] of (map.navigation?.faces || []).entries()) {
    if (face.length !== 3 || face.some(v => !vertices[v])) continue;
    context.beginPath();
    face.forEach((vertexIndex, i) => {
      const vertex = vertices[vertexIndex];
      const point = mapPoint(map, vertex.x, vertex.z, width, height);
      if (!i) context.moveTo(point.x, point.y); else context.lineTo(point.x, point.y);
    });
    context.closePath();
    context.fillStyle = highlightedFaces.has(index) ? "#9a7145" : "#365c4a"; context.fill();
    context.strokeStyle = highlightedFaces.has(index) ? "#ffd18c" : "#78a889"; context.stroke();
    context.fillStyle = "#c7e5c4"; context.font = "12px system-ui";
    const center = face.reduce((point, vertexIndex) => {
      const vertex = vertices[vertexIndex];
      const p = mapPoint(map, vertex.x, vertex.z, width, height);
      return { x: point.x + p.x / 3, y: point.y + p.y / 3 };
    }, { x: 0, y: 0 });
    context.fillText(String(index), center.x, center.y);
  }
  for (const [index, vertex] of vertices.entries()) {
    const point = mapPoint(map, vertex.x, vertex.z, width, height);
    context.beginPath(); context.arc(point.x, point.y, highlightedVertices.has(index) ? 7 : 4, 0, 2 * Math.PI);
    context.fillStyle = highlightedVertices.has(index) ? "#ffd18c" : "#c7e5c4"; context.fill();
    context.fillStyle = "#eaf9ee"; context.fillText(String(index), point.x + 7, point.y - 6);
  }
  for (const [index, npc] of (map.npcs || []).entries()) {
    const point = mapPoint(map, npc.x, npc.z, width, height);
    const active = selected?.kind === "npcs" && selected.index === index;
    context.beginPath(); context.arc(point.x, point.y, active ? 10 : 8, 0, 2 * Math.PI);
    context.fillStyle = active ? "#ffce85" : "#8ec7d5"; context.fill();
    context.strokeStyle = "#0b1719"; context.stroke();
    context.fillStyle = "#eaf9ee"; context.fillText(npc.name || npc.id, point.x + 12, point.y + 4);
  }
  if (startPoint) {
    const point = mapPoint(map, startPoint.x, startPoint.z, width, height);
    context.beginPath(); context.arc(point.x, point.y, 9, 0, 2 * Math.PI);
    context.fillStyle = "#ffdf70"; context.fill();
    context.strokeStyle = "#283321"; context.stroke();
    context.fillStyle = "#fff4bf"; context.fillText("START", point.x + 12, point.y + 4);
  }
  if (preview) {
    const point = mapPoint(map, preview.x, preview.z, width, height);
    context.beginPath(); context.arc(point.x, point.y, 8, 0, 2 * Math.PI);
    context.fillStyle = "#ffce85"; context.fill();
  }
  context.fillStyle = "#bad2c7";
  context.fillText("X →", 28, height - 8);
  context.fillText("Z ↓", width - 48, 20);
}

/** Render the top-down maker canvas; coordinates are Content-0 Q10 values. */
export function renderMap(container, map, file, namespace, onEdit, onSelect, selected,
                          startPoint = null, onSetStart = null) {
  const toolbar = el("div", "toolbar palette");
  const options = [["select", "Select / drag NPC"], ["vertex", "Add navigation vertex"],
                   ["face", "Add navigation face"], ["npc", "Place NPC"], ["trigger", "Place trigger"],
                   ["region", "Place encounter region"], ["transition", "Place transition"]];
  if (onSetStart) options.push(["start", "Set starting point"]);
  let tool = "select", drag = -1, draggedPoint = null;
  let currentMap = map, currentSelected = selected;
  const pending = { vertices: [] };
  const help = el("p", "map-help");
  const messages = {
    select: "Drag an NPC to move it. Click a placement to inspect it.",
    vertex: "Click the map to add a flat navigation vertex. The surface supports at most 256 vertices.",
    face: "Click three distinct navigation vertices to add a face. Shared edges are linked automatically.",
    npc: "Click a navigable face to place an NPC on its surface.",
    trigger: "Click three distinct navigation vertices to define a trigger.",
    region: "Click a navigation face to make an encounter region.",
    transition: "Click a navigation face, then click a point inside it to place a transition.",
    start: "Click a navigable face to set the player's starting point.",
  };
  const wrap = el("div", "map-wrap");
  const canvas = el("canvas"); canvas.id = "map-canvas";
  canvas.setAttribute("aria-label", "Map canvas for " + map.name);
  wrap.append(canvas); container.append(toolbar, help, wrap);
  const paint = () => drawScene(canvas, currentMap, currentSelected, null, pending, startPoint);
  const buttons = new Map();
  for (const [id, title] of options) {
    const button = el("button", "", title); button.type = "button"; button.dataset.active = String(id === tool);
    button.onclick = () => {
      tool = id; pending.vertices = []; pending.face = undefined; help.textContent = messages[id];
      for (const [key, child] of buttons) child.dataset.active = String(key === id);
      paint();
    };
    buttons.set(id, button); toolbar.append(button);
  }
  help.textContent = messages.select;
  requestAnimationFrame(paint);
  const resize = new ResizeObserver(paint); resize.observe(canvas);
  const prefix = namespace.replace(/[^a-z0-9_-]/g, "") || "maker";
  const appendItem = (kind, item) => {
    const index = (currentMap[kind] || []).length;
    currentMap = { ...currentMap, [kind]: [...(currentMap[kind] || []), item] };
    currentSelected = { file, kind, index };
    onEdit([file], currentMap);
    onSelect(currentSelected);
    paint();
  };
  const updateNavigation = navigation => {
    currentMap = { ...currentMap, navigation };
    onEdit([file], currentMap);
    paint();
  };
  canvas.addEventListener("pointerdown", event => {
    const index = nearestNpc(canvas, currentMap, event);
    if (tool === "select") {
      if (index >= 0) {
        drag = index; canvas.setPointerCapture(event.pointerId);
        currentSelected = { file, kind: "npcs", index }; onSelect(currentSelected); paint();
      } else {
        const placement = nearestPlacement(canvas, currentMap, event);
        if (placement) {
          currentSelected = { file, ...placement }; onSelect(currentSelected); paint();
        }
      }
      return;
    }
    const cursor = screenPoint(canvas, event);
    if (tool === "vertex") {
      const navigation = currentMap.navigation || { vertices: [], faces: [], links: [] };
      const vertices = navigation.vertices || [];
      if (vertices.length >= 256) { help.textContent = "Cannot add a vertex: Content-0 allows at most 256."; return; }
      const worldX = Math.round((cursor.x - 24) * Math.max(1024, currentMap.width * 1024) / Math.max(1, cursor.width - 48));
      const worldZ = Math.round((cursor.y - 24) * Math.max(1024, currentMap.height * 1024) / Math.max(1, cursor.height - 48));
      if (vertices.some(vertex => vertex.x === worldX && vertex.z === worldZ && vertex.y === 0)) {
        help.textContent = "That navigation vertex already exists. Click a different map location."; return;
      }
      updateNavigation({ ...navigation, vertices: [...vertices, { x: worldX, y: 0, z: worldZ }] });
      help.textContent = messages.vertex;
      return;
    }
    if (tool === "face") {
      const navigation = currentMap.navigation || { vertices: [], faces: [], links: [] };
      const faces = navigation.faces || [];
      const vertex = nearestVertex(canvas, currentMap, event);
      if (vertex < 0 || pending.vertices.includes(vertex)) return;
      pending.vertices.push(vertex); paint();
      if (pending.vertices.length < 3) return;
      const selectedVertices = [...pending.vertices];
      const [a, b, c] = selectedVertices.map(index => navigation.vertices[index]);
      const area = (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x);
      if (!area) {
        help.textContent = "Those vertices form a flat triangle. Pick three with nonzero X/Z area.";
        pending.vertices = []; paint(); return;
      }
      if (hasSameFace(faces, selectedVertices)) {
        help.textContent = "That navigation face already exists. Pick a different triangle.";
        pending.vertices = []; paint(); return;
      }
      if (faces.length >= 256) {
        help.textContent = "Cannot add a face: Content-0 allows at most 256.";
        pending.vertices = []; paint(); return;
      }
      const nextFaces = [...faces, selectedVertices];
      const nextLinks = linksForFace(nextFaces, navigation.links || [], nextFaces.length - 1);
      if (nextLinks.length > 256) {
        help.textContent = "Cannot add this face: it would exceed 256 navigation links.";
        pending.vertices = []; paint(); return;
      }
      updateNavigation({ ...navigation, faces: nextFaces, links: nextLinks });
      help.textContent = messages.face; pending.vertices = []; paint();
      return;
    }
    const surface = surfaceAt(currentMap, cursor, cursor.width, cursor.height);
    if (tool === "start") {
      if (surface) onSetStart({ x: surface.x, y: surface.y, z: surface.z });
      return;
    }
    if (tool === "npc") {
      if (!surface) return;
      appendItem("npcs", { id: prefix + ":npc-" + ((currentMap.npcs || []).length + 1), name: "New NPC", x: surface.x, y: surface.y, z: surface.z });
      return;
    }
    if (tool === "trigger") {
      const vertex = nearestVertex(canvas, currentMap, event);
      if (vertex < 0 || pending.vertices.includes(vertex)) return;
      pending.vertices.push(vertex); paint();
      if (pending.vertices.length === 3) {
        appendItem("triggers", { id: prefix + ":trigger-" + ((currentMap.triggers || []).length + 1), event: prefix + ":event-1", vertices: [...pending.vertices] });
        pending.vertices = []; paint();
      }
      return;
    }
    if (tool === "region") {
      if (!surface) return;
      appendItem("encounterRegions", { id: prefix + ":region-" + ((currentMap.encounterRegions || []).length + 1), encounter: prefix + ":encounter-1", faces: [surface.face] });
      return;
    }
    if (tool === "transition") {
      if (pending.face === undefined) {
        if (!surface) return;
        pending.face = surface.face; pending.vertices = surface.vertices; paint();
      } else {
        if (!surface || surface.face !== pending.face) return;
        appendItem("transitions", { id: prefix + ":gate-" + ((currentMap.transitions || []).length + 1), targetMap: currentMap.id,
          vertices: [...pending.vertices], x: surface.x, y: surface.y, z: surface.z });
        pending.face = undefined; pending.vertices = []; paint();
      }
    }
  });
  canvas.addEventListener("pointermove", event => {
    if (drag < 0 || !canvas.hasPointerCapture(event.pointerId)) return;
    const cursor = screenPoint(canvas, event);
    const surface = surfaceAt(currentMap, cursor, cursor.width, cursor.height);
    const npc = currentMap.npcs[drag];
    if (!npc || !surface) return;
    draggedPoint = surface;
    drawScene(canvas, currentMap, currentSelected, surface, pending, startPoint);
  });
  canvas.addEventListener("pointerup", () => {
    if (drag >= 0 && draggedPoint) {
      const next = [...currentMap.npcs];
      next[drag] = { ...next[drag], x: draggedPoint.x, y: draggedPoint.y, z: draggedPoint.z };
      currentMap = { ...currentMap, npcs: next };
      onEdit([file, "npcs"], next);
    }
    drag = -1; draggedPoint = null;
  });
  canvas.addEventListener("pointercancel", () => { drag = -1; draggedPoint = null; paint(); });
  return () => resize.disconnect();
}
