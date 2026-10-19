"""Generate the run/walk/tick chimes as CAF files. Pure Python; requires afconvert (macOS)."""
import math, struct, wave, subprocess, os, tempfile

RATE = 44100

def tone(path, notes, dur=0.12, gap=0.02, vol=0.5):
    frames = bytearray()
    for f in notes:
        n = int(RATE * dur)
        for i in range(n):
            env = min(1.0, i / (RATE * 0.005), (n - i) / (RATE * 0.03))
            v = vol * env * math.sin(2 * math.pi * f * i / RATE)
            frames += struct.pack('<h', int(v * 32767))
        frames += b'\x00\x00' * int(RATE * gap)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(bytes(frames))

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Couch5k', 'Audio', 'Sounds')
os.makedirs(out, exist_ok=True)
tmp = tempfile.mkdtemp()
tone(f'{tmp}/run.wav', [660, 880, 1100])          # rising: go
tone(f'{tmp}/walk.wav', [880, 660])               # falling: ease off
tone(f'{tmp}/tick.wav', [1320], dur=0.05, vol=0.3)
for n in ['run', 'walk', 'tick']:
    subprocess.run(['afconvert', '-f', 'caff', '-d', 'LEI16', f'{tmp}/{n}.wav', os.path.join(out, f'{n}.caf')], check=True)
    print('wrote', n)
