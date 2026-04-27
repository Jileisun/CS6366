
Fractal Ecosystem Corridor — Implementation Task Spec

1. Project Goal

Build a real-time procedural alien ecosystem corridor in Three.js + custom GLSL ray marching shader, using the current Mandelbulb distance estimator as one of the core visual primitives.

The final scene should no longer be a single isolated Mandelbulb object.
Instead, it should become a layered environment with:
	•	a traversable central corridor
	•	repeated tall organic/fractal trunk structures on both sides
	•	overhead canopy / arch-like connective structures
	•	ground surface with clustered small growths
	•	fog / atmospheric depth
	•	emissive accents and strong visual composition toward a focal point

The scene should feel like an alien forest / biome / ecosystem, not just a fractal demo.

⸻

2. High-Level Artistic Direction

The target style is:
	•	alien organic
	•	bone-like / root-like structural forms
	•	dark base palette
	•	red/pink emissive vein-like accents
	•	misty atmospheric depth
	•	strong center perspective / tunnel-like corridor
	•	fractal / recursive / procedural visual language

The final result should resemble:
	•	alien forest
	•	organic corridor
	•	fractal biome
	•	surreal root/coral architecture

It should not look like:
	•	a single floating fractal sphere
	•	a random collection of repeated identical objects
	•	a normal low-poly forest
	•	a texture-only effect pasted onto simple geometry

⸻

3. Core Technical Constraints

Required
	•	Three.js app with custom fullscreen ray marching fragment shader
	•	Scene built primarily through procedural SDF / DE functions
	•	Use existing Mandelbulb DE as a key primitive or variant source
	•	Real-time rendering
	•	Camera can orbit or move through the corridor
	•	Preserve atmospheric depth and cinematic composition

Preferred
	•	Keep external assets minimal
	•	Avoid reliance on GLB/mesh scene assembly for the main scene
	•	Use procedural shading instead of image-based texturing whenever possible
	•	Reuse existing raymarch / AO / shadow / fog pipeline if already implemented

Not Allowed as Main Strategy
	•	Do not solve the scene by importing many prebuilt 3D models
	•	Do not simply place a single Mandelbulb in front of a textured plane
	•	Do not make the effect depend primarily on baked textures

⸻

4. Development Strategy

The implementation should follow a layered scene function design.

Instead of:

vec3 f(vec3 p) {
    return mb(p);
}

the new design should be conceptually like:

vec3 f(vec3 p) {
    // combine multiple scene layers
    // return vec3(distance, trap/materialAux, materialIdOrAux)
}

The new scene must be composed from multiple logical layers:
	1.	ground layer
	2.	trunk layer
	3.	canopy layer
	4.	ground cluster layer
	5.	optional focal structure layer
	6.	atmosphere and emissive styling

⸻

5. Scene Composition Requirements

5.1 Corridor Structure

The scene must have a clear central corridor.

Requirements:
	•	visually readable forward direction
	•	two sides of the scene populated with tall organic structures
	•	center area should remain more open than the sides
	•	distant focal point visible through the corridor
	•	should encourage camera-forward cinematic framing

Possible strategy:
	•	reserve a corridor around world center, e.g. around x = 0
	•	density of side structures increases as abs(x) grows beyond a threshold
	•	corridor should not be perfectly empty, but should remain visually traversable

⸻

5.2 Tall Side Structures

Both sides of the corridor should contain repeated large structures that read as:
	•	trunks
	•	pillars
	•	roots
	•	bone-like supports
	•	alien trees

These should not all be full expensive Mandelbulbs.
Use a mix of:
	•	stretched/warped Mandelbulb
	•	capsule/cylinder-like SDF base forms
	•	small fractal deformation near tops or surfaces
	•	repeated but varied instances

Each trunk should vary in:
	•	height
	•	thickness
	•	small tilt or bend
	•	local warp
	•	emissive intensity or color accents

They must not look like perfectly identical clones.

⸻

5.3 Overhead Canopy / Arch Layer

The upper region of the corridor should contain connective structure so that the environment feels enclosed and biological.

This can be implemented using:
	•	repeated arching capsules
	•	warped root-like tendrils
	•	branch-like connections between nearby trunks
	•	sparse overhead fractal membranes or lattice structures

Requirements:
	•	not too dense to destroy readability
	•	enough density to suggest ecosystem connectivity
	•	should frame the corridor and help depth perception
	•	should visually connect left and right side structures

⸻

5.4 Ground Layer

The scene must have a ground surface, not empty space.

