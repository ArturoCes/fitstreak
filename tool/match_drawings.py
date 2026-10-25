"""Matches free-exercise-db exercises with Everkinetic drawings by name.

  match_drawings.py <free.json> <everkinetic.json> <png_dir> <out.json>

Writes {exercise_id: {drawings, everkinetic, score}} and prints the
approximate matches so they can be reviewed by hand.
"""
import json
import re
import sys

free_path, ever_path, png_dir, out_path = sys.argv[1:5]
import os

free = json.load(open(free_path, encoding="utf-8"))
ever = json.load(open(ever_path, encoding="utf-8"))
pngs = set(os.listdir(png_dir))

STOP = {"the", "a", "with", "on", "to", "and", "of", "exercise", "version"}
SYN = {
    "dumbbells": "dumbbell", "db": "dumbbell", "bb": "barbell",
    "pushup": "push up", "pushups": "push up", "pullup": "pull up", "pullups": "pull up",
    "ups": "up", "downs": "down", "pulldown": "pull down", "pulldowns": "pull down",
    "chinup": "chin up", "chinups": "chin up", "situp": "sit up", "situps": "sit up",
    "curls": "curl", "raises": "raise", "rows": "row", "presses": "press",
    "extensions": "extension", "flyes": "fly", "flys": "fly", "flies": "fly",
    "crunches": "crunch", "lunges": "lunge", "squats": "squat", "dips": "dip",
    "shrugs": "shrug", "kickbacks": "kickback", "deadlifts": "deadlift",
    "lateral": "lateral", "side": "lateral",
}


def tokens(name):
    """Normalized set of meaningful words of an exercise name (singular,
    synonyms unified, stop words removed)."""
    s = name.lower().replace("-", " ").replace("_", " ").replace("dead lift", "deadlift")
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    words = []
    for w in s.split():
        w = SYN.get(w, w)
        words.extend(w.split())
    return frozenset(w for w in words if w not in STOP)


ever_entries = []
for e in ever:
    imgs = [f"{e['id_num']}-relaxation.png", f"{e['id_num']}-tension.png"]
    if not all(i in pngs for i in imgs):
        continue
    ever_entries.append((tokens(e["title"]), e, imgs))

mapping = {}
exact = fuzzy = 0
for f in free:
    ft = tokens(f["name"])
    best, best_score = None, 0.0
    for et, e, imgs in ever_entries:
        if not ft or not et:
            continue
        inter = len(ft & et)
        score = inter / len(ft | et)
        if score > best_score:
            best, best_score = (e, imgs), score
    # Words that change the posture or variant: if only one side has it, the
    # drawing doesn't show that exercise.
    KEY = {"incline", "decline", "rear", "triceps", "hack", "pistol", "reverse",
           "band", "bands", "front", "seated", "standing", "lying", "wide",
           "close", "narrow", "smith"}
    if best and best_score < 1.0 and (ft ^ tokens(best[0]["title"])) & KEY:
        best, best_score = None, 0.0
    # If one name contains the other and only neutral words are left over
    # (equipment, medium grip...), it is the same movement: "Barbell Bench
    # Press - Medium Grip" ≈ "Bench Press".
    NEUTRAL = {"barbell", "dumbbell", "cable", "machine", "medium", "grip", "ez",
               "bar", "weighted", "bodyweight", "body", "using", "lever",
               "leverage", "plate", "weight", "only", "powerlifting"}
    if not best or best_score < 0.75:
        for et, e, imgs in ever_entries:
            if et and (et <= ft or ft <= et) and (ft ^ et) <= NEUTRAL:
                best, best_score = (e, imgs), 0.7
                break
    if best and best_score == 0.7:
        fuzzy += 1
    elif best and best_score == 1.0:
        exact += 1
    elif best and best_score >= 0.75:
        fuzzy += 1
    else:
        continue
    mapping[f["id"]] = {"drawings": best[1], "everkinetic": best[0]["title"], "score": round(best_score, 2)}

json.dump(mapping, open(out_path, "w", encoding="utf-8"), indent=1)
print(f"free={len(free)} ever_con_png={len(ever_entries)} exactos={exact} aproximados={fuzzy} total={len(mapping)}")
for k, v in list(mapping.items()):
    if v["score"] < 1.0:
        print(f"  ~ {k}  <->  {v['everkinetic']}  ({v['score']})")
