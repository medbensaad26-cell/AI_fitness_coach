# API contracts — mobile frontend

Base URL: `http://localhost:8000`  
Interactive OpenAPI: `http://localhost:8000/docs`

**Authentication:** unless noted, send  
`Authorization: Bearer <access_token>`  
Obtain a token with `POST /api/login` (`email`, `password` → `access_token`).

All endpoints below are **implemented**.

---

## 1. `PATCH /api/me/profile`

### Purpose
Partially update the authenticated user's fitness profile. Omitted fields are left unchanged.

### Authentication
Required (Bearer JWT).

### Request JSON (`UserProfileUpdate`)
All fields optional. Only fields present in the JSON are applied.

| Field | Type | Validation |
|-------|------|------------|
| `name` | string \| null | — |
| `age` | integer \| null | `gt=0` when set |
| `sex` | string \| null | — |
| `height_cm` | number \| null | `gt=0` when set |
| `weight_kg` | number \| null | `gt=0` when set |
| `fitness_level` | string \| null | — |
| `primary_goal` | string \| null | — |
| `training_frequency` | string \| null | — |
| `available_equipment` | string \| null | — |
| `limitations` | string \| null | — |
| `available_time_minutes` | integer \| null | `gt=0` when set |

Do not send `user_id` or `email` — they are not accepted on this schema. Updates always apply to the JWT user.

### Successful response `200` (`UserProfileResponse`)
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "email": "user@example.com",
  "name": "Alex",
  "age": 28,
  "sex": "female",
  "height_cm": 170.0,
  "weight_kg": 65.0,
  "fitness_level": "intermediate",
  "primary_goal": "strength",
  "training_frequency": "3x/week",
  "available_equipment": "dumbbells",
  "limitations": "none",
  "available_time_minutes": 45,
  "created_at": "2026-01-01",
  "updated_at": "2026-07-23"
}
```
Note: `id` is the **user** id (not the profile row id).

### Status codes
| Code | Meaning |
|------|---------|
| `200` | Updated |
| `401` | Missing/invalid token |
| `404` | Profile not found |
| `422` | Validation error (e.g. `available_time_minutes: 0`) |

### Ownership / security
Only the authenticated user's profile is loaded and updated.

### curl
```bash
curl -X PATCH http://localhost:8000/api/me/profile \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d "{\"available_time_minutes\": 45, \"primary_goal\": \"strength\"}"
```

---

## 2. `POST /api/programs/generate`

### Purpose
Generate a workout program with AI from the user's **database** profile, then persist it and return the saved program.

### Authentication
Required.

### Request JSON (`ProgramGenerateRequest`)
```json
{
  "start_date": "2026-07-23"
}
```

| Field | Type | Validation |
|-------|------|------------|
| `start_date` | date (ISO) \| null/omit | Optional; AI defaults to today if omitted |

Profile fields are **not** taken from the body. Extra fields such as `user_id` are not part of the contract.

Required profile fields (non-null in DB) for generation:  
`name`, `age`, `sex`, `height_cm`, `weight_kg`, `fitness_level`, `primary_goal`, `training_frequency`, `available_equipment`, `limitations`.  
(`available_time_minutes` is stored on the profile but is **not** passed to the AI `ProfileContext` today.)

### Successful response `201` (`ProgramResponse`)
```json
{
  "id": "…",
  "user_id": "…",
  "name": "Strength Session",
  "goal": "strength",
  "start_date": "2026-07-23",
  "end_date": "2026-07-30",
  "status": "active",
  "exercises": [
    {
      "id": "…",
      "program_id": "…",
      "exercise_name": "Goblet Squat",
      "sets": 3,
      "reps": "8-10",
      "rest_seconds": 90,
      "duration_minutes": null,
      "notes": "[id:goblet_squat] Brace core",
      "order": 0
    }
  ]
}
```

### Status codes
| Code | Meaning |
|------|---------|
| `201` | Program created |
| `401` | Unauthorized |
| `400` | Incomplete profile |
| `404` | Profile not found |
| `422` | Invalid body |
| `502` | AI failure or invalid AI `ProgramCreate` |
| `500` | DB persistence failure (rolled back) |

### Ownership / security
Persisted `user_id` is always the JWT user.

### curl
```bash
curl -X POST http://localhost:8000/api/programs/generate \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d "{\"start_date\": \"2026-07-23\"}"
```

---

## 3. `POST /api/programs/suggest-next`

### Purpose
Suggest the next program using AI + the authenticated user's indexed session history (`user_history_chunks`), persist it, and return program plus coaching rationale.

### Authentication
Required.

### Request JSON (`ProgramSuggestNextRequest`)
```json
{
  "start_date": "2026-07-24"
}
```

| Field | Type | Validation |
|-------|------|------------|
| `start_date` | date \| omit | Optional |

Do not send history or `user_id`. Empty history is allowed (AI may produce a first session).

Same incomplete-profile rules as generate.

### Successful response `201` (`ProgramSuggestNextResponse`)
```json
{
  "program": { /* ProgramResponse — same shape as generate */ },
  "rationale": "Progress from last session with slightly higher volume.",
  "adaptations": ["Added RDL", "Reduced fatigue-sensitive volume"]
}
```

### Status codes
| Code | Meaning |
|------|---------|
| `201` | Suggested program persisted |
| `401` | Unauthorized |
| `400` | Incomplete profile |
| `404` | Profile not found |
| `422` | Invalid body |
| `502` | AI failure / invalid suggestion |
| `500` | DB failure (rolled back) |

### Ownership / security
AI and persistence use only `current_user.id`. History is never accepted from the client.

### curl
```bash
curl -X POST http://localhost:8000/api/programs/suggest-next \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d "{}"
```

---

## 4. `POST /api/sessions`

### Purpose
Save a workout session (and per-exercise completion rows) for the authenticated user. After a successful commit, the API best-effort indexes the session for suggest-next (`index_session_history`). Indexing failure does not undo the saved session.

### Authentication
Required.

### Request JSON (`SessionCreate`)
```json
{
  "program_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "start_time": "2026-07-23T18:00:00",
  "end_time": "2026-07-23T19:05:00",
  "overall_feeling": 4,
  "fatigue_level": 3,
  "comments": "Solid session",
  "exercises": [
    {
      "exercise_name": "Goblet Squat",
      "sets_completed": 3,
      "reps_completed": "10",
      "weight_kg": 20,
      "difficulty": 3,
      "skipped": false,
      "notes": null
    }
  ]
}
```

| Field | Type | Validation |
|-------|------|------------|
| `program_id` | UUID \| null | Optional (backward compatible). If set: must exist and belong to caller; each `exercise_name` must match that program's `program_exercises` |
| `start_time` | datetime | Required |
| `end_time` | datetime \| null | If set, must be ≥ `start_time` |
| `overall_feeling` | int \| null | 1–5 |
| `fatigue_level` | int \| null | 1–5 |
| `comments` | string \| null | — |
| `exercises[].exercise_name` | string | Required per item |
| `exercises[].sets_completed` | int | `ge=0` |
| `exercises[].reps_completed` | string \| null | — |
| `exercises[].weight_kg` | number \| null | `ge=0` |
| `exercises[].difficulty` | int \| null | 1–5 |
| `exercises[].skipped` | bool | default `false` |
| `exercises[].notes` | string \| null | — |

There is **no** exercise UUID / catalog-id field on this payload. Match by `exercise_name`.  
Duplicate identical POSTs create **two** sessions (no idempotency).

`duration_minutes` is computed server-side when `end_time` is present.

### Successful response `201` (`SessionResponse`)
```json
{
  "id": "…",
  "user_id": "…",
  "program_id": "…",
  "start_time": "2026-07-23T18:00:00",
  "end_time": "2026-07-23T19:05:00",
  "duration_minutes": 65,
  "overall_feeling": 4,
  "fatigue_level": 3,
  "comments": "Solid session",
  "created_at": "2026-07-23T19:05:01",
  "exercises": [
    {
      "id": "…",
      "session_id": "…",
      "exercise_name": "Goblet Squat",
      "sets_completed": 3,
      "reps_completed": "10",
      "weight_kg": 20,
      "difficulty": 3,
      "skipped": false,
      "notes": null
    }
  ]
}
```

### Status codes
| Code | Meaning |
|------|---------|
| `201` | Session created |
| `401` | Unauthorized |
| `403` | Program belongs to another user |
| `404` | Program not found |
| `400` | Exercise name not on the program |
| `422` | Invalid UUID / times / field validation |
| `500` | DB failure (rolled back) |

### Ownership / security
`user_id` is always the JWT user. Cross-user `program_id` → `403`.

### curl
```bash
curl -X POST http://localhost:8000/api/sessions \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d "{\"program_id\":\"PROGRAM_UUID\",\"start_time\":\"2026-07-23T18:00:00\",\"end_time\":\"2026-07-23T19:05:00\",\"overall_feeling\":4,\"fatigue_level\":3,\"exercises\":[{\"exercise_name\":\"Goblet Squat\",\"sets_completed\":3,\"reps_completed\":\"10\",\"difficulty\":3}]}"
```

---

## 5. `GET /api/programs/{program_id}`

### Purpose
Fetch one program (with ordered exercises) owned by the authenticated user.

### Authentication
Required.

### Request
Path parameter `program_id` (UUID). No body.

### Successful response `200` (`ProgramResponse`)
Same shape as the `program` object under generate / suggest-next.

### Status codes
| Code | Meaning |
|------|---------|
| `200` | OK |
| `401` | Unauthorized |
| `403` | Program exists but not owned by caller |
| `404` | Program not found |
| `422` | Invalid UUID |

### Ownership / security
Owner-only; other users' programs return `403` (not data).

### curl
```bash
curl http://localhost:8000/api/programs/PROGRAM_UUID \
  -H "Authorization: Bearer YOUR_JWT"
