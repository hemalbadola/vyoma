import os
import re

def fix_with_opacity(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace .withOpacity(x) with .withAlpha((x * 255).toInt()) or similar.
    # Actually wait. Flutter 3.27+ recommends .withValues(alpha: x)
    
    # Regex to find .withOpacity(val)
    # Be careful with multiline or complex expressions.
    # Simple replace:
    
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
    
    if new_content != content:
        with open(filepath, 'w') as f:
             f.write(new_content)
        print(f"Fixed {filepath}")

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                fix_with_opacity(os.path.join(root, file))

if __name__ == "__main__":
    process_directory('lib')
    process_directory('test')
