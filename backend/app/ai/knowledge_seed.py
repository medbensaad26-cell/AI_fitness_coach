"""Seed fitness knowledge used to fill knowledge_chunks for RAG.

These are short, coach-useful facts. Person A owns the content; ingest embeds
them and Person B's DB stores the vectors.
"""

from typing import TypedDict


class KnowledgeSeed(TypedDict):
    category: str
    topic: str
    content: str


# Small starter corpus — enough to test retrieval; expand later.
KNOWLEDGE_SEEDS: list[KnowledgeSeed] = [
    {
        "category": "safety",
        "topic": "pain",
        "content": (
            "Sharp joint pain is a stop signal. Stop the set, note which movement "
            "triggered it, and switch to a pain-free alternative. Muscle burn and "
            "effort are normal; stabbing or radiating pain is not."
        ),
    },
    {
        "category": "safety",
        "topic": "warmup",
        "content": (
            "Start sessions with 5–10 minutes of easy cardio plus 1–2 light warmup "
            "sets of the first main lift. Warm muscles and joints reduce injury risk "
            "and improve first-set quality."
        ),
    },
    {
        "category": "form",
        "topic": "squat",
        "content": (
            "Squat cues: brace the core, keep heels down, track knees over toes, "
            "and sit the hips back and down. Depth should stay controlled; stop "
            "before the lower back rounds."
        ),
    },
    {
        "category": "form",
        "topic": "hinge",
        "content": (
            "Hip-hinge cues (deadlift/RDL): soft knees, push hips back, keep a "
            "long spine, and feel load in the hamstrings and glutes. Do not yank "
            "with the lower back."
        ),
    },
    {
        "category": "form",
        "topic": "pushup",
        "content": (
            "Push-up cues: body in a straight line, ribs down, elbows about 45 "
            "degrees from the torso. If form breaks, elevate hands or drop to "
            "knees rather than sagging the hips."
        ),
    },
    {
        "category": "form",
        "topic": "row",
        "content": (
            "Rowing cues: initiate with the shoulder blades, keep elbows close, "
            "avoid shrugging, and control the eccentric. Stop short of using "
            "momentum from the torso."
        ),
    },
    {
        "category": "programming",
        "topic": "beginner",
        "content": (
            "Beginners progress best with full-body or upper/lower sessions 2–4 "
            "days per week, 1–3 hard sets per exercise, and simple compound "
            "movements before isolation work."
        ),
    },
    {
        "category": "programming",
        "topic": "progressive_overload",
        "content": (
            "Progressive overload means gradually doing more over weeks: extra "
            "reps, slightly more weight, cleaner form, or shorter rest. Change "
            "one variable at a time when the current target becomes easy."
        ),
    },
    {
        "category": "programming",
        "topic": "rest",
        "content": (
            "Rest between hard sets is usually 60–180 seconds. Strength-focused "
            "compounds need longer rests; isolation and lighter accessory work "
            "can use shorter rests."
        ),
    },
    {
        "category": "programming",
        "topic": "frequency",
        "content": (
            "Training a muscle 2+ times per week often beats one marathon session. "
            "Spread volume across the week and leave at least one easier day after "
            "very hard lower-body work."
        ),
    },
    {
        "category": "adaptation",
        "topic": "fatigue",
        "content": (
            "High fatigue after a session suggests reducing volume or intensity "
            "next time, especially for the same muscle group. Persistent exhaustion "
            "across several days means prioritize sleep and deload."
        ),
    },
    {
        "category": "adaptation",
        "topic": "skipped_exercises",
        "content": (
            "If a user repeatedly skips an exercise, replace it with a similar "
            "pattern they tolerate (e.g. lunges → step-ups, barbell squat → goblet "
            "squat) instead of forcing the same movement."
        ),
    },
    {
        "category": "adaptation",
        "topic": "difficulty",
        "content": (
            "Target an average difficulty around 3–4 out of 5 for productive "
            "training. If most sets are 5/5, reduce load or reps. If most are 1–2, "
            "increase challenge gradually."
        ),
    },
    {
        "category": "equipment",
        "topic": "bodyweight",
        "content": (
            "Bodyweight programs can build strength with push-ups, squats, lunges, "
            "hip hinges (good mornings), planks, and inverted rows under a table "
            "or with bands. Raise difficulty with tempo, range, or harder variations."
        ),
    },
    {
        "category": "equipment",
        "topic": "dumbbells",
        "content": (
            "With dumbbells, prioritize goblet squats, Romanian deadlifts, floor "
            "or bench presses, rows, overhead presses, and loaded carries. They "
            "cover most goals without machines."
        ),
    },
    {
        "category": "coaching",
        "topic": "check_in",
        "content": (
            "During a workout, ask briefly how the last set felt (effort 1–5) and "
            "whether anything hurt. Keep cues short: one correction at a time, "
            "then continue the session."
        ),
    },
    {
        "category": "coaching",
        "topic": "breathing",
        "content": (
            "Brace before heavy efforts: inhale, stiffen the midsection, then "
            "move. For repeated reps, exhale on the effort and avoid holding the "
            "breath for the entire set unless doing a brief maximal brace."
        ),
    },
    {
        "category": "limitations",
        "topic": "knees",
        "content": (
            "For sensitive knees, prefer controlled depth, goblet squats, leg "
            "press with comfortable range, step-ups, and avoid pushing through "
            "painful knee tracking. Strengthen hips and quads gradually."
        ),
    },
    {
        "category": "limitations",
        "topic": "lower_back",
        "content": (
            "For lower-back sensitivity, emphasize hip hinges with light loads, "
            "neutral spine, more machine or chest-supported rows, and core bracing. "
            "Avoid loaded spinal flexion under fatigue."
        ),
    },
    {
        "category": "recovery",
        "topic": "sleep",
        "content": (
            "Sleep and protein intake strongly affect recovery and progress. When "
            "feeling poor, keep technique work but cut optional hard sets rather "
            "than pushing PRs."
        ),
    },
]