```

---

## 6. `GET /api/me/sessions`

### Purpose
List the authenticated user's sessions (newest `start_time` first), including nested exercises.

### Authentication
Required.

### Request
Query: `limit` (integer, default `50`, min `1`, max `100`). No body.

### Successful response `200` (`SessionResponse[]`)
Array of `SessionResponse` objects (same shape as `POST /api/sessions`).

### Status codes
| Code | Meaning |
|------|---------|
| `200` | OK |
| `401` | Unauthorized |
| `422` | Invalid `limit` |

### Ownership / security
Results are filtered to `Session.user_id ==` JWT user only.

### curl
```bash
curl "http://localhost:8000/api/me/sessions?limit=20" \
  -H "Authorization: Bearer YOUR_JWT"
```

---

## Related implemented endpoints (brief)

These exist but are outside the mobile focus list above:

| Method | Path | Notes |
|--------|------|-------|
| `POST` | `/api/register` | Create user + profile |
| `POST` | `/api/login` | JWT |
| `GET` | `/api/me/profile` | Same response as PATCH |
| `POST` | `/api/programs` | Manual `ProgramCreate` |
| `GET` | `/api/me/programs` | List own programs |
| `GET` | `/api/me/programs/{program_id}/sessions` | Sessions for one owned program |
| `GET` | `/api/sessions/{session_id}` | Owner-only session detail |
| `GET` | `/health` | Liveness (`{"status":"ok"}`) |

No other program/session/profile routes are documented here beyond what exists in the routers.
