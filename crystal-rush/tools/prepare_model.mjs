// Shrinks a Meshy GLB (often a million triangles) to a game-ready mesh: simplified geometry,
// resized textures named "albedo" / "normal" (Godot extracts them as <model>_albedo.jpg ...).
//
//   cd /some/scratch/dir && npm install @gltf-transform/core @gltf-transform/extensions @gltf-transform/functions meshoptimizer sharp
//   node <repo>/crystal-rush/tools/prepare_model.mjs in.glb out.glb [triangles=17000] [baseSize=1024] [normalSize=512]
//
// Packages are resolved from the current directory, so they stay out of the Godot project.
//
// The metal/roughness map is dropped: the game shades everything as rough, non-metallic toys.

import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const req = createRequire(process.cwd() + '/');
const load = async (name) => import(pathToFileURL(req.resolve(name)).href);
const { NodeIO } = await load('@gltf-transform/core');
const { ALL_EXTENSIONS } = await load('@gltf-transform/extensions');
const { dedup, prune, simplify, textureCompress, weld } = await load('@gltf-transform/functions');
const { MeshoptSimplifier } = await load('meshoptimizer');
const sharp = (await load('sharp')).default;

const [, , input, output, target = '17000', base = '1024', normal = '512'] = process.argv;
if (!input || !output) {
	console.error('usage: node prepare_model.mjs in.glb out.glb [triangles] [baseSize] [normalSize]');
	process.exit(1);
}
const countTris = (doc) => doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives())
	.reduce((t, p) => t + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0);

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
await MeshoptSimplifier.ready;
for (const mat of doc.getRoot().listMaterials()) {
	mat.setMetallicRoughnessTexture(null);
	mat.setMetallicFactor(0.0);
	mat.setRoughnessFactor(0.85);
	mat.setDoubleSided(false);
}
await doc.transform(weld());
const ratio = Math.min(1.0, Number(target) / countTris(doc));
const b = Number(base);
const n = Number(normal);
await doc.transform(
	simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.003 }),
	prune(),
	dedup(),
	textureCompress({ encoder: sharp, targetFormat: 'jpeg', quality: 88, slots: /^baseColor/, resize: [b, b] }),
	textureCompress({ encoder: sharp, targetFormat: 'jpeg', quality: 90, slots: /^normal/, resize: [n, n] }),
);
for (const mat of doc.getRoot().listMaterials()) {
	mat.getBaseColorTexture()?.setName('albedo');
	mat.getNormalTexture()?.setName('normal');
}
await io.write(output, doc);
console.log(`wrote ${output}: ${countTris(doc)} triangles, textures ${doc.getRoot().listTextures().map((t) => t.getSize()?.join('x')).join(', ')}`);
