import subprocess
from bs4 import BeautifulSoup

# Load XML file
with open("FFXI+Wiki-20250521034029.xml", "r", encoding="utf-8") as file:
    xml_content = file.read()

# Parse XML
soup = BeautifulSoup(xml_content, "xml")

# Convert wiki markup to plain text using Pandoc
def convert_wiki_to_plain(wiki_text):
    try:
        result = subprocess.run(
            ["pandoc", "--from=mediawiki", "--to=plain"],
            input=wiki_text.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10
        )
        output = result.stdout.decode("utf-8").strip()
        # Replace [[ and ]] with single chars (example: « and »)
        output = output.replace("[[", "[").replace("]]", "]").replace("\"", "\\\"")
        return output
    except Exception as e:
        return f"[ERROR: {e}]"

# Extract pages and convert text
entries = []
for page in soup.find_all("page"):
    title = page.find("title").text.strip().replace("\"", "\\\"")
    text_tag = page.find("text")
    if text_tag and text_tag.text.strip():
        plain_text = convert_wiki_to_plain(text_tag.text)
        if plain_text:
            entries.append({
                "title": title,
                "walkthrough": plain_text
            })

# Format as Lua table
lua_entries = [
    f'  {{ title = "{entry["title"]}", walkthrough = [[{entry["walkthrough"]}]] }}'
    for entry in entries
]
lua_content = "return {\n" + ",\n".join(lua_entries) + "\n}"

# Write to .lua file
with open("ffxi_walkthroughs.lua", "w", encoding="utf-8") as f:
    f.write(lua_content)
