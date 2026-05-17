import { useEffect } from 'react'
import type { RefObject } from 'react'
import * as THREE from 'three'
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js'
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js'
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js'
import { MeshSurfaceSampler } from 'three/examples/jsm/math/MeshSurfaceSampler.js'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

type SceneManagerProps = {
  canvasRef: RefObject<HTMLCanvasElement | null>
  mainRef: RefObject<HTMLElement | null>
  onReady?: () => void
}

const PARTICLE_COUNT = 14000
const LOGO_ORBIT_FRACTION = 0.15
const LOGO_GLB_CANDIDATES = ['/vyomalogo.glb', '/VyomaLogo.glb', '/vyoma-logo.glb']
const LOGO_TARGET_SIZE = 18
const HERO_LOGO_Y = 6.2
const ORBIT_SPEED_MIN = 0.008
const ORBIT_SPEED_MAX = 0.022
const FIELD_SPEED_MIN = 0.004
const FIELD_SPEED_MAX = 0.012

// Cinematic refinement constants
const FORMATION_DURATION = 3.6
const FORMATION_MAX_DELAY = 0.35
const FOG_DENSITY = 0.007
const MAX_CONSTELLATION_LINES = 30
const CONSTELLATION_DISTANCE = 2.2
const CONSTELLATION_CURSOR_RADIUS = 6.0
const BREATH_BLOOM_AMP = 0.08
const BREATH_GLOW_AMP = 0.025
const BREATH_WIRE_AMP = 0.035
const BREATH_EMISSIVE_AMP = 0.035
const MICRO_DRIFT_AMP = 0.01
const CAMERA_DRIFT_AMP = 0.15

// Parallax depth tiers
const PARALLAX_FOREGROUND = 1.0  // z > 5
const PARALLAX_MID = 0.4         // z: -5 to 5
const PARALLAX_DEEP = 0.08       // z < -5

// Calibration ring constants
const RING_INNER_RADIUS = 4.0
const RING_MID_RADIUS = 7.5
const RING_OUTER_RADIUS = 11.0
const RING_MAX_OPACITY = 0.06
const RING_ROTATE_INNER = 0.015
const RING_ROTATE_MID = -0.008
const RING_ROTATE_OUTER = 0.005

// Alignment field constants
const ALIGNMENT_COLUMN_SPACING = 15.0
const ALIGNMENT_FORCE = 0.003

const meshVertexShader = `
  varying vec3 vNormal;
  varying vec3 vViewPosition;
  void main() {
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    vNormal = normalize(normalMatrix * normal);
    vViewPosition = -mvPosition.xyz;
    gl_Position = projectionMatrix * mvPosition;
  }
`

const meshFragmentShader = `
  uniform vec3 color1;
  uniform vec3 color2;
  uniform float opacity;
  varying vec3 vNormal;
  varying vec3 vViewPosition;
  void main() {
    vec3 normal = normalize(vNormal);
    vec3 viewDir = normalize(vViewPosition);
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.1);
    vec3 finalColor = mix(color1, color2, fresnel);
    gl_FragColor = vec4(finalColor, opacity * (0.35 + fresnel * 0.65));
  }
`

const particleVertexShader = `
  attribute float aSize;
  attribute float aPhase;
  varying float vPhase;
  varying vec3 vWorldPos;
  varying float vDepthFade;
  void main() {
    vPhase = aPhase;
    vec4 worldPos = modelMatrix * vec4(position, 1.0);
    vWorldPos = worldPos.xyz;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * mvPosition;
    float dist = max(-mvPosition.z, 1.0);
    float depthFactor = 1.0 - smoothstep(5.0, 50.0, dist);
    vDepthFade = 0.45 + depthFactor * 0.55;
    gl_PointSize = aSize * (300.0 / dist) * (0.6 + depthFactor * 0.4);
  }
`

const particleFragmentShader = `
  varying float vPhase;
  varying float vDepthFade;
  uniform vec3 uGoldLight;
  uniform vec3 uGoldMid;
  uniform vec3 uGoldDark;

  float goldFlake(vec2 p) {
    float a = atan(p.y, p.x);
    float r = length(p);
    float edge = 0.34
      + 0.11 * sin(a * 3.0 + vPhase * 6.283)
      + 0.07 * sin(a * 5.0 + vPhase * 4.0)
      + 0.05 * sin(a * 8.0 + vPhase * 9.0)
      + 0.03 * sin(a * 13.0);
    edge += 0.02 * sin(r * 40.0 + vPhase * 12.0);
    return 1.0 - smoothstep(edge - 0.04, edge + 0.02, r);
  }

  void main() {
    vec2 uv = gl_PointCoord - 0.5;
    float mask = goldFlake(uv);
    if (mask < 0.08) discard;

    float r = length(uv) * 2.2;
    vec3 col = mix(uGoldDark, uGoldMid, 1.0 - r);
    col = mix(col, uGoldLight, pow(1.0 - r, 2.5) * 0.85);

    float spec = pow(max(0.0, 1.0 - r * 1.4), 3.0);
    col += uGoldLight * spec * 0.35;

    float alpha = mask * (0.78 + spec * 0.22) * vDepthFade;
    gl_FragColor = vec4(col, alpha);
  }
`

type PreparedLogo = {
  group: THREE.Group
  sampleMesh: THREE.Mesh
  displayMesh: THREE.Mesh
  radius: number
}

