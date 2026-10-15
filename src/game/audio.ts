import {POKEMON_TYPES,type PokemonType} from "@/pokemon/types/typeChart";
import {moveBehavior,moveVisual,isStreamMove} from "@/pokemon/moves/behavior";
import {arenaMoveProfile} from "@/pokemon/moves/arenaProfile";
export type SfxName = "attack" | "faint" | "lowHp" | "throw" | "land" | "levelUp" | "beep" | "clash" | "dodge" | "hit";
export type MusicName = "battleTrainer" | "battleWild" | "victory" | "defeat" | "select" | `arena:${PokemonType}`;
export function moveSoundFile(name:string,type:PokemonType,utility=false){
  const kind=utility?"status":isStreamMove(moveBehavior(name))?"stream":arenaMoveProfile(name).delivery==="melee"?"melee":moveVisual(name)==="sphere"?"sphere":"projectile";
  return `/assets/arena-audio/${kind}-${type}.wav`;
}

const BASE = "/assets/samy/audio/";
const SFX_FILES: Record<SfxName, string> = {
  clash:"/assets/arena-audio/clash.wav",dodge:"/assets/arena-audio/dodge.wav",hit:"/assets/arena-audio/hit.wav",
  attack: "attack.mp3",
  faint: "faint.mp3",
  lowHp: "low-hp.mp3",
  throw: "throw.mp3",
  land: "land.mp3",
  levelUp: "rarecandy.mp3",
  beep: "beep.mp3",
};
const MUSIC_FILES: Record<MusicName, { file: string; loop: boolean }> = {
  ...Object.fromEntries(POKEMON_TYPES.map(type=>[`arena:${type}`,{file:`/assets/arena-audio/battle-${type}.wav`,loop:true}])) as Record<`arena:${PokemonType}`,{file:string;loop:boolean}>,
  battleTrainer: { file: "trainer-battle.mp3", loop: true },
  battleWild: { file: "trainer-battle2.mp3", loop: true },
  victory: { file: "victory.mp3", loop: false },
  defeat: { file: "failed.mp3", loop: false },
  select: { file: "select.mp3", loop: true },
};

/** The slice of HTMLAudioElement we use (lets tests inject a fake). */
export interface AudioLike {
  src: string;
  volume: number;
  loop: boolean;
  currentTime: number;
  play(): Promise<void> | void;
  pause(): void;
  addEventListener(type: "error", fn: () => void): void;
}

const MUTE_KEY = "peh:muted";
const MUSIC_MUTE_KEY = "peh:music-muted";
const MUSIC_VOLUME_KEY = "peh:music-volume";
const MIN_SFX_GAP_MS = 70;

export class AudioManager {
  muted = false;
  musicMuted = false;
  musicVolume = 0.3;
  sfxVolume = 0.55;
  private music: { name: MusicName; el: AudioLike } | null = null;
  private broken = new Set<string>();
  private lastSfx = new Map<string, number>();
  private voices: AudioLike[] = [];
  private pending: MusicName | null = null;
  private listeners = new Set<() => void>();

  constructor(
    private make: (src: string) => AudioLike,
    private now: () => number = () => Date.now(),
    storage?: Pick<Storage, "getItem" | "setItem">,
  ) {
    this.storage = storage;
    try {
      this.muted = storage?.getItem(MUTE_KEY) === "1";
      this.musicMuted = storage?.getItem(MUSIC_MUTE_KEY) === "1";
      const savedVolume = storage?.getItem(MUSIC_VOLUME_KEY);
      if (savedVolume != null && savedVolume.trim() !== "" && Number.isFinite(Number(savedVolume))) {
        this.musicVolume = Math.max(0, Math.min(1, Number(savedVolume)));
      }
    } catch {
      /* storage unavailable */
    }
  }
  private storage?: Pick<Storage, "getItem" | "setItem">;

  subscribe = (fn: () => void) => {
    this.listeners.add(fn);
    return () => {
      this.listeners.delete(fn);
    };
  };

  setMuted(muted: boolean) {
    this.muted = muted;
    try {
      this.storage?.setItem(MUTE_KEY, muted ? "1" : "0");
    } catch {
      /* ignore */
    }
    if (muted) {this.music?.el.pause();this.stopSfx();}
    else if (this.music && !this.musicMuted) this.start(this.music.el, this.music.name);
    this.listeners.forEach((l) => l());
  }

