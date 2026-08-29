#!/usr/bin/env python3
"""T7: the AQtion #74 reporter's workload — faster-whisper (CTranslate2) on all
threads, looping over a short wav for SECS seconds.  Env: MODEL (default small),
THREADS (24), SECS (1500), CT2_FORCE_CPU_ISA (unset = AVX-512 on this CPU;
the reporter's fault vanished with =AVX2)."""
import os, sys, time
from faster_whisper import WhisperModel

model_name = os.environ.get("MODEL", "small")
threads = int(os.environ.get("THREADS", "24"))
secs = int(os.environ.get("SECS", "1500"))
wav = sys.argv[1] if len(sys.argv) > 1 else "/tmp/k.wav"

t0 = time.time()
m = WhisperModel(model_name, device="cpu", compute_type="int8", cpu_threads=threads, num_workers=1)
print(f"loaded {model_name} in {time.time()-t0:.1f}s threads={threads} isa={os.environ.get('CT2_FORCE_CPU_ISA','default')}", flush=True)
n = 0
end = time.time() + secs
while time.time() < end:
    segs, info = m.transcribe(wav, beam_size=5, language="en")
    text = " ".join(s.text for s in segs)
    n += 1
    if n % 20 == 0:
        print(f"{n} passes, last: {text[:60]!r}", flush=True)
print(f"T7 done: {n} transcriptions in {secs}s", flush=True)