async function loadLogoGlb(path: string): Promise<PreparedLogo> {
  const gltf = await new GLTFLoader().loadAsync(path)
  const root = gltf.scene
  root.updateMatrixWorld(true)

  const geometries: THREE.BufferGeometry[] = []
  root.traverse((child) => {
    if (child instanceof THREE.Mesh) {
      const geom = child.geometry.clone()
      geom.applyMatrix4(child.matrixWorld)
      geometries.push(geom)
    }
  })

  if (geometries.length === 0) {
    throw new Error('vyomalogo.glb contains no meshes')
  }

  const merged =
    geometries.length === 1 ? geometries[0] : mergeGeometries(geometries, false)
  if (!merged) {
    throw new Error('Failed to merge logo meshes')
  }

  merged.computeBoundingBox()
  const box = merged.boundingBox!
  const center = box.getCenter(new THREE.Vector3())
  merged.translate(-center.x, -center.y, -center.z)

  const size = box.getSize(new THREE.Vector3())
  const maxDim = Math.max(size.x, size.y, size.z)
  const scale = LOGO_TARGET_SIZE / maxDim
  merged.scale(scale, scale, scale)
  merged.computeBoundingBox()
  const dims = merged.boundingBox!.getSize(new THREE.Vector3())
  // GLB ships with VYOMA vertical (+Y); rotate so V is left, A is right, facing the camera
  if (dims.y > dims.x * 1.05) {
    merged.rotateZ(Math.PI / 2)
  }
  if (dims.z > dims.y * 1.05) {
    merged.rotateX(-Math.PI / 2)
  }
  merged.rotateY(Math.PI)
  merged.computeBoundingBox()
  merged.computeBoundingSphere()

  const displayMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xb8860b,
    metalness: 0.92,
    roughness: 0.22,
    emissive: new THREE.Color(0x3d2f0a),
    emissiveIntensity: 0.15,
    clearcoat: 0.6,
    clearcoatRoughness: 0.2,
    transparent: true,
    opacity: 0.92
  })

  const displayMesh = new THREE.Mesh(merged, displayMaterial)
  const radius = merged.boundingSphere?.radius ?? LOGO_TARGET_SIZE * 0.5

  const group = new THREE.Group()
  group.add(displayMesh)

  return { group, sampleMesh: displayMesh, displayMesh, radius }
}

type OrbitShellData = {
  positions: Float32Array
  angle: Float32Array
  radiusXZ: Float32Array
  baseY: Float32Array
  speed: Float32Array
}



type ParticlePhaseMix = {
  scatter: number
  inner: number
  expansion: number
  cursorPull: number
  alignment: number
  scrollY: number
}

type ViewportExtents = { halfW: number; halfH: number; depth: number }

function createParticleShellData(): OrbitShellData {
  return {
    positions: new Float32Array(PARTICLE_COUNT * 3),
    angle: new Float32Array(PARTICLE_COUNT),
    radiusXZ: new Float32Array(PARTICLE_COUNT),
    baseY: new Float32Array(PARTICLE_COUNT),
    speed: new Float32Array(PARTICLE_COUNT)
  }
}

function createFormationDelays(scatter: Float32Array, centerY: number): Float32Array {
  const delays = new Float32Array(PARTICLE_COUNT)
  let maxDist = 0
  for (let i = 0; i < PARTICLE_COUNT; i++) {
    const idx = i * 3
    const dx = scatter[idx]!
    const dy = scatter[idx + 1]! - centerY
    const dz = scatter[idx + 2]!
    const dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
    if (dist > maxDist) maxDist = dist
  }
  const invMax = maxDist > 0 ? 1 / maxDist : 1
  for (let i = 0; i < PARTICLE_COUNT; i++) {
    const idx = i * 3
    const dx = scatter[idx]!
    const dy = scatter[idx + 1]! - centerY
    const dz = scatter[idx + 2]!
    const normalizedDist = Math.sqrt(dx * dx + dy * dy + dz * dz) * invMax
    delays[i] = normalizedDist * FORMATION_MAX_DELAY + Math.random() * 0.05
  }
  return delays
}

function getViewportExtents(camera: THREE.PerspectiveCamera, distance: number): ViewportExtents {
  const vFov = (camera.fov * Math.PI) / 180
  const height = 2 * Math.tan(vFov / 2) * distance
  const width = height * camera.aspect
  return { halfW: width * 0.55, halfH: height * 0.55, depth: 22 }
}

/** Logo-adjacent shell — orbits close to the emblem. */
function sampleLogoOrbitShell(
  mesh: THREE.Mesh,
  shell: OrbitShellData,
  startIndex: number,
  count: number,
  centerY: number,
  radiusScale: number,
  shellThickness: number,
  speedMin: number,
  speedMax: number
) {
  const sampler = new MeshSurfaceSampler(mesh).build()
  const point = new THREE.Vector3()
  const normal = new THREE.Vector3()

  for (let i = 0; i < count; i += 1) {
    const p = startIndex + i
    sampler.sample(point, normal)
    if (normal.lengthSq() < 1e-8) {
      normal.set(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).normalize()
    }
    const shellDist = radiusScale * (0.92 + Math.random() * 0.22)
    const jitter = (Math.random() - 0.5) * shellThickness
    const offset = shellDist + jitter
    const x = point.x + normal.x * offset
    const y = point.y + normal.y * offset + centerY
    const z = point.z + normal.z * offset
    const idx = p * 3
    shell.positions[idx] = x
    shell.positions[idx + 1] = y
    shell.positions[idx + 2] = z
    shell.angle[p] = Math.atan2(z, x)
    shell.radiusXZ[p] = Math.hypot(x, z) || 0.01
    shell.baseY[p] = y
    shell.speed[p] = speedMin + Math.random() * (speedMax - speedMin)
  }
}

/** Ambient field — random distribution across the camera frustum. */
function sampleViewportField(
  shell: OrbitShellData,
  scatter: Float32Array,
  startIndex: number,
  count: number,
  extents: ViewportExtents,
  centerY: number,
  speedMin: number,
  speedMax: number
) {
  for (let i = 0; i < count; i += 1) {
    const p = startIndex + i
    const idx = p * 3
    const edgeBias = 0.5 + Math.random() * 0.5
    const x = (Math.random() * 2 - 1) * extents.halfW * edgeBias
    const y = centerY + (Math.random() * 2 - 1) * extents.halfH * edgeBias
    const z = (Math.random() * 2 - 1) * extents.depth * edgeBias
    shell.positions[idx] = x
    shell.positions[idx + 1] = y
    shell.positions[idx + 2] = z
    shell.angle[p] = Math.atan2(z, x)
    shell.radiusXZ[p] = Math.hypot(x, z) || 0.01
    shell.baseY[p] = y
    shell.speed[p] = speedMin + Math.random() * (speedMax - speedMin)

    scatter[idx] = (Math.random() * 2 - 1) * extents.halfW * 1.1
    scatter[idx + 1] = (Math.random() * 2 - 1) * extents.halfH * 1.1
    scatter[idx + 2] = (Math.random() * 2 - 1) * extents.depth * 1.2
  }
}

