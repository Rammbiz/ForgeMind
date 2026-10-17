// Stage 3 of the crowd-unit re-UV pipeline: puts the baked albedo (stage 2) on the simplified,
// re-unwrapped mesh (stage 1) as its base colour texture named "albedo" (rough, non-metallic).
//   node reuv_stage3.mjs LOW.glb ALBEDO.jpg OUT.glb
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';
const req = createRequire(process.cwd() + '/');
const load = async (name) => import(pathToFileURL(req.resolve(name)).href);
const { NodeIO } = await load('@gltf-transform/core');
const { ALL_EXTENSIONS } = await load('@gltf-transform/extensions');
const { prune } = await load('@gltf-transform/functions');
const [, , input, albedo, output] = process.argv;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const tex = doc.createTexture('albedo').setImage(readFileSync(albedo)).setMimeType('image/jpeg').setURI('albedo.jpg');
for (const m of doc.getRoot().listMaterials()) {
	m.setBaseColorTexture(tex);
	m.setBaseColorFactor([1, 1, 1, 1]);
	m.setMetallicFactor(0.0);
	m.setRoughnessFactor(0.85);
	m.setDoubleSided(false);
}
await doc.transform(prune());
await io.write(output, doc);
console.log('wrote', output);
