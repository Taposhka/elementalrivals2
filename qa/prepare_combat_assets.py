from pathlib import Path
import shutil
import json
import numpy as np
import soundfile as sf

p = Path(__file__).resolve().parent.parent
downloads = Path(r"C:\Users\99899\Downloads")
images = downloads / "AyuGram Desktop"
copies = {
    "background-remover-1794726842852.png": "combo_wow.png",
    "New Piskel (12).png": "element_water.png",
    "Fire icon-1.png.png": "element_fire.png",
    "ICE.png": "element_ice.png",
}
for source, target in copies.items():
    shutil.copy2(images / source, p / "assets" / "ui" / target)

sources = {
    "steam": "dragon-studio-steam-hissing-2-386162.mp3",
    "explosion": "kalsstockmedia-explosion-3-274684.mp3",
    "thunder": "pwlpl-loud-thunder-sound-effect-359272.mp3",
    "fire": "djartmusic-short-fire-whoosh_1-317280.mp3",
    "wind": "alexzavesa-strong-wind-1-463603.mp3",
    "electric": "freesound_community-electricity-106510.mp3",
    "wave": "dragon-studio-wave-on-the-shore-390306.mp3",
    "ice": "dragon-studio-winter-wind-402331.mp3",
    "bright": "soundreality-whoosh-bright-panning-6-620360.mp3",
    "swipe": "floraphonic-transitional-swipe-3-211685.mp3",
}
recipes = {
    "fire_dash": ("fire", 0.28, "peak"),
    "fire_burst": ("fire", 1.1, "onset"),
    "water_attack": ("wave", 0.30, "peak"),
    "water_burst": ("wave", 1.15, "onset"),
    "ice_attack": ("ice", 0.23, "peak"),
    "ice_burst": ("ice", 1.4, "onset"),
    "electric_attack": ("electric", 0.18, "peak"),
    "electric_burst": ("electric", 0.48, "onset"),
    "wind_attack": ("bright", 0.24, "peak"),
    "wind_burst": ("wind", 1.5, "peak"),
    "thunder_burst": ("thunder", 1.9, "onset"),
    "steam_burst": ("steam", 0.85, "onset"),
    "explosion": ("explosion", 1.5, "onset"),
    "combo": ("bright", 0.55, "peak"),
    "swipe": ("swipe", 0.16, "peak"),
    "hit": ("swipe", 0.075, "peak"),
}
loaded = {}
manifest = {}
for key, (source_key, duration, mode) in recipes.items():
    filename = sources[source_key]
    if source_key not in loaded:
        audio, rate = sf.read(downloads / filename, dtype="float32", always_2d=True)
        mono = audio.mean(axis=1)
        window = max(1, int(rate * 0.01))
        blocks = mono[:len(mono)//window*window].reshape(-1, window)
        rms = np.sqrt(np.mean(blocks * blocks, axis=1))
        onset = int(np.flatnonzero(rms > max(0.003, float(rms.max()) * .25))[0]) * window
        peak = int(np.argmax(rms)) * window
        loaded[source_key] = (mono, rate, max(0, onset-int(rate*.02)), max(0, peak-int(rate*.025)))
    mono, rate, onset, peak = loaded[source_key]
    start = onset if mode == "onset" else peak
    start = min(start, max(0, len(mono)-int(rate*duration)))
    clip = mono[start:start+int(rate*duration)].copy()
    target_rate = 22050
    count = max(1, int(len(clip) * target_rate / rate))
    clip = np.interp(np.arange(count)/target_rate, np.arange(len(clip))/rate, clip).astype(np.float32)
    level = max(1e-5, float(np.sqrt(np.mean(clip * clip))))
    gain = min(10**(-18/20)/level, .89/max(1e-5,float(np.max(np.abs(clip)))))
    clip *= gain
    fade = min(len(clip)//3, int(target_rate*.012))
    clip[:fade] *= np.linspace(0,1,fade)
    clip[-fade:] *= np.linspace(1,0,fade)
    sf.write(p/"assets"/"audio"/f"{key}.wav", clip, target_rate, subtype="PCM_16")
    manifest[key] = {"source": filename, "start": round(start/rate,4), "seconds": round(len(clip)/target_rate,4), "gain_db": round(20*np.log10(gain),2)}
(p/"assets"/"audio"/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print(f"Copied {len(copies)} image assets and prepared {len(recipes)} short SFX from all {len(sources)} source recordings.")
