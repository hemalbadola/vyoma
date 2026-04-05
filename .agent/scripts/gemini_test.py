import base64
import json
import urllib.request
import urllib.error
import sys

image_path = "/Users/hemalbadola/Documents/Vyoma/Screenshot 2026-03-15 at 2.40.44 PM.png"
api_key = "AIzaSyC90-9zVuIpfPa9dC7vtlpJOj7s5nf6qGo"
url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"

try:
    with open(image_path, "rb") as image_file:
        base64_image = base64.b64encode(image_file.read()).decode("utf-8")
except Exception as e:
    print(f"Error reading image: {e}")
    sys.exit(1)

payload = {
    "contents": [
        {
            "parts": [
                {"text": "Extract all the schedule blocks including day, time, subject, and venue from this timetable. Output as JSON."},
                {
                    "inlineData": {
                        "mimeType": "image/png",
                        "data": base64_image
                    }
                }
            ]
        }
    ]
}

data = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})

try:
    response = urllib.request.urlopen(req)
    result = response.read().decode("utf-8")
    parsed = json.loads(result)
    print(parsed["candidates"][0]["content"]["parts"][0]["text"])
except urllib.error.HTTPError as e:
    print(f"HTTPError: {e.code} - {e.read().decode('utf-8')}")
except Exception as e:
    print(f"Error: {e}")
