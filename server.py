"""
FawFitt A2A Server
Implements the Agent-to-Agent (A2A) Protocol Specification:
  https://a2a-protocol.org/latest/

Endpoints:
  GET  /.well-known/agent.json  →  Agent Card (discovery)
  POST /                        →  JSON-RPC 2.0 (message/send, tasks/get, tasks/cancel)
  GET  /health                  →  Health check

Skills:
  fitness_plan   →  Groq LLM generates a personalised weekly workout plan
  apple_health   →  Returns mock Apple Health calorie summary (A2A inner payload)
  coach_chat     →  Groq LLM answers fitness/nutrition questions  (default)

Run:
  export GROQ_API_KEY='your_key'
  python3 server.py
"""

import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from groq import Groq

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

GROQ_MODEL = "llama-3.1-8b-instant"
PORT = 8000
BASE_URL = f"http://localhost:{PORT}"
PROTOCOL_VERSION = "0.2.6"

# ---------------------------------------------------------------------------
# Agent Card  (served at /.well-known/agent.json)
# ---------------------------------------------------------------------------

AGENT_CARD: Dict[str, Any] = {
    "name": "FawFitt Agent",
    "description": (
        "AI fitness coaching agent for FawFitt iOS. Generates personalised "
        "workout plans, provides Apple Health calorie summaries, and answers "
        "fitness and nutrition coaching questions."
    ),
    "version": "1.0.0",
    "protocolVersion": PROTOCOL_VERSION,
    "url": BASE_URL,
    "defaultInputModes": ["text/plain"],
    "defaultOutputModes": ["text/plain"],
    "capabilities": {
        "streaming": False,
        "pushNotifications": False,
        "stateTransitionHistory": False,
    },
    "skills": [
        {
            "id": "fitness_plan",
            "name": "Fitness Plan Generator",
            "description": (
                "Generates a personalised weekly workout plan from user profile "
                "(age, goal, fitness level, available equipment)."
            ),
            "tags": ["fitness", "workout", "planning"],
            "examples": [
                "Buat rencana latihan untuk pemula 3 hari seminggu tanpa alat",
                "Create a 4-week fat-loss plan, no equipment",
            ],
            "inputModes": ["text/plain"],
            "outputModes": ["text/plain"],
        },
        {
            "id": "apple_health",
            "name": "Apple Health Calorie Summary",
            "description": (
                "Returns weekly calorie and activity data from Apple Health "
                "as an A2A JSON payload (inner A2A response)."
            ),
            "tags": ["health", "calories", "apple health", "healthkit"],
            "examples": [
                "Get my Apple Health calorie summary",
                "Show this week's activity data",
            ],
            "inputModes": ["text/plain"],
            "outputModes": ["application/json"],
        },
        {
            "id": "coach_chat",
            "name": "AI Fitness Coach",
            "description": (
                "Answers training, recovery, and nutrition questions. "
                "This is the default skill."
            ),
            "tags": ["coaching", "fitness", "nutrition", "recovery", "chat"],
            "examples": [
                "How do I improve my push-up form?",
                "What should I eat after a workout?",
            ],
            "inputModes": ["text/plain"],
            "outputModes": ["text/plain"],
        },
    ],
}

# ---------------------------------------------------------------------------
# Apple Health inner A2A payload  (mirrors crew_test.py)
# ---------------------------------------------------------------------------

APPLE_HEALTH_A2A: Dict[str, Any] = {
    "jsonrpc": "2.0",
    "id": "fawfitt-apple-health-calories-001",
    "result": {
        "agent": {
            "name": "AppleHealthAgent",
            "persona": "Privacy-first Apple Health interpreter for FawFitt calorie signals.",
            "version": "1.0.0",
        },
        "artifact": {
            "type": "health.calorie.sample",
            "unit": "kcal",
            "generatedAt": "2026-05-14T09:00:00Z",
        },
        "calories": {
            "activeEnergyBurned": 684,
            "restingEnergyBurned": 1638,
            "totalBurned": 2322,
            "dailyGoal": 2400,
            "samples": [
                {"date": "2026-05-08", "active": 420, "total": 2060, "score": 68},
                {"date": "2026-05-09", "active": 610, "total": 2245, "score": 72},
                {"date": "2026-05-10", "active": 530, "total": 2168, "score": 70},
                {"date": "2026-05-11", "active": 740, "total": 2384, "score": 78},
                {"date": "2026-05-12", "active": 690, "total": 2320, "score": 81},
                {"date": "2026-05-13", "active": 820, "total": 2466, "score": 86},
                {"date": "2026-05-14", "active": 760, "total": 2415, "score": 88},
            ],
        },
        "summary": (
            "Mock A2A calorie signal: user is 96.8% toward the daily burn goal "
            "with strong active-energy consistency."
        ),
    },
}

