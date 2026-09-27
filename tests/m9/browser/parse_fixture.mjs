import { parseSceneCsv } from "../../../platform/presentation/browser/renderer.mjs";

if (process.argv.length !== 3) throw new Error("expected one M9 scene CSV argument");
const scene = parseSceneCsv(process.argv[2]);
if (scene.cameraAnchor == null) throw new Error("camera anchor missing");
process.stdout.write(`${scene.contentIdentity},${scene.mapId}\n`);