  setMusicMuted(muted: boolean) {
    this.musicMuted = muted;
    try { this.storage?.setItem(MUSIC_MUTE_KEY, muted ? "1" : "0"); } catch { /* unavailable storage */ }
    if (muted) this.music?.el.pause();
    else if (this.music && !this.muted) this.start(this.music.el, this.music.name);
    this.listeners.forEach(l => l());
  }

  setMusicVolume(volume: number) {
    if (!Number.isFinite(volume)) return;
    this.musicVolume = Math.max(0, Math.min(1, volume));
    if (this.music) this.music.el.volume = this.musicVolume;
    try { this.storage?.setItem(MUSIC_VOLUME_KEY, String(this.musicVolume)); } catch { /* unavailable storage */ }
    this.listeners.forEach(l => l());
  }

  private create(file: string): AudioLike | null {
    if (this.broken.has(file)) return null;
    const el = this.make(file.startsWith("/")?file:BASE + file);
    el.addEventListener("error", () => this.broken.add(file)); // file not imported: stay silent
    return el;
  }

  playSfx(name: SfxName) {
    if (this.muted) return;
    const t = this.now();
    if (t - (this.lastSfx.get(name) ?? -Infinity) < MIN_SFX_GAP_MS) return;
    this.lastSfx.set(name, t);
    const el = this.create(SFX_FILES[name]);
    if (!el) return;
    this.trackVoice(el);el.volume = this.sfxVolume;
    void Promise.resolve(el.play()).catch(() => undefined);
  }
  playMoveSfx(name:string,type:PokemonType,utility=false):AudioLike|null {
    if(this.muted)return null;
    const file=moveSoundFile(name,type,utility),t=this.now();
    if(t-(this.lastSfx.get(file)??-Infinity)<MIN_SFX_GAP_MS)return null;
    this.lastSfx.set(file,t);const el=this.create(file);if(!el)return null;
    this.trackVoice(el);el.volume=this.sfxVolume;void Promise.resolve(el.play()).catch(()=>undefined);return el;
  }

  private trackVoice(el:AudioLike) {this.voices.push(el);if(this.voices.length>12)this.voices.shift()?.pause();}
  stopSfx(){this.voices.forEach(el=>el.pause());this.voices=[];}
  playArenaMusic(type:string){const valid=POKEMON_TYPES.find(t=>t===type)??"normal";this.playMusic(`arena:${valid}`);}
  playMusic(name: MusicName) {
    if (this.music?.name === name) return;
    this.stopMusic();
    const def = MUSIC_FILES[name];
    const el = this.create(def.file);
    if (!el) return;
    el.loop = def.loop;
    el.volume = this.musicVolume;
    this.music = { name, el };
    if (!this.muted && !this.musicMuted) this.start(el, name);
  }

  private start(el: AudioLike, name: MusicName) {
    void Promise.resolve(el.play()).catch(() => {
      // autoplay blocked: retry on the first user gesture
      this.pending = name;
    });
  }

  /** Call from a user-gesture handler to release music that was blocked by autoplay rules. */
  unlock() {
    if (this.pending && this.music?.name === this.pending && !this.muted && !this.musicMuted) this.start(this.music.el, this.pending);
    this.pending = null;
  }

  stopMusic() {
    if (!this.music) return;
    this.music.el.pause();
    this.music.el.currentTime = 0;
    this.music = null;
    this.pending = null;
  }
}

let instance: AudioManager | null = null;

/** Browser singleton; null on the server. */
export function getAudio(): AudioManager | null {
  if (typeof window === "undefined") return null;
  if (!instance) {
    let storage: Storage | undefined;
    try {
      storage = window.localStorage;
    } catch {
      storage = undefined;
    }
    instance = new AudioManager((src) => new Audio(src) as unknown as AudioLike, undefined, storage);
    const unlock = () => instance?.unlock();
    window.addEventListener("pointerdown", unlock, { passive: true });
    window.addEventListener("keydown", unlock);
  }
  return instance;
}