# ---------------------------------------------------------------------------
# In-memory Task store
# ---------------------------------------------------------------------------

_tasks: Dict[str, Dict] = {}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_task(context_id: str) -> Dict:
    return {
        "id": str(uuid.uuid4()),
        "contextId": context_id,
        "status": {"state": "submitted", "timestamp": _now()},
        "artifacts": [],
        "history": [],
    }


def _complete(task: Dict, text: str, skill: str) -> Dict:
    task["status"] = {"state": "completed", "timestamp": _now()}
    task["artifacts"] = [
        {
            "artifactId": str(uuid.uuid4()),
            "name": skill,
            "parts": [{"type": "text", "text": text}],
        }
    ]
    return task


def _fail(task: Dict, reason: str) -> Dict:
    task["status"] = {
        "state": "failed",
        "timestamp": _now(),
        "message": {
            "role": "agent",
            "parts": [{"type": "text", "text": reason}],
            "messageId": str(uuid.uuid4()),
        },
    }
    return task

# ---------------------------------------------------------------------------
# Groq helper
# ---------------------------------------------------------------------------

def _groq_complete(system: str, user: str) -> str:
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY is not set on the server")
    client = Groq(api_key=api_key)
    completion = client.chat.completions.create(
        model=GROQ_MODEL,
        temperature=0.4,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )
    return completion.choices[0].message.content or ""

# ---------------------------------------------------------------------------
# Skill handlers
# ---------------------------------------------------------------------------

def _skill_coach_chat(text: str) -> str:
    return _groq_complete(
        system=(
            "You are FawFitt's AI fitness coach. Give short, motivating, actionable advice. "
            "Keep replies concise (2-4 sentences). Never claim to be a doctor. "
            "Respond in the same language the user uses."
        ),
        user=text,
    )


def _skill_fitness_plan(text: str) -> str:
    return _groq_complete(
        system=(
            "You are a practical, clear fitness coach. "
            "Create safe, realistic workout plans. "
            "Always respond in Bahasa Indonesia. "
            "Never claim to be a doctor."
        ),
        user=text,
    )


def _skill_apple_health() -> str:
    return json.dumps(APPLE_HEALTH_A2A, ensure_ascii=False)

# ---------------------------------------------------------------------------
# Skill router
# ---------------------------------------------------------------------------

_SKILL_KEYWORDS: Dict[str, List[str]] = {
    "apple_health": [
        "apple health", "calorie", "kalori", "healthkit",
        "activity data", "aktifitas", "health summary",
    ],
    "fitness_plan": [
        "rencana latihan", "workout plan", "jadwal latihan",
        "program latihan", "fitness plan", "buat latihan",
    ],
}


def _detect_skill(text: str, explicit: Optional[str]) -> str:
    if explicit in {"fitness_plan", "apple_health", "coach_chat"}:
        return explicit  # type: ignore[return-value]
    lower = text.lower()
    for skill, keywords in _SKILL_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            return skill
    return "coach_chat"


def _dispatch(skill: str, text: str) -> str:
    if skill == "apple_health":
        return _skill_apple_health()
    if skill == "fitness_plan":
        return _skill_fitness_plan(text)
    return _skill_coach_chat(text)

# ---------------------------------------------------------------------------
# JSON-RPC method handlers
# ---------------------------------------------------------------------------

def _rpc_error(code: int, message: str, rpc_id: Any = None) -> Dict:
    return {"jsonrpc": "2.0", "id": rpc_id, "error": {"code": code, "message": message}}


