import re
with open('backend/src/index.ts', 'r') as f:
    text = f.read()

target = """// Initialize Firebase Admin (uses default credentials locally or via Heroku Env)
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});"""

replacement = """// Initialize Firebase Admin (uses explicit projectId for verifyIdToken)
admin.initializeApp({
  projectId: 'vyoma-in'
});"""

text = text.replace(target, replacement)

with open('backend/src/index.ts', 'w') as f:
    f.write(text)
