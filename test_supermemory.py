#!/usr/bin/env python3
"""Quick Supermemory connectivity and recall smoke test.

Usage:
  export VYOMA_SUPERMEMORY_API_KEY=...
  python3 test_supermemory.py
"""

import os
import sys
import json
import re
from pathlib import Path
import requests

BASE_URL = "https://api.supermemory.ai/v3"
PROJECT = os.getenv("VYOMA_SUPERMEMORY_PROJECT", "vyoma").strip()


def _decode(encoded, seed):
    out = []
    for i, b in enumerate(encoded):
        out.append(b ^ ((seed + i * 29 + (i >> 1)) & 0xFF))
    return bytes(out).decode("utf-8", errors="ignore")


def _load_fallback_key_from_secrets():
    secrets_path = Path(__file__).parent / "lib" / "core" / "secrets.dart"
    if not secrets_path.exists():
        return ""

    text = secrets_path.read_text(encoding="utf-8")

    seed_match = re.search(r"_supermemorySeed\s*=\s*(\d+)\s*;", text)
    data_match = re.search(r"_supermemoryData\s*=\s*\[(.*?)\]\s*;", text, re.S)
    if not seed_match or not data_match:
        return ""

    seed = int(seed_match.group(1))
    encoded = [int(n) for n in re.findall(r"\d+", data_match.group(1))]
    if not encoded:
        return ""

    return _decode(encoded, seed).strip()


API_KEY = os.getenv("VYOMA_SUPERMEMORY_API_KEY", "").strip() or _load_fallback_key_from_secrets()

if not API_KEY:
    raise SystemExit("Missing Supermemory API key (env and fallback decode both empty)")

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}
if PROJECT:
    headers["x-sm-project"] = PROJECT


def post(path, payload):
    url = f"{BASE_URL}{path}"
    r = requests.post(url, headers=headers, json=payload, timeout=10)
    return r


def get(path):
    url = f"{BASE_URL}{path}"
    r = requests.get(url, headers=headers, timeout=10)
    return r


def main():
    print("1) Health check")
    health = get("/health")
    print(f"   status={health.status_code}")

    print("2) Save memory")
    content = "Behavior pattern probe: user tends to delay hard tasks till evening and recovers with 20-minute sprint."
    save = post("/documents", {
        "content": content,
        "type": "note",
        "tags": ["probe", "behavior_pattern"],
    })
    print(f"   status={save.status_code}")
    if save.status_code not in (200, 201):
      print(save.text[:300])
      sys.exit(1)

    print("3) Semantic recall")
    recall = post("/search", {
        "q": "delay hard tasks evening sprint",
        "limit": 3,
    })
    print(f"   status={recall.status_code}")
    if recall.status_code != 200:
      print(recall.text[:300])
      sys.exit(1)

    data = recall.json()
    results = data.get("results") or data.get("data") or []
    print(f"   results={len(results)}")
    if results:
        top = results[0]
        snippet = (top.get("content") or top.get("text") or "")[:120]
        score = top.get("score", top.get("similarity", "n/a"))
        print(f"   top_score={score}")
        print(f"   top_snippet={snippet}")

    print("4) Profile (optional endpoint)")
    profile = get("/profile")
    print(f"   status={profile.status_code}")
    if profile.status_code == 200:
        try:
            p = profile.json()
            print(f"   summary={str(p.get('summary', ''))[:140]}")
        except Exception:
            print("   profile not JSON")

    print("Done.")


if __name__ == "__main__":
    main()