def _handle_message_send(params: Dict, rpc_id: Any) -> Dict:
    msg = params.get("message", {})
    parts = msg.get("parts", [])
    user_text = " ".join(
        p.get("text", "") for p in parts if p.get("type") == "text"
    ).strip()
    context_id = msg.get("contextId") or str(uuid.uuid4())

    # Allow explicit skill routing via params.metadata.skill
    explicit_skill: Optional[str] = None
    metadata = params.get("metadata")
    if isinstance(metadata, dict):
        explicit_skill = metadata.get("skill")

    skill = _detect_skill(user_text, explicit_skill)

    task = _new_task(context_id)
    task["status"] = {"state": "working", "timestamp": _now()}
    _tasks[task["id"]] = task

    try:
        result_text = _dispatch(skill, user_text)
    except Exception as exc:
        _fail(task, str(exc))
        _tasks[task["id"]] = task
        return _rpc_error(-32000, str(exc), rpc_id)

    _complete(task, result_text, skill)
    _tasks[task["id"]] = task
    return {"jsonrpc": "2.0", "id": rpc_id, "result": task}


def _handle_tasks_get(params: Dict, rpc_id: Any) -> Dict:
    task_id = params.get("id")
    if not task_id:
        return _rpc_error(-32602, "Missing required param: id", rpc_id)
    task = _tasks.get(task_id)
    if task is None:
        return _rpc_error(-32001, f"Task not found: {task_id}", rpc_id)
    return {"jsonrpc": "2.0", "id": rpc_id, "result": task}


def _handle_tasks_cancel(params: Dict, rpc_id: Any) -> Dict:
    task_id = params.get("id")
    task = _tasks.get(task_id) if task_id else None
    if task is None:
        return _rpc_error(-32001, "Task not found", rpc_id)
    task["status"] = {"state": "canceled", "timestamp": _now()}
    _tasks[task_id] = task
    return {"jsonrpc": "2.0", "id": rpc_id, "result": task}


_RPC_METHODS = {
    "message/send": _handle_message_send,
    "tasks/get": _handle_tasks_get,
    "tasks/cancel": _handle_tasks_cancel,
}

# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------

app = FastAPI(title="FawFitt A2A Server", version="1.0.0", docs_url="/docs")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/.well-known/agent.json", tags=["A2A Discovery"])
def agent_card():
    """A2A Agent Card — discovery endpoint used by A2A clients."""
    return JSONResponse(content=AGENT_CARD)


@app.post("/", tags=["A2A JSON-RPC"])
async def jsonrpc_endpoint(request: Request):
    """A2A JSON-RPC 2.0 endpoint. Accepts message/send, tasks/get, tasks/cancel."""
    try:
        body = await request.json()
    except Exception:
        return JSONResponse(
            status_code=400,
            content=_rpc_error(-32700, "Parse error: request body is not valid JSON"),
        )

    rpc_id = body.get("id")

    if body.get("jsonrpc") != "2.0":
        return JSONResponse(
            content=_rpc_error(-32600, "Invalid Request: jsonrpc must be '2.0'", rpc_id)
        )

    method = body.get("method")
    handler = _RPC_METHODS.get(method)
    if not handler:
        return JSONResponse(
            content=_rpc_error(-32601, f"Method not found: {method}", rpc_id)
        )

    params = body.get("params") or {}
    try:
        result = handler(params, rpc_id)
    except Exception as exc:
        return JSONResponse(content=_rpc_error(-32000, str(exc), rpc_id))

    return JSONResponse(content=result)


@app.get("/health", tags=["Utility"])
def health_check():
    return {
        "status": "ok",
        "service": "FawFitt A2A Server",
        "protocolVersion": PROTOCOL_VERSION,
        "skills": [s["id"] for s in AGENT_CARD["skills"]],
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if not os.environ.get("GROQ_API_KEY"):
        print("ERROR: GROQ_API_KEY belum diset.")
        print("Jalankan: export GROQ_API_KEY='api_key_kamu'")
        raise SystemExit(1)

    print(f"\nFawFitt A2A Server — {BASE_URL}")
    print(f"  Agent Card : {BASE_URL}/.well-known/agent.json")
    print(f"  JSON-RPC   : POST {BASE_URL}/")
    print(f"  Swagger UI : {BASE_URL}/docs\n")
    uvicorn.run("server:app", host="0.0.0.0", port=PORT, reload=True)