function buildParticleShells(
  mesh: THREE.Mesh,
  logoRadius: number,
  camera: THREE.PerspectiveCamera,
  centerY: number
): { outer: OrbitShellData; inner: OrbitShellData; scatter: Float32Array; logoOrbitCount: number } {
  const logoOrbitCount = Math.floor(PARTICLE_COUNT * LOGO_ORBIT_FRACTION)
  const extents = getViewportExtents(camera, 32)
  const outer = createParticleShellData()
  const inner = createParticleShellData()
  const scatter = new Float32Array(PARTICLE_COUNT * 3)

  sampleLogoOrbitShell(
    mesh,
    outer,
    0,
    logoOrbitCount,
    centerY,
    logoRadius * 1.45,
    logoRadius * 0.55,
    ORBIT_SPEED_MIN,
    ORBIT_SPEED_MAX
  )
  sampleLogoOrbitShell(
    mesh,
    inner,
    0,
    logoOrbitCount,
    centerY,
    logoRadius * 1.1,
    logoRadius * 0.16,
    ORBIT_SPEED_MIN,
    ORBIT_SPEED_MAX
  )

  for (let i = 0; i < logoOrbitCount; i += 1) {
    const idx = i * 3
    const randomPos = new THREE.Vector3().randomDirection().multiplyScalar(22 + Math.random() * 32)
    scatter[idx] = randomPos.x
    scatter[idx + 1] = randomPos.y + centerY
    scatter[idx + 2] = randomPos.z
  }

  sampleViewportField(
    outer,
    scatter,
    logoOrbitCount,
    PARTICLE_COUNT - logoOrbitCount,
    extents,
    centerY * 0.15,
    FIELD_SPEED_MIN,
    FIELD_SPEED_MAX
  )
  sampleViewportField(
    inner,
    scatter,
    logoOrbitCount,
    PARTICLE_COUNT - logoOrbitCount,
    extents,
    centerY * 0.15,
    FIELD_SPEED_MIN,
    FIELD_SPEED_MAX
  )

  for (let p = logoOrbitCount; p < PARTICLE_COUNT; p += 1) {
    inner.radiusXZ[p] = outer.radiusXZ[p]! * (0.88 + Math.random() * 0.08)
    inner.baseY[p] = outer.baseY[p]!
  }

  return { outer, inner, scatter, logoOrbitCount }
}

function computeAmbientPosition(
  i: number,
  outerShell: OrbitShellData,
  innerShell: OrbitShellData,
  phases: Float32Array,
  scatter: Float32Array,
  scatterMix: number,
  innerMix: number,
  elapsed: number,
  logoOrbitCount: number,
  target: THREE.Vector3,
  formationDelays: Float32Array | null
) {
  const { positions: outer, angle, speed } = outerShell
  const { radiusXZ: innerRadius, baseY: innerBaseY } = innerShell
  const idx = i * 3

  if (scatterMix > 0.001) {
    let effectiveScatter = scatterMix
    if (formationDelays) {
      const delay = formationDelays[i]!
      effectiveScatter = Math.max(0, (scatterMix - (1 - delay)) / delay)
      effectiveScatter = Math.min(1, effectiveScatter)
      // Spring overshoot: particles briefly pass target before settling
      if (effectiveScatter > 0 && effectiveScatter < 0.3) {
        const springT = effectiveScatter / 0.3
        effectiveScatter *= (1 - 0.06 * Math.sin(springT * Math.PI * 1.5))
      }
    }
    if (effectiveScatter > 0.001) {
      target.set(
        THREE.MathUtils.lerp(outer[idx]!, scatter[idx]!, effectiveScatter),
        THREE.MathUtils.lerp(outer[idx + 1]!, scatter[idx + 1]!, effectiveScatter),
        THREE.MathUtils.lerp(outer[idx + 2]!, scatter[idx + 2]!, effectiveScatter)
      )
      return
    }
  }

  const isLogoOrbit = i < logoOrbitCount
  const tighten = isLogoOrbit ? innerMix : innerMix * 0.25
  const theta = angle[i]! + elapsed * speed[i]!
  const r = THREE.MathUtils.lerp(outerShell.radiusXZ[i]!, innerRadius[i]!, tighten)
  const y =
    THREE.MathUtils.lerp(outerShell.baseY[i]!, innerBaseY[i]!, tighten) +
    Math.sin(elapsed * 0.22 + phases[i]! * 6.283) * 0.12 +
    Math.sin(elapsed * 0.15 + phases[i]! * 3.7) * MICRO_DRIFT_AMP

  target.set(Math.cos(theta) * r, y, Math.sin(theta) * r)
}

