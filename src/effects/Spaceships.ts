import {
  BoxGeometry,
  ConeGeometry,
  CylinderGeometry,
  Group,
  Mesh,
  MeshStandardMaterial,
  MeshBasicMaterial,
  PointLight,
  DirectionalLight,
  AmbientLight,
  Vector3,
  AdditiveBlending,
  SphereGeometry,
} from 'three';
import { SceneLayer } from '../core/SceneLayer';
import type { Frame } from '../core/Frame';

/** Build one sleek synthwave shuttle (dark hull, cyan trim, glowing engines). */
function buildShip(): Group {
  const g = new Group();
  const hullMat = new MeshStandardMaterial({
    color: 0x16131f,
    metalness: 0.85,
    roughness: 0.35,
    emissive: 0x05060a,
  });
  const trimMat = new MeshBasicMaterial({ color: 0x39e6ff });
  const cockpitMat = new MeshStandardMaterial({
    color: 0x0a1820,
    emissive: 0x39e6ff,
    emissiveIntensity: 0.7,
    metalness: 0.6,
    roughness: 0.2,
  });

  // fuselage — stretched, tapered
  const body = new Mesh(new ConeGeometry(0.5, 3.2, 6), hullMat);
  body.rotation.z = -Math.PI / 2;
  body.scale.set(1, 1, 0.5);
  g.add(body);

  // rear block
  const rear = new Mesh(new BoxGeometry(0.9, 0.5, 0.8), hullMat);
  rear.position.x = -1.3;
  g.add(rear);

  // wings
  const wingGeo = new BoxGeometry(1.1, 0.06, 2.6);
  const wing = new Mesh(wingGeo, hullMat);
  wing.position.set(-0.7, -0.05, 0);
  g.add(wing);
  // wing tip trim lights
  for (const z of [-1.25, 1.25]) {
    const tip = new Mesh(new BoxGeometry(0.9, 0.07, 0.08), trimMat);
    tip.position.set(-0.7, -0.02, z);
    g.add(tip);
  }

  // cockpit canopy
  const canopy = new Mesh(new SphereGeometry(0.34, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), cockpitMat);
  canopy.position.set(0.5, 0.2, 0);
  canopy.scale.set(1.6, 1, 0.8);
  g.add(canopy);

  // underglow strip
  const strip = new Mesh(new BoxGeometry(2.2, 0.04, 0.18), trimMat);
  strip.position.set(-0.3, -0.22, 0);
  g.add(strip);

  // engines (two glowing nozzles)
  for (const z of [-0.32, 0.32]) {
    const nozzle = new Mesh(new CylinderGeometry(0.16, 0.2, 0.4, 8), hullMat);
    nozzle.rotation.z = Math.PI / 2;
    nozzle.position.set(-1.7, -0.02, z);
    g.add(nozzle);
    const glow = new Mesh(new SphereGeometry(0.18, 10, 8), new MeshBasicMaterial({
      color: 0xff8a3d,
      transparent: true,
      opacity: 0.95,
      blending: AdditiveBlending,
      depthWrite: false,
    }));
    glow.position.set(-1.95, -0.02, z);
    glow.userData.engine = true;
    g.add(glow);
    const light = new PointLight(0x39c8ff, 1.2, 4);
    light.position.set(-2.1, 0, z);
    g.add(light);
  }

  return g;
}

interface ShipInstance {
  group: Group;
  path: (t: number) => Vector3;
  speed: number;
  phase: number;
  bank: number;
}

/**
 * Squadron of procedural spaceships sweeping through a perspective scene —
 * the "romskip er fantastisk!" hero moment. Ships follow gentle curved paths,
 * bank into turns, and their engines flare on the beat.
 */
export class Spaceships extends SceneLayer {
  readonly name = 'spaceships';
  private ships: ShipInstance[] = [];
  private shake = 0;

  constructor(count = 4) {
    super(55);
    this.camera.position.set(0, 1.5, 9);
    this.camera.lookAt(0, 0, 0);

    this.scene.add(new AmbientLight(0x4a3a66, 1.1));
    const key = new DirectionalLight(0xff7ad0, 1.4);
    key.position.set(5, 6, 4);
    this.scene.add(key);
    const fill = new DirectionalLight(0x39e6ff, 1.0);
    fill.position.set(-6, -2, 3);
    this.scene.add(fill);

    for (let i = 0; i < count; i++) {
      const ship = buildShip();
      const lane = (i - (count - 1) / 2) * 2.2;
      const depth = -2 - i * 1.5;
      const amp = 1.2 + Math.random() * 1.0;
      const path = (t: number): Vector3 =>
        new Vector3(
          Math.sin(t * 0.5) * 6 + lane * 0.3,
          Math.sin(t * 0.8 + i) * amp + 0.5,
          depth + Math.cos(t * 0.4) * 2,
        );
      ship.scale.setScalar(0.8 + Math.random() * 0.5);
      this.scene.add(ship);
      this.ships.push({
        group: ship,
        path,
        speed: 0.4 + Math.random() * 0.25,
        phase: i * 1.7,
        bank: 0,
      });
    }
  }

  update(f: Frame): void {
    this.shake = Math.max(this.shake * 0.9, f.audio.beatPulse * 0.12);
    for (const s of this.ships) {
      const t = f.time * s.speed + s.phase;
      const pos = s.path(t);
      const ahead = s.path(t + 0.05);
      s.group.position.copy(pos);
      // orient along travel direction
      s.group.lookAt(ahead);
      // bank into the turn
      const targetBank = (ahead.y - pos.y) * 1.5;
      s.bank += (targetBank - s.bank) * Math.min(1, f.dt * 4);
      s.group.rotateZ(s.bank);

      // engine flare with the beat
      s.group.traverse((o) => {
        if ((o as Mesh).userData?.engine) {
          const m = (o as Mesh).material as MeshBasicMaterial;
          m.opacity = 0.6 + f.audio.beatPulse * 0.4 + f.audio.bass * 0.3;
          (o as Mesh).scale.setScalar(1 + f.audio.beatPulse * 0.5);
        }
      });
    }
    // subtle audio-reactive camera move
    this.camera.position.x = Math.sin(f.time * 0.3) * 1.5 + (Math.random() - 0.5) * this.shake;
    this.camera.position.y = 1.5 + Math.sin(f.time * 0.4) * 0.4 + (Math.random() - 0.5) * this.shake;
    this.camera.lookAt(0, 0.4, -2);
  }
}
