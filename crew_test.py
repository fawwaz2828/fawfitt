import os
import json

from crewai import Agent, Crew, LLM, Process, Task


APPLE_HEALTH_AGENT_A2A_RESPONSE = {
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
        "summary": "Mock A2A calorie signal: user is 96.8% toward the daily burn goal with strong active-energy consistency.",
    },
}


def required_env(name):
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(
            f"{name} belum diset. Jalankan: export {name}='api_key_kamu'"
        )
    return value


def ask(label, default):
    answer = input(f"{label} [{default}]: ").strip()
    return answer or default


required_env("GROQ_API_KEY")

print("\nIsi profil singkat untuk rencana fitness.\nTekan Enter untuk pakai nilai default.\n")

profile = {
    "umur": ask("Umur", "25"),
    "tujuan": ask("Tujuan", "turun berat badan dan lebih bugar"),
    "level": ask("Level", "pemula"),
    "alat": ask("Alat yang tersedia", "tanpa alat"),
    "hari": ask("Jumlah hari latihan per minggu", "3"),
    "durasi": ask("Durasi per sesi", "30 menit"),
    "catatan": ask("Catatan cedera/batasan", "tidak ada"),
}


llm = LLM(
    model="groq/llama-3.1-8b-instant",
    temperature=0.4,
)

agent = Agent(
    role="Fitness Coach",
    goal="Membuat rencana latihan yang personal, aman, dan mudah dijalankan",
    backstory=(
        "Kamu adalah pelatih fitness yang praktis, jelas, dan mudah dipahami. "
        "Kamu memberi arahan yang aman untuk pemula dan tidak mengklaim sebagai dokter."
    ),
    llm=llm,
    verbose=True,
)

apple_health_agent = Agent(
    role="AppleHealthAgent",
    goal="Generate privacy-preserving Apple Health calorie summaries as A2A JSON for the iOS app",
    backstory=(
        "You are an Apple Health specialist agent for FawFitt. You never expose raw private "
        "HealthKit records; you summarize mock calorie signals into a compact A2A-style JSON "
        "artifact that SwiftUI can decode deterministically."
    ),
    llm=llm,
    verbose=True,
)

task = Task(
    description=f"""
Buat rencana latihan berdasarkan profil berikut:
- Umur: {profile["umur"]}
- Tujuan: {profile["tujuan"]}
- Level: {profile["level"]}
- Alat: {profile["alat"]}
- Jumlah hari latihan per minggu: {profile["hari"]}
- Durasi per sesi: {profile["durasi"]}
- Catatan cedera/batasan: {profile["catatan"]}

Berikan program yang realistis, aman, dan bisa dilakukan di rumah.
Jika ada catatan cedera/batasan, beri saran untuk konsultasi profesional dan hindari gerakan berisiko.
""",
    expected_output=(
        "Jawaban dalam bahasa Indonesia berisi: ringkasan tujuan, jadwal latihan mingguan, "
        "detail setiap hari latihan, pemanasan, pendinginan, progres 4 minggu, dan tips keamanan."
    ),
    agent=agent,
)

apple_health_task = Task(
    description=f"""
Return this exact mock A2A JSON response for sample Apple Health calorie data.
Do not add markdown, commentary, or extra keys.

{json.dumps(APPLE_HEALTH_AGENT_A2A_RESPONSE, indent=2)}
""",
    expected_output="A valid JSON object matching the provided A2A calorie response exactly.",
    agent=apple_health_agent,
)

crew = Crew(
    agents=[agent, apple_health_agent],
    tasks=[task, apple_health_task],
    process=Process.sequential,
    verbose=True,
)

result = crew.kickoff()
print("\n=== Rencana Fitness ===\n")
print(result)

print("\n=== AppleHealthAgent Mock A2A JSON ===\n")
print(json.dumps(APPLE_HEALTH_AGENT_A2A_RESPONSE, indent=2))
