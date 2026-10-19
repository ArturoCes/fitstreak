"""Herramientas para traducir las instrucciones de los ejercicios.

  dump  <exercises.json> <out_dir>       → lotes de texto para traducir
  merge <exercises.json> <tr_dir> <out>  → une los lotes traducidos y valida

Los lotes traducidos son JSON {id: [paso, paso, ...]} con el mismo número de
pasos que el original. Los ejercicios de fuerza van primero porque son los que
usa el generador de rutinas.
"""
import json
import os
import sys

BATCH_CHARS = 22000


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def ordered(exercises):
    strength = {"strength", "powerlifting"}
    return sorted(exercises, key=lambda e: (e["category"] not in strength, e["id"]))


def dump(src, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    batch, size, n = [], 0, 0
    for e in ordered(load(src)):
        if not e["instructions"]:
            continue
        chunk = e["id"] + "\n" + "\n".join(f"{i + 1}. {s}" for i, s in enumerate(e["instructions"]))
        if size + len(chunk) > BATCH_CHARS and batch:
            n += 1
            write_batch(out_dir, n, batch)
            batch, size = [], 0
        batch.append(chunk)
        size += len(chunk)
    if batch:
        n += 1
        write_batch(out_dir, n, batch)
    print(f"{n} lotes")


def write_batch(out_dir, n, chunks):
    with open(os.path.join(out_dir, f"{n:02d}.txt"), "w", encoding="utf-8") as f:
        f.write("\n\n".join(chunks))


def merge(src, tr_dir, out):
    original = {e["id"]: e["instructions"] for e in load(src)}
    merged, problems = {}, []
    for name in sorted(os.listdir(tr_dir)):
        if not name.endswith(".json"):
            continue
        for ex_id, steps in load(os.path.join(tr_dir, name)).items():
            if ex_id not in original:
                problems.append(f"{name}: id desconocido {ex_id}")
            elif len(steps) != len(original[ex_id]):
                problems.append(f"{name}: {ex_id} tiene {len(steps)} pasos, original {len(original[ex_id])}")
            elif any(not s.strip() and o.strip() for s, o in zip(steps, original[ex_id])):
                problems.append(f"{name}: {ex_id} tiene pasos vacíos")
            else:
                merged[ex_id] = steps
    pending = [i for i, s in original.items() if s and i not in merged]
    with open(out, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, separators=(",", ":"))
    print(f"traducidos={len(merged)} pendientes={len(pending)} problemas={len(problems)}")
    for p in problems[:30]:
        print("  " + p)


if __name__ == "__main__":
    cmd, *args = sys.argv[1:]
    {"dump": dump, "merge": merge}[cmd](*args)