Requirements:
	•	mildly uneven terrain
	•	not a perfectly flat plane unless temporarily used as debug fallback
	•	should support grounded ecosystem growths
	•	should visually connect foreground, midground, and background

Recommended approach:
	•	start from a simple plane SDF
	•	add low-frequency height variation via noise
	•	optionally add gentle ridges or depressions along the corridor sides
	•	center path may be slightly smoother than edges

⸻

5.5 Ground Cluster Layer

Add many smaller repeated ecosystem growths on or near the ground:
	•	spore pods
	•	coral-like lumps
	•	fungus-like clusters
	•	bulbous growths
	•	small fractal shrubs

These are crucial for making the scene feel like an ecosystem rather than just a corridor of pillars.

These can be much cheaper than the hero fractal:
	•	smooth union of spheres
	•	warped blobs
	•	tiny simplified fractal forms
	•	small capped columns with bulb heads

Requirements:
	•	concentrated more near trunk bases and scene edges
	•	some foreground detail must exist for scale and richness
	•	should not become visually noisy everywhere
	•	should break up empty ground

⸻

5.6 Focal Point

The far end of the corridor should contain a visual focal point.

Possibilities:
	•	glowing core
	•	bright organic portal-like structure
	•	large distant fractal mass
	•	emissive cavity / “nest” / “heart”

Requirements:
	•	visible from the camera
	•	subtle but clear
	•	acts as visual destination
	•	should enhance scene composition and scale

⸻

6. Geometry / Distance Field Design

6.1 Scene Query Function

The scene function should return enough information for shading.

Preferred return shape:

vec3 scene(vec3 p)

Suggested meaning:
	•	.x = signed/estimated distance
	•	.y = auxiliary shading data (trap / emissive factor / organic mask)
	•	.z = material identifier or other shading control

Alternative:
use a small struct if supported/desired in your shader style.

⸻

6.2 Recommended Layer Functions

Implement the scene using clearly separated helper functions.

Suggested function list:

vec3 mapScene(vec3 p);

vec3 layerGround(vec3 p);
vec3 layerTrunks(vec3 p);
vec3 layerCanopy(vec3 p);
vec3 layerClusters(vec3 p);
vec3 layerFocal(vec3 p);

vec3 mandelbulbDEInfo(vec3 p);
float sdCapsule(...);
float sdSphere(...);
float sdCappedCylinder(...);
float opSmoothUnion(...);
float hash11(float x);
vec2 hash21(float x);

The final mapScene should combine all relevant layers.

⸻

6.3 Combining Distances

Scene combination should be deliberate.

Use:
	•	min(a, b) for unions
	•	smooth union where visual blending is helpful
	•	limited use of subtraction/intersection unless necessary
	•	avoid overcomplicated CSG that hurts stability or readability

Important:
the final scene should remain marchable and stable.
Avoid producing fields that are too noisy or discontinuous.

⸻

7. Mandelbulb Usage Plan

The Mandelbulb should remain part of the scene language, but it should not be the only geometry everywhere.

Use Mandelbulb in one or more of these roles:

Option A: Hero Organism

Use full Mandelbulb for:
	•	major trunk heads
	•	distant central structure
	•	rare large ecosystem organisms

Option B: Deformed Trunk Primitive

Create a stretched or domain-warped version by transforming input coordinates before evaluating the DE.

Example concept:

vec3 q = p;
q.y *= 0.45; // compress input so shape appears vertically stretched
vec3 info = mandelbulbDEInfo(q);

Option C: Cluster Accent

Use small simplified Mandelbulb-based growths for select cluster points.

Important Constraint

Do not fill the whole world with many full-resolution Mandelbulbs.
This will be too expensive.

Use true Mandelbulb selectively, and cheaper procedural forms elsewhere.

⸻

8. Spatial Organization Rules

8.1 Repetition / Distribution

Use procedural repetition and seeded variation.

Good candidates:
	•	repeated side anchors along corridor depth
	•	mirrored or semi-mirrored left/right distribution
	•	pseudo-random perturbation per anchor
	•	denser objects away from central path

Example concept:
	•	anchors along z-axis at regular spacing
	•	left and right trunk positions around fixed side offsets
	•	random jitter added to x/z and scale
	•	some missing anchors to avoid perfect grid appearance

⸻

8.2 Variation

Each repeated structure should vary based on hashed seed.

Recommended variable parameters:
	•	height
	•	radius
	•	tilt
	•	local rotation
	•	emissive factor
	•	cluster density around the base
	•	top bulb scale

⸻

8.3 Foreground / Midground / Background

The scene should read at multiple scales.