function updateParticles(
  positionsAttr: THREE.BufferAttribute,
  scatter: Float32Array,
  outerShell: OrbitShellData,
  innerShell: OrbitShellData,
  phases: Float32Array,
  phaseMix: ParticlePhaseMix,
  elapsed: number,
  logoOrbitCount: number,
  logoY: number,
  logoRadius: number,
  cursorWorld: THREE.Vector3,
  velocities: Float32Array,
  formationDelays: Float32Array,
  titlePositions: THREE.Vector3[]
) {
  const ambient = new THREE.Vector3()
  const expansion = phaseMix.expansion
  const alignment = phaseMix.alignment
  const scrollY = phaseMix.scrollY
  const dt = 0.016

  for (let i = 0; i < PARTICLE_COUNT; i += 1) {
    computeAmbientPosition(
      i, outerShell, innerShell, phases, scatter,
      phaseMix.scatter, phaseMix.inner, elapsed, logoOrbitCount,
      ambient, formationDelays
    )

    let x = ambient.x
    let y = ambient.y
    let z = ambient.z

    // ── Parallax depth layers ──────────────────────────────────────────
    // Foreground particles shift more with scroll, deep ones barely move
    const baseZ = outerShell.positions[i * 3 + 2]!
    let parallaxFactor: number
    if (baseZ > 5) parallaxFactor = PARALLAX_FOREGROUND
    else if (baseZ > -5) parallaxFactor = PARALLAX_MID
    else parallaxFactor = PARALLAX_DEEP
    y += scrollY * parallaxFactor * 6.0

    // Expansion: particles gently exhale outward from logo center
    if (expansion > 0.001) {
      const dx = x
      const dy = y - logoY
      const dz = z
      const dist = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1
      const isLogoOrbit = i < logoOrbitCount
      const pushScale = isLogoOrbit
        ? logoRadius * (0.8 + phases[i]! * 1.2) * expansion
        : logoRadius * (0.15 + phases[i]! * 0.4) * expansion
      x += (dx / dist) * pushScale
      y += (dy / dist) * pushScale
      z += (dz / dist) * pushScale
      const driftAngle = elapsed * 0.06 + phases[i]! * 6.283
      x += Math.sin(driftAngle) * expansion * 0.4
      y += Math.cos(driftAngle * 0.7) * expansion * 0.2
    }

    // ── Alignment fields ───────────────────────────────────────────────
    // Subtle vertical column ordering — hidden structure emerges during scroll
    if (alignment > 0.001) {
      const nearestColumn = Math.round(x / ALIGNMENT_COLUMN_SPACING) * ALIGNMENT_COLUMN_SPACING
      const columnDx = nearestColumn - x
      velocities[i * 3]! += columnDx * ALIGNMENT_FORCE * alignment * dt * 60
    }

    // ── Particle compression toward titles ─────────────────────────────
    // Gravitational lensing: particles gently compress inward toward visible titles
    if (titlePositions.length > 0) {
      for (let t = 0; t < titlePositions.length; t++) {
        const tp = titlePositions[t]!
        const tdx = tp.x - x
        const tdy = tp.y - y
        const tdist = Math.sqrt(tdx * tdx + tdy * tdy + 0.1)
        if (tdist < 12.0) {
          const tFalloff = 1.0 - tdist / 12.0
          const compressStrength = 0.15 * tFalloff * tFalloff
          velocities[i * 3]! += tdx / tdist * compressStrength * dt
          velocities[i * 3 + 1]! += tdy / tdist * compressStrength * dt
        }
      }
    }

    // ── Cursor attraction ──────────────────────────────────────────────
    const vi = i * 3
    const cdx = cursorWorld.x - x
    const cdy = cursorWorld.y - y
    const dist2D = Math.sqrt(cdx * cdx + cdy * cdy + 0.01)

    if (dist2D < 10.0) {
      const t = 1.0 - dist2D / 10.0
      const pullStrength = 5.0 * t * t * t
      velocities[vi]! += cdx / dist2D * pullStrength * dt
      velocities[vi + 1]! += cdy / dist2D * pullStrength * dt
    }

    // Damping: spring-return to ambient
    velocities[vi]! *= 0.82
    velocities[vi + 1]! *= 0.82
    velocities[vi + 2]! *= 0.82

    x += velocities[vi]!
    y += velocities[vi + 1]!
    z += velocities[vi + 2]!

    positionsAttr.setXYZ(i, x, y, z)
  }
  positionsAttr.needsUpdate = true
}

async function loadLogoGlbFromCandidates(): Promise<PreparedLogo | null> {
  for (const path of LOGO_GLB_CANDIDATES) {
    try {
      return await loadLogoGlb(path)
    } catch {
      // try next path
    }
  }
  return null
}

function createGoldParticleMaterial(): THREE.ShaderMaterial {
  return new THREE.ShaderMaterial({
    uniforms: {
      uGoldLight: { value: new THREE.Color(0xfff4d6) },
      uGoldMid: { value: new THREE.Color(0xd4af37) },
      uGoldDark: { value: new THREE.Color(0x5c4510) }
    },
    vertexShader: particleVertexShader,
    fragmentShader: particleFragmentShader,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending
  })
}

