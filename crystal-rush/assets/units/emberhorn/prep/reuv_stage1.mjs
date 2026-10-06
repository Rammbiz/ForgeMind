// Stage 1 of the crowd-unit re-UV pipeline: position-welded geometric simplification of a skinned
// Meshy GLB (its hundreds of UV charts would otherwise lock the seams), smooth normals, a fresh
// xatlas (watlas) unwrap. Writes a GLB without textures; stage 2 bakes the albedo onto the new UVs.
//   node reuv_stage1.mjs IN OUT TARGET_TRIS [ERROR=0.03]
//
// Why: Meshy atlases have hundreds of UV charts, so seam-preserving simplification stalls (the
// Emberhorn stopped at 4 077 of 10 357 triangles) and seam-ignoring simplification smears the
// texture. Re-unwrapping the 1 800-triangle mesh and re-baking its albedo keeps the paint crisp.
// Full Emberhorn run (packages from a scratch dir with @gltf-transform/{core,extensions,functions},
// meshoptimizer, watlas; Python with numpy, scipy, trimesh, Pillow):
//   node reuv_stage1.mjs Meshy_AI_Emberhorn_Sentinel_Running.glb low.glb 1800 0.03
//   python3 reuv_stage2.py Meshy_AI_Emberhorn_Sentinel_Running.glb low.glb albedo.jpg 512 \
//       -0.17,0.965,0.07,0.17,1.205,0.4                    # -> albedo.jpg + albedo_glow.png (eyes)
//   node reuv_stage3.mjs low.glb albedo.jpg emberhorn_src.glb
//   cp albedo_glow.png ../emberhorn_src_glow.png; then tools/bake_vat.gd (see its header)
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
const req = createRequire(process.cwd() + '/');
const load = async (name) => import(pathToFileURL(req.resolve(name)).href);
const { NodeIO } = await load('@gltf-transform/core');
const { ALL_EXTENSIONS } = await load('@gltf-transform/extensions');
const { weld, prune, simplify, normals, unwrap } = await load('@gltf-transform/functions');
const { MeshoptSimplifier } = await load('meshoptimizer');
const watlas = await load('watlas');
const [, , input, output, target, err = '0.03'] = process.argv;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
await MeshoptSimplifier.ready;
const prims = () => doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives());
const count = () => prims().reduce((t, p) => t + p.getIndices().getCount() / 3, 0);
for (const p of prims()) {
	for (const s of ['TANGENT', 'NORMAL', 'TEXCOORD_0', 'TEXCOORD_1', 'COLOR_0']) if (p.getAttribute(s)) p.setAttribute(s, null);
}
for (const m of doc.getRoot().listMaterials()) {
	m.setBaseColorTexture(null); m.setNormalTexture(null); m.setMetallicRoughnessTexture(null);
	m.setEmissiveTexture(null); m.setOcclusionTexture(null);
}
await doc.transform(prune(), weld());
const before = count();
await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio: Number(target) / before, error: Number(err) }), prune());
console.log('tris', before, '->', count(), 'verts', prims().map((p) => p.getAttribute('POSITION').getCount()));
await doc.transform(unwrap({ watlas, overwrite: true, groupBy: 'mesh' }));
// Smooth normals per position (area weighted), so UV seams leave no shading seams; then weld.
for (const p of prims()) {
	const pos = p.getAttribute('POSITION').getArray();
	const idx = p.getIndices() ? p.getIndices().getArray() : Uint32Array.from({ length: pos.length / 3 }, (_, i) => i);
	const key = (i) => `${pos[i * 3].toFixed(6)},${pos[i * 3 + 1].toFixed(6)},${pos[i * 3 + 2].toFixed(6)}`;
	const acc = new Map();
	for (let t = 0; t < idx.length; t += 3) {
		const [a, b, c] = [idx[t], idx[t + 1], idx[t + 2]];
		const e1 = [0, 1, 2].map((k) => pos[b * 3 + k] - pos[a * 3 + k]);
		const e2 = [0, 1, 2].map((k) => pos[c * 3 + k] - pos[a * 3 + k]);
		const n = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
		for (const v of [a, b, c]) {
			const k = key(v);
			const s = acc.get(k) || [0, 0, 0];
			acc.set(k, [s[0] + n[0], s[1] + n[1], s[2] + n[2]]);
		}
	}
	const nrm = new Float32Array(pos.length);
	for (let i = 0; i < pos.length / 3; i++) {
		const s = acc.get(key(i)) || [0, 1, 0];
		const l = Math.hypot(s[0], s[1], s[2]) || 1;
		nrm[i * 3] = s[0] / l; nrm[i * 3 + 1] = s[1] / l; nrm[i * 3 + 2] = s[2] / l;
	}
	const na = p.getAttribute('NORMAL') || doc.createAccessor().setType('VEC3').setBuffer(doc.getRoot().listBuffers()[0]);
	na.setArray(nrm);
	p.setAttribute('NORMAL', na);
}
await doc.transform(weld());
console.log('after unwrap verts', prims().map((p) => p.getAttribute('POSITION').getCount()), 'attrs', prims()[0].listSemantics());
await io.write(output, doc);