Foreground
	•	detailed clusters
	•	trunk roots / bases
	•	strong local texture/shading contrast

Midground
	•	readable repeating large structures
	•	major corridor identity

Background
	•	simplified silhouettes
	•	fog-heavy
	•	focal glow
	•	lower detail acceptable

⸻

9. Shading Requirements

9.1 Base Material Language

Use at least two visually distinct material responses:

Hard Structural Material
	•	bone-like
	•	pale / desaturated
	•	root / wood / exoskeleton feeling

Soft / Organic / Emissive Material
	•	glowing red or pink veins
	•	porous cavities
	•	subsurface-like accent feeling
	•	localized bright spots

⸻

9.2 Surface Color Logic

Avoid uniform flat color.

Suggested drivers:
	•	orbit trap value from Mandelbulb
	•	curvature approximation
	•	world height
	•	object type / material id
	•	noise masks
	•	normal direction
	•	cavity / AO

Color palette suggestion:
	•	dark charcoal / purple-black base
	•	bone white / pale gray trunk highlights
	•	red / crimson / magenta emissive accents
	•	cold blue-white distant focal glow

⸻

9.3 Emissive Accents

Very important for the ecosystem mood.

Use emissive accents in:
	•	trunk nodes
	•	vein-like cracks
	•	cluster pores
	•	focal point
	•	scattered glowing spores/points

Do not overuse.
Emissive accents should guide the eye and create life, not flatten the whole scene.

⸻

9.4 Fog / Atmosphere

Keep or improve atmospheric fog.

Requirements:
	•	distance-based fog
	•	stronger haze in the far corridor
	•	supports visual depth
	•	blends distant geometry into environment naturally

Optional:
	•	slight colored fog tint
	•	subtle volumetric glow around focal light
	•	atmospheric absorption

⸻

9.5 Ambient Occlusion and Shadows

Keep AO and soft shadows if performance allows.

Requirements:
	•	AO to reinforce contact and cavity richness
	•	shadows for primary light direction
	•	should remain stable under camera movement
	•	avoid overly noisy shadowing

⸻

10. Camera Requirements

10.1 Camera Intent

The camera should support a strong corridor composition.

Two acceptable modes:

Mode A: Cinematic Orbit / Drift
	•	slow orbit around corridor centerline
	•	slight user mouse control
	•	still shows strong forward depth

Mode B: Forward Flythrough
	•	subtle movement into/through corridor
	•	ideal for final demo
	•	stronger immersion

⸻

10.2 Camera Framing

The camera should:
	•	see both sides of the corridor
	•	see enough canopy overhead
	•	preserve focal point visibility
	•	avoid looking too flat or too close to the ground

⸻

11. Performance Constraints

This is critical.

11.1 General Rule

The scene must remain real-time and stable.
Favor a convincing overall result over mathematically maximal complexity.

11.2 Recommended Optimizations
	•	use full Mandelbulb DE only for limited important shapes
	•	use cheaper proxy SDFs for repeated population
	•	limit march steps where possible
	•	use reduced iteration counts for far or secondary fractal forms if feasible
	•	avoid excessive layer count inside mapScene
	•	keep canopy simpler than hero trunks
	•	use fog to hide distant simplification

11.3 Marching Stability

Ensure:
	•	no severe overstepping artifacts
	•	no obvious popping
	•	normals remain stable enough for shading
	•	scene distances remain reasonably conservative

⸻

12. Suggested Implementation Plan

Phase 1 — Scene Skeleton

Implement:
	•	ground layer
	•	central corridor composition
	•	two rows of repeated tall structures
	•	simple fog
	•	keep current shading mostly intact

Goal:
scene already reads as a corridor

⸻

Phase 2 — Trunk Design

Refine tall structures:
	•	stretch/warp Mandelbulb or hybrid trunk primitive
	•	add base variation
	•	improve top silhouette
	•	add per-instance randomization

Goal:
trunks feel organic and non-repetitive

⸻

Phase 3 — Canopy + Clusters

Add:
	•	overhead connective structures
	•	small ground growth clusters
	•	foreground detail
	•	trunk-root transitions

Goal:
scene feels ecological, not just architectural

⸻

Phase 4 — Material Language

Add:
	•	bone-like trunk shading
	•	red emissive accents
	•	stronger contrast between hard/soft materials
	•	focal point glow

Goal:
scene gains final alien visual identity

⸻

Phase 5 — Polish

Tune:
	•	fog
	•	camera
	•	AO/shadows
	•	composition
	•	performance
	•	vignette / post look

Goal:
presentation-ready final scene

