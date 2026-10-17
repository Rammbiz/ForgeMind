// Shrinks a Meshy image-to-3D GLB for the game (mobile texture budget, no metal/rough map).
//
//   cd /some/scratch/dir && npm install @gltf-transform/core @gltf-transform/extensions @gltf-transform/functions sharp
//   node <repo>/crystal-bastion/tools/prepare_arena.mjs in.glb out.glb [baseSize=2048] [normalSize=1024]
//
// Packages are resolved from the current directory, so they stay out of the Godot project.
//
// Base colour is kept sharp because the whole level is one model seen from above; the
// normal map only adds small relief, so it is halved. The metal/roughness map is dropped:
// the stylized arena is fully rough and non-metallic, and the map costs a whole texture.

import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const req = createRequire(process.cwd() + '/');
const load = async (name) => import(pathToFileURL(req.resolve(name)).href);
const { NodeIO } = await load('@gltf-transform/core');
const { ALL_EXTENSIONS } = await load('@gltf-transform/extensions');
const { dedup, prune, textureCompress } = await load('@gltf-transform/functions');
const sharp = (await load('sharp')).default;

const [, , input, output, base = '2048', normal = '1024'] = process.argv;
if (!input || !output) {
	console.error('usage: node prepare_arena.mjs in.glb out.glb [baseSize] [normalSize]');
	process.exit(1);
}
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
for (const mat of doc.getRoot().listMaterials()) {
	mat.setMetallicRoughnessTexture(null);
	mat.setMetallicFactor(0.0);
	mat.setRoughnessFactor(0.9);
	mat.setDoubleSided(false);
}
const b = Number(base);
const n = Number(normal);
await doc.transform(
	prune(),
	dedup(),
	textureCompress({ encoder: sharp, targetFormat: 'jpeg', quality: 90, slots: /^baseColor/, resize: [b, b] }),
	textureCompress({ encoder: sharp, targetFormat: 'jpeg', quality: 92, slots: /^normal/, resize: [n, n] }),
);
await io.write(output, doc);
const tris = doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives())
	.reduce((t, p) => t + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0);
console.log(`wrote ${output}: ${tris} triangles, textures ${doc.getRoot().listTextures().map((t) => t.getSize()?.join('x')).join(', ')}`);