const SceneManager = ({ canvasRef, mainRef, onReady }: SceneManagerProps) => {
  useEffect(() => {
    const canvas = canvasRef.current
    const main = mainRef.current
    if (!canvas || !main) {
      return undefined
    }

    let cancelled = false
    const disposers: Array<() => void> = []

    const run = async (): Promise<void> => {
      let logo: PreparedLogo | null = await loadLogoGlbFromCandidates()
      const usingGlb = Boolean(logo)

      if (!logo) {
        console.warn('[Vyoma] vyomalogo.glb not found — place it in paperverse-ui/public/vyomalogo.glb')
      }
      if (cancelled) return

      const scene = new THREE.Scene()
      const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000)
      const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true })
      renderer.setPixelRatio(window.devicePixelRatio)
      renderer.setSize(window.innerWidth, window.innerHeight)
      camera.position.set(0, 0, 32)

      scene.add(new THREE.AmbientLight(0xfff8e8, 0.4))

      const keyLight = new THREE.DirectionalLight(0xfff5e6, 1.8)
      keyLight.position.set(18, 24, 18)
      scene.add(keyLight)

      const rimLight = new THREE.PointLight(0xc9a227, 2.0, 120)
      rimLight.position.set(-14, -10, 22)

      const fillLight = new THREE.PointLight(0xe8c066, 0.8, 80)
      fillLight.position.set(12, 8, 20)
      scene.add(fillLight)
      scene.add(rimLight)

      scene.fog = new THREE.FogExp2(0x000000, FOG_DENSITY)

      const composer = new EffectComposer(renderer)
      composer.addPass(new RenderPass(scene, camera))
      const bloomPass = new UnrealBloomPass(
        new THREE.Vector2(window.innerWidth, window.innerHeight),
        1.4,
        0.4,
        0.7
      )
      bloomPass.threshold = 0.05
      bloomPass.strength = 1.3
      bloomPass.radius = 0.4
      composer.addPass(bloomPass)

      const rootGroup = new THREE.Group()
      scene.add(rootGroup)

      const logoGroup = new THREE.Group()
      rootGroup.add(logoGroup)

      const fallbackGeom = new THREE.DodecahedronGeometry(10, 1)
      let sampleMesh: THREE.Mesh
      let displayMesh: THREE.Mesh
      let logoRadius = 6.5
      let glowMaterial: THREE.ShaderMaterial
      let wireframe: THREE.LineSegments
      let wireframeMaterial: THREE.LineBasicMaterial

      if (logo) {
        logoGroup.add(logo.group)
        sampleMesh = logo.sampleMesh
        displayMesh = logo.displayMesh
        logoRadius = logo.radius

        glowMaterial = new THREE.ShaderMaterial({
          vertexShader: meshVertexShader,
          fragmentShader: meshFragmentShader,
          uniforms: {
            color1: { value: new THREE.Color(0x6b4f1a) },
            color2: { value: new THREE.Color(0xf0d080) },
            opacity: { value: 0 }
          },
          transparent: true,
          blending: THREE.AdditiveBlending,
          depthWrite: false
        })
        const glowShell = new THREE.Mesh(displayMesh.geometry, glowMaterial)
        logoGroup.add(glowShell)

        wireframeMaterial = new THREE.LineBasicMaterial({
          color: 0xd4af37,
          transparent: true,
          opacity: 0,
          blending: THREE.AdditiveBlending,
          depthWrite: false
        })
        wireframe = new THREE.LineSegments(new THREE.EdgesGeometry(displayMesh.geometry, 14), wireframeMaterial)
        logoGroup.add(wireframe)
      } else {
        sampleMesh = new THREE.Mesh(fallbackGeom)
        glowMaterial = new THREE.ShaderMaterial({
          vertexShader: meshVertexShader,
          fragmentShader: meshFragmentShader,
          uniforms: {
            color1: { value: new THREE.Color(0x6b4f1a) },
            color2: { value: new THREE.Color(0xf0d080) },
            opacity: { value: 0 }
          },
          transparent: true,
          blending: THREE.AdditiveBlending,
          depthWrite: false
        })
        displayMesh = new THREE.Mesh(fallbackGeom, new THREE.MeshPhysicalMaterial({ transparent: true, opacity: 0 }))
        logoGroup.add(displayMesh)
        wireframeMaterial = new THREE.LineBasicMaterial({
          color: 0xd4af37,
          transparent: true,
          opacity: 0,
          blending: THREE.AdditiveBlending,
          depthWrite: false
        })
        wireframe = new THREE.LineSegments(new THREE.WireframeGeometry(fallbackGeom), wireframeMaterial)
        logoGroup.add(wireframe)
        logoRadius = 10
      }

      logoGroup.position.y = HERO_LOGO_Y

      const { outer: outerShell, inner: innerShell, scatter: scatterPositions, logoOrbitCount } =
        buildParticleShells(sampleMesh, logoRadius, camera, HERO_LOGO_Y)

      const positions = new Float32Array(scatterPositions)

      const sizes = new Float32Array(PARTICLE_COUNT)
      const phases = new Float32Array(PARTICLE_COUNT)
      for (let i = 0; i < PARTICLE_COUNT; i += 1) {
        sizes[i] = 0.12 + Math.random() * 0.22
        phases[i] = Math.random()
      }

      const particlesMaterial = createGoldParticleMaterial()
      particlesMaterial.opacity = 0.88
      const particlesGeom = new THREE.BufferGeometry()
      particlesGeom.setAttribute('position', new THREE.BufferAttribute(positions, 3))
      particlesGeom.setAttribute('aSize', new THREE.BufferAttribute(sizes, 1))
      particlesGeom.setAttribute('aPhase', new THREE.BufferAttribute(phases, 1))

      const particles = new THREE.Points(particlesGeom, particlesMaterial)
      particles.renderOrder = 0
      particles.frustumCulled = false
      displayMesh.renderOrder = 10
      if (logo) {
        logo.group.children.forEach((child) => {
          child.renderOrder = 10
        })
      }
      rootGroup.add(particles)

      // Velocity buffer for gravitational cursor physics
      const particleVelocities = new Float32Array(PARTICLE_COUNT * 3)

      // Per-particle formation delays for staggered assembly
      const formationDelays = createFormationDelays(scatterPositions, HERO_LOGO_Y)

      // Constellation line geometry (pre-allocated)
      const constellationMaxVerts = MAX_CONSTELLATION_LINES * 2
      const constellationPositions = new Float32Array(constellationMaxVerts * 3)
      const constellationGeom = new THREE.BufferGeometry()
      constellationGeom.setAttribute('position', new THREE.BufferAttribute(constellationPositions, 3))
      constellationGeom.setDrawRange(0, 0)
      const constellationMaterial = new THREE.LineBasicMaterial({
        color: 0xd4af37,
        transparent: true,
        opacity: 0,
        blending: THREE.AdditiveBlending,
        depthWrite: false
      })
      const constellationLines = new THREE.LineSegments(constellationGeom, constellationMaterial)
      constellationLines.frustumCulled = false
      scene.add(constellationLines)
      let constellationTargetOpacity = 0

      // ── Procedural calibration rings ────────────────────────────────
      const ringMaterial = new THREE.MeshBasicMaterial({
        color: 0xd4af37,
        transparent: true,
        opacity: 0,
        side: THREE.DoubleSide,
        blending: THREE.AdditiveBlending,
        depthWrite: false
      })
      const createRing = (innerR: number, outerR: number) => {
        const geom = new THREE.RingGeometry(innerR, outerR, 128)
        const mat = ringMaterial.clone()
        const mesh = new THREE.Mesh(geom, mat)
        mesh.rotation.x = -Math.PI / 2
        mesh.position.y = HERO_LOGO_Y
        logoGroup.add(mesh)
        return { mesh, mat, geom }
      }
      const ringInner = createRing(RING_INNER_RADIUS, RING_INNER_RADIUS + 0.02)
      const ringMid = createRing(RING_MID_RADIUS, RING_MID_RADIUS + 0.015)
      const ringOuter = createRing(RING_OUTER_RADIUS, RING_OUTER_RADIUS + 0.01)
      let ringTargetOpacity = 0

      // ── Spatial Axis Architecture ───────────────────────────────────
      // Sparse structural beams — architectural, not decorative
      const AXIS_COUNT = 12
      const axisVerts: number[] = []
      const axisColors: number[] = []
      for (let i = 0; i < AXIS_COUNT; i++) {
        // Intentional spacing: grid-like with subtle jitter
        const col = (i % 4) - 1.5 // -1.5, -0.5, 0.5, 1.5
        const row = Math.floor(i / 4) - 1 // -1, 0, 1
        const x = col * 28 + (Math.random() - 0.5) * 6
        const z = row * 18 + (Math.random() - 0.5) * 4
        axisVerts.push(x, -50, z, x, 50, z)
        // Varied brightness: some brighter reference lines, others ghostly
        const brightness = 0.015 + Math.random() * 0.025
        axisColors.push(brightness, brightness, brightness, brightness, brightness, brightness)
      }
      const axisGeom = new THREE.BufferGeometry()
      axisGeom.setAttribute('position', new THREE.BufferAttribute(new Float32Array(axisVerts), 3))
      axisGeom.setAttribute('color', new THREE.BufferAttribute(new Float32Array(axisColors), 3))
      const axisMat = new THREE.LineBasicMaterial({
        color: 0xd4af37,
        transparent: true,
        opacity: 1.0,
        vertexColors: true,
        blending: THREE.AdditiveBlending,
        depthWrite: false
      })
      const spatialAxes = new THREE.LineSegments(axisGeom, axisMat)
      rootGroup.add(spatialAxes)

      // Title position tracking for particle compression
      const titlePositions: THREE.Vector3[] = []

      const mouse = new THREE.Vector2()
      const handleMouseMove = (event: MouseEvent) => {
        mouse.x = (event.clientX / window.innerWidth) * 2 - 1
        mouse.y = -(event.clientY / window.innerHeight) * 2 + 1
      }
      window.addEventListener('mousemove', handleMouseMove)

      const resizeHandler = () => {
        camera.aspect = window.innerWidth / window.innerHeight
        camera.updateProjectionMatrix()
        renderer.setSize(window.innerWidth, window.innerHeight)
        composer.setSize(window.innerWidth, window.innerHeight)
      }
      window.addEventListener('resize', resizeHandler)

      const painPointTweens = gsap.utils.toArray<HTMLElement>('.pain-point').map((point, index) =>
        gsap.fromTo(
          point,
          { opacity: 0, x: -20 },
          {
            opacity: 1,
            x: 0,
            duration: 0.5,
            delay: index * 0.2,
            scrollTrigger: {
              trigger: '#section-2',
              start: 'top center',
              toggleActions: 'play none none reverse'
            }
          }
        )
      )

      const particlePhase: ParticlePhaseMix = {
        scatter: 1,
        inner: 0,
        expansion: 0,
        cursorPull: 0,
        alignment: 0,
        scrollY: 0
      }
      const positionsAttr = particlesGeom.getAttribute('position') as THREE.BufferAttribute
      const displayMat = displayMesh.material
      const cursorWorld = new THREE.Vector3()
      const cursorRay = new THREE.Raycaster()
      const cursorPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0)
      const cursorHit = new THREE.Vector3()

      glowMaterial.uniforms.opacity.value = 0.14
      wireframeMaterial.opacity = 0.1
      logoGroup.rotation.set(0, 0, 0)
      rootGroup.rotation.set(0, 0, 0)

      // Single smooth timeline — monotonic camera dolly, no bouncing
      const timeline = gsap.timeline({ paused: true })
      // Camera smoothly approaches — ONE direction only
      timeline.to(camera.position, { z: 28, duration: 6, ease: 'power2.inOut' }, 0)
      // Logo glow builds then stays bright
      timeline.to(glowMaterial.uniforms.opacity, { value: 0.22, duration: 2.8, ease: 'power3.out' }, 0.4)
      timeline.to(wireframeMaterial, { opacity: 0.14, duration: 2.4, ease: 'power3.out' }, 0.6)
      // Particles tighten to logo
      timeline.to(particlePhase, { inner: 1, duration: 3.2, ease: 'power3.inOut' }, 2.5)
      // Logo becomes solid
      timeline.to(displayMat, { opacity: 1, duration: 2.0, ease: 'power3.out' }, 3.0)
      // Logo drifts up slightly to make room for content
      timeline.to(logoGroup.position, { y: 4.2, duration: 3.0, ease: 'power3.inOut' }, 3.0)
      timeline.to(particlesMaterial, { opacity: 0.88, duration: 2.0, ease: 'power3.out' }, 3.0)
      // Glow stays vivid on scroll — no dimming
      timeline.to(glowMaterial.uniforms.opacity, { value: 0.18, duration: 2.0, ease: 'power2.out' }, 4.5)
      timeline.to(wireframeMaterial, { opacity: 0.12, duration: 2.0, ease: 'power2.out' }, 4.5)
      const timelineProgress = gsap.quickTo(timeline, 'progress', { duration: 0.6, ease: 'power2.out' })

      let introComplete = false
      gsap.to(particlePhase, {
        scatter: 0,
        duration: FORMATION_DURATION,
        delay: 0.4,
        ease: 'power3.out',
        onComplete: () => {
          introComplete = true
        }
      })

      // Single unified scroll trigger — no more fighting between 3 triggers
      const scrollTimelineTrigger = ScrollTrigger.create({
        trigger: main,
        start: 'top top',
        end: 'bottom bottom',
        scrub: 1.6,
        onUpdate: (self) => {
          if (!introComplete) return
          const p = self.progress
          // Smooth timeline progression
          timelineProgress(p)
          // Store scroll progress for parallax depth layers
          particlePhase.scrollY = p
          // Expansion: particles gently push outward as you scroll deeper
          particlePhase.expansion = gsap.utils.clamp(0, 1, (p - 0.15) / 0.5)
          // Cursor pull activates in the middle sections
          particlePhase.cursorPull = gsap.utils.clamp(0, 1, (p - 0.25) / 0.35)
          // Cursor pull fades at the bottom
          if (p > 0.75) {
            particlePhase.cursorPull *= gsap.utils.clamp(0, 1, (1 - p) / 0.25)
          }
          // Alignment fields: emerge during Process/Solution sections (0.35-0.7)
          if (p > 0.35 && p < 0.7) {
            const alignT = (p - 0.35) / 0.35
            particlePhase.alignment = Math.sin(alignT * Math.PI) // bell curve: 0→1→0
          } else {
            particlePhase.alignment = Math.max(0, particlePhase.alignment - 0.02)
          }
          // Calibration rings: visible during sections 3-4 (scroll 0.3-0.6)
          if (p > 0.3 && p < 0.6) {
            const ringT = (p - 0.3) / 0.3
            ringTargetOpacity = Math.sin(ringT * Math.PI) * RING_MAX_OPACITY
          } else {
            ringTargetOpacity = 0
          }
        }
      })

      const cards = gsap.utils.toArray<HTMLElement>('.process-card')
      const connections = cards.map((card) => {
        const lineGeometry = new THREE.BufferGeometry().setFromPoints([
          new THREE.Vector3(0, 0, 0),
          new THREE.Vector3(0, 0, 0)
        ])
        const lineMaterial = new THREE.LineBasicMaterial({
          color: 0xd4af37,
          transparent: true,
          opacity: 0,
          blending: THREE.AdditiveBlending,
          depthWrite: false
        })
        const line = new THREE.Line(lineGeometry, lineMaterial)
        scene.add(line)

        const popInTl = gsap.timeline({ paused: true }).fromTo(
          card,
          { opacity: 0, scale: 0.95, y: 20 },
          {
            opacity: 1,
            scale: 1,
            y: 0,
            boxShadow: '0 0 28px 6px rgba(201, 162, 39, 0.45)',
            duration: 0.5,
            ease: 'power2.out'
          }
        )

        return { card, line, popInTl }
      })

      const processTrigger = ScrollTrigger.create({
        trigger: '#section-3',
        start: 'top 80%',
        end: 'bottom 20%',
        scrub: true,
        onUpdate: () => {
          let activeIndex = -1
          let smallestDist = Infinity
          const triggerPoint = window.innerHeight * 0.4

          connections.forEach((entry, index) => {
            const rect = entry.card.getBoundingClientRect()
            const dist = Math.abs(rect.top - triggerPoint)
            if (rect.top < window.innerHeight && rect.bottom > 0 && dist < smallestDist) {
              smallestDist = dist
              activeIndex = index
            }
          })

          connections.forEach((entry, index) => {
            const rect = entry.card.getBoundingClientRect()
            const progress = gsap.utils.clamp(
              0,
              1,
              gsap.utils.mapRange(window.innerHeight * 0.8, window.innerHeight * 0.3, 0, 1, rect.top)
            )
            entry.popInTl.progress(progress)
            entry.line.material.opacity = index === activeIndex ? progress : 0
          })
        }
      })

      const solutionPanel = document.getElementById('solution-panel')
      const solutionTween = solutionPanel
        ? gsap.fromTo(
          solutionPanel,
          { opacity: 0, y: 50 },
          {
            opacity: 1,
            y: 0,
            duration: 0.7,
            ease: 'power2.out',
            boxShadow: '0 0 28px 6px rgba(201, 162, 39, 0.4)',
            scrollTrigger: {
              trigger: solutionPanel,
              start: 'top 85%',
              toggleActions: 'play none none reverse'
            }
          }
        )
        : null

      let activeConnectionRadius = logoRadius * 1.25

      const clock = new THREE.Clock()
      let frameId = 0
      let ticks = 0

      const animate = () => {
        const elapsed = clock.getElapsedTime()

        cursorRay.setFromCamera(mouse, camera)
        if (cursorRay.ray.intersectPlane(cursorPlane, cursorHit)) {
          cursorWorld.copy(cursorHit)
        } else {
          cursorWorld.set(mouse.x * 14, mouse.y * 10 + logoGroup.position.y * 0.2, 2)
        }

        // ── Project visible titles to 3D for particle compression ────
        // Throttled: only recalculate DOM bounds every 12 frames to prevent layout thrashing
        if (ticks % 12 === 0) {
          titlePositions.length = 0
          document.querySelectorAll('h2').forEach((el) => {
            const rect = el.getBoundingClientRect()
            if (rect.top < window.innerHeight && rect.bottom > 0) {
              const ndcX = ((rect.left + rect.width / 2) / window.innerWidth) * 2 - 1
              const ndcY = -((rect.top + rect.height / 2) / window.innerHeight) * 2 + 1
              const worldPos = new THREE.Vector3(ndcX, ndcY, 0.5).unproject(camera)
              titlePositions.push(worldPos)
            }
          })
        }
        ticks++

        updateParticles(
          positionsAttr,
          scatterPositions,
          outerShell,
          innerShell,
          phases,
          particlePhase,
          elapsed,
          logoOrbitCount,
          logoGroup.position.y,
          logoRadius,
          cursorWorld,
          particleVelocities,
          formationDelays,
          titlePositions
        )

        // ── Calibration ring animation ───────────────────────────────
        ringInner.mesh.rotation.z += RING_ROTATE_INNER
        ringMid.mesh.rotation.z += RING_ROTATE_MID
        ringOuter.mesh.rotation.z += RING_ROTATE_OUTER
        const ringSmooth = 0.04
        ringInner.mat.opacity += (ringTargetOpacity - ringInner.mat.opacity) * ringSmooth
        ringMid.mat.opacity += (ringTargetOpacity * 0.7 - ringMid.mat.opacity) * ringSmooth * 0.7
        ringOuter.mat.opacity += (ringTargetOpacity * 0.4 - ringOuter.mat.opacity) * ringSmooth * 0.5

        // Logo breathing activation — subtle pulsing after formation
        if (introComplete) {
          const glowBreath = Math.sin(elapsed * 0.4) * BREATH_GLOW_AMP
          const wireBreath = Math.sin(elapsed * 0.55) * BREATH_WIRE_AMP
          const bloomBreath = Math.sin(elapsed * 0.3) * BREATH_BLOOM_AMP
          glowMaterial.uniforms.opacity.value += glowBreath
          wireframeMaterial.opacity += wireBreath
          bloomPass.strength = 1.3 + bloomBreath
          if (displayMesh.material instanceof THREE.MeshPhysicalMaterial) {
            displayMesh.material.emissiveIntensity = 0.15 + Math.sin(elapsed * 0.5) * BREATH_EMISSIVE_AMP
          }
        }

        // Constellation lines — elegant particle connections near cursor
        const constellationActive = particlePhase.cursorPull > 0.3 && particlePhase.expansion > 0.3
        if (constellationActive) {
          constellationTargetOpacity = Math.min(0.14, particlePhase.cursorPull * 0.18)
          const nearCursor: number[] = []
          const rSq = CONSTELLATION_CURSOR_RADIUS * CONSTELLATION_CURSOR_RADIUS
          for (let i = 0; i < PARTICLE_COUNT && nearCursor.length < 150; i++) {
            const px = positionsAttr.getX(i)
            const py = positionsAttr.getY(i)
            const pz = positionsAttr.getZ(i)
            const dx = px - cursorWorld.x
            const dy = py - cursorWorld.y
            const dz = pz - cursorWorld.z
            if (dx * dx + dy * dy + dz * dz < rSq) nearCursor.push(i)
          }
          let lineCount = 0
          const cPosAttr = constellationGeom.getAttribute('position') as THREE.BufferAttribute
          const threshSq = CONSTELLATION_DISTANCE * CONSTELLATION_DISTANCE
          for (let a = 0; a < nearCursor.length && lineCount < MAX_CONSTELLATION_LINES; a++) {
            const ia = nearCursor[a]!
            const ax = positionsAttr.getX(ia), ay = positionsAttr.getY(ia), az = positionsAttr.getZ(ia)
            for (let b = a + 1; b < nearCursor.length && lineCount < MAX_CONSTELLATION_LINES; b++) {
              const ib = nearCursor[b]!
              const bx = positionsAttr.getX(ib), by = positionsAttr.getY(ib), bz = positionsAttr.getZ(ib)
              const dSq = (ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2
              if (dSq < threshSq) {
                const vi = lineCount * 6
                cPosAttr.array[vi] = ax; cPosAttr.array[vi + 1] = ay; cPosAttr.array[vi + 2] = az
                cPosAttr.array[vi + 3] = bx; cPosAttr.array[vi + 4] = by; cPosAttr.array[vi + 5] = bz
                lineCount++
              }
            }
          }
          constellationGeom.setDrawRange(0, lineCount * 2)
          cPosAttr.needsUpdate = true
        } else {
          constellationTargetOpacity = 0
          constellationGeom.setDrawRange(0, 0)
        }
        constellationMaterial.opacity += (constellationTargetOpacity - constellationMaterial.opacity) * 0.08

        const scrollProgress = timeline.progress()
        const logoLocked = scrollProgress >= 0.5

        // Camera parallax + subtle atmospheric drift
        const driftX = Math.sin(elapsed * 0.08) * CAMERA_DRIFT_AMP
        const driftY = Math.cos(elapsed * 0.06) * CAMERA_DRIFT_AMP * 0.6
        const smoothedMouseX = camera.position.x + (mouse.x * 1.6 + driftX - camera.position.x) * 0.05
        const smoothedMouseY = camera.position.y + (mouse.y * 1.2 + driftY - camera.position.y) * 0.05
        camera.position.x = smoothedMouseX
        camera.position.y = smoothedMouseY
        camera.lookAt(scene.position)

        if (logoLocked) {
          const logoWorldPos = new THREE.Vector3()
          logoGroup.getWorldPosition(logoWorldPos)
          const logoScreenPos = logoWorldPos.clone().project(camera)
          const logoScreenX = (logoScreenPos.x + 1) * window.innerWidth / 2
          const logoScreenY = (-logoScreenPos.y + 1) * window.innerHeight / 2

          document
            .querySelectorAll(
              'h1, h2, h3, h1 > span:not(.accent-gold), h2 > span:not(.accent-gold), h3 > span:not(.accent-gold)'
            )
            .forEach((element) => {
              if (element.classList.contains('accent-gold')) return
              const rect = element.getBoundingClientRect()
              const isOverlapping = logoScreenY >= rect.top - 150 && logoScreenY <= rect.bottom + 150
              if (isOverlapping) {
                const textCenterX = rect.left + rect.width / 2
                const textCenterY = rect.top + rect.height / 2
                const distance = Math.hypot(logoScreenX - textCenterX, logoScreenY - textCenterY)
                const intensity = Math.max(0, 1 - distance / 300)
                  ; (element as HTMLElement).style.setProperty('--glow-intensity', intensity.toFixed(2))
                element.classList.add('localized-glow')
              } else {
                element.classList.remove('localized-glow')
                  ; (element as HTMLElement).style.removeProperty('--glow-intensity')
              }
            })
        }

        const worldCenter = new THREE.Vector3()
        logoGroup.getWorldPosition(worldCenter)

        connections.forEach((entry) => {
          const progress = entry.popInTl.progress()
          if (progress <= 0) {
            gsap.set(entry.card, { x: 0, y: 0 })
            return
          }
          gsap.set(entry.card, { x: -smoothedMouseX * 9, y: -smoothedMouseY * 9 })
          const rect = entry.card.getBoundingClientRect()
          const cardX = ((rect.left + rect.width / 2) / window.innerWidth) * 2 - 1
          const cardY = -((rect.top + rect.height / 2) / window.innerHeight) * 2 + 1
          const cardWorldPos = new THREE.Vector3(cardX, cardY, 0.5).unproject(camera)
          const surfaceDirection = cardWorldPos.clone().sub(worldCenter).normalize()
          const worldSurfacePoint = worldCenter.clone().add(surfaceDirection.multiplyScalar(activeConnectionRadius))
          const posAttr = entry.line.geometry.attributes.position as THREE.BufferAttribute
          posAttr.setXYZ(0, worldSurfacePoint.x, worldSurfacePoint.y, worldSurfacePoint.z)
          posAttr.setXYZ(1, cardWorldPos.x, cardWorldPos.y, cardWorldPos.z)
          posAttr.needsUpdate = true
        })

        composer.render()
        frameId = requestAnimationFrame(animate)
      }

      animate()

      const readyTimeout = window.setTimeout(() => {
        canvas.classList.add('canvas-visible')
        onReady?.()
      }, 700)

      let tornDown = false
      const teardown = () => {
        if (tornDown) return
        tornDown = true
        window.clearTimeout(readyTimeout)
        cancelAnimationFrame(frameId)
        window.removeEventListener('mousemove', handleMouseMove)
        window.removeEventListener('resize', resizeHandler)
        painPointTweens.forEach((t) => t?.kill())
        solutionTween?.kill()
        scrollTimelineTrigger.kill()
        processTrigger.kill()
        timeline.kill()
        ScrollTrigger.getAll().forEach((t) => t.kill())
        connections.forEach((entry) => {
          scene.remove(entry.line)
          entry.line.geometry.dispose()
          entry.line.material.dispose()
        })
        particlesGeom.dispose()
        particlesMaterial.dispose()
        constellationGeom.dispose()
        constellationMaterial.dispose()
        scene.remove(constellationLines)
        glowMaterial.dispose()
        wireframe.geometry.dispose()
        wireframeMaterial.dispose()
        axisGeom.dispose()
        axisMat.dispose()
        const sharedGeom = displayMesh.geometry
        sharedGeom.dispose()
        if (displayMesh.material instanceof THREE.Material) displayMesh.material.dispose()
        if (!usingGlb) fallbackGeom.dispose()
        composer.dispose()
        renderer.dispose()
      }

      disposers.push(teardown)
      if (cancelled) teardown()
    }

    void run()

    return () => {
      cancelled = true
      disposers.forEach((d) => d())
    }
  }, [canvasRef, mainRef, onReady])

  return <canvas ref={canvasRef} id="bg-canvas" />
}

export default SceneManager