⸻

13. Deliverables

Required Deliverable 1

A working real-time scene in the existing Three.js app.

Required Deliverable 2

A fragment shader whose scene is no longer a single Mandelbulb object, but a layered ecosystem corridor.

Required Deliverable 3

Clean code organization with modular scene functions:
	•	ground
	•	trunks
	•	canopy
	•	clusters
	•	focal point
	•	final scene composition

Required Deliverable 4

Short comments in code explaining:
	•	each layer’s role
	•	how repeated objects are distributed
	•	where Mandelbulb is used
	•	where cheaper proxy forms are used

⸻

14. Expected Visual Milestones

Milestone 1

A walkable/open central corridor with repeated side forms

Milestone 2

The side forms feel like alien organic trunks, not simple cylinders

Milestone 3

The upper scene feels enclosed by canopy/arches

Milestone 4

The ground feels populated by smaller ecosystem growths

Milestone 5

The final scene reads immediately as an alien biome / ecosystem

⸻

15. Concrete Coding Requirements

15.1 Preserve Existing Useful Components

If already present, preserve and reuse where reasonable:
	•	raymarch intersection function
	•	normal estimation
	•	AO
	•	soft shadows
	•	background / fog / tonemapping
	•	Mandelbulb DE base logic

Do not rewrite everything from scratch unless necessary.

⸻

15.2 Refactor f() / scene query

Refactor the current single-object scene into layered scene composition.

Suggested pattern:

vec3 unionScene(vec3 a, vec3 b) {
    return (a.x < b.x) ? a : b;
}

Then:

vec3 mapScene(vec3 p) {
    vec3 res = vec3(1e9, 0.0, 0.0);

    res = unionScene(res, layerGround(p));
    res = unionScene(res, layerTrunks(p));
    res = unionScene(res, layerCanopy(p));
    res = unionScene(res, layerClusters(p));
    res = unionScene(res, layerFocal(p));

    return res;
}

This is only a suggestion.
Equivalent clear structure is acceptable.

⸻

15.3 Material Signaling

Use the .z channel or equivalent to distinguish material classes if helpful.

Example:
	•	0.0 ground
	•	1.0 trunk
	•	2.0 canopy
	•	3.0 cluster
	•	4.0 focal / emissive core

Then branch shading logic accordingly.

⸻

15.4 Randomization

Introduce deterministic per-instance variation using cheap hash functions.
Do not use temporal randomness for geometry layout.

⸻

16. What Not to Do

Do not:
	•	place one Mandelbulb and call it an ecosystem
	•	rely on large imported mesh assets
	•	rely primarily on image textures to fake complexity
	•	make every object a full expensive Mandelbulb
	•	destroy corridor readability with too much clutter
	•	make the scene perfectly symmetric and repetitive everywhere
	•	optimize too early before the corridor composition works
	•	overcomplicate GI/path tracing if the scene structure is still weak

⸻

17. Priority Order

If time is limited, prioritize in this order:
	1.	corridor composition
	2.	side trunk population
	3.	ground layer
	4.	canopy layer
	5.	ground clusters
	6.	emissive/fog/material polish
	7.	advanced lighting refinements

The scene composition matters more than adding expensive rendering tricks.

⸻

18. Success Criteria

This task is successful if the final result:
	•	clearly reads as a procedural fractal ecosystem corridor
	•	uses the Mandelbulb as a design language element, not just a standalone demo object
	•	has spatial hierarchy and atmosphere
	•	feels like a scene/world rather than an object render
	•	remains real-time and visually coherent

⸻

Optional Implementation Hints

Hint A — Trunk Primitive Strategy

A good compromise is:
	•	main trunk = capsule / warped column
	•	top/head = Mandelbulb-derived form
	•	base = cluster union
	•	small domain warp to unify silhouette

This usually works better than using full Mandelbulb for the entire trunk.

⸻

Hint B — Corridor Distribution Strategy

One simple strategy:
	•	march direction roughly along positive z
	•	generate side anchors along z
	•	left side around x = -sideWidth
	•	right side around x = +sideWidth
	•	keep abs(x) < corridorWidth relatively open

⸻

Hint C — Ground Cluster Strategy

Ground clusters can be cheap:
	•	union of 3–8 spheres
	•	slight noise warp
	•	occasional emissive pores
	•	concentrated near trunks and edges

⸻

Hint D — Canopy Strategy

Canopy can be sparse and implied:
	•	not every trunk needs connection
	•	connect only some neighbors
	•	use curved/arched capsule-like forms
	•	let fog hide the simplifications

