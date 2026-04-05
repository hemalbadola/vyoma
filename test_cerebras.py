import os
import requests
import json

api_key = os.getenv('VYOMA_CEREBRAS_API_KEY', '').strip()
if not api_key:
    raise SystemExit('Missing VYOMA_CEREBRAS_API_KEY environment variable.')

url = "https://api.cerebras.ai/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}
data = {
    "model": "llama3.1-8b",
    "messages": [{"role": "user", "content": "Why is fast inference important? Answer in one sentence."}],
    "max_completion_tokens": 100
}

try:
    response = requests.post(url, headers=headers, json=data)
    print(f"Status: {response.status_code}")
    print(response.json())
except Exception as e:
    print(f"Error: {e}")
