#!/usr/bin/env python3
"""Check updatePlugins.xml against the zips it points to.

The IDE refuses or silently skips an entry whose id, version or idea-version differ from the
plugin.xml inside the zip, so run this before every push that touches jetbrains/.
"""
import io
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ok = True
for entry in ET.parse(HERE / "updatePlugins.xml").getroot().findall("plugin"):
    url = entry.get("url", "")
    zip_path = HERE / "dist" / url.rsplit("/", 1)[-1]
    if not url.startswith("https://") or not zip_path.is_file():
        print(f"BAD {entry.get('id')}: url must be https and {zip_path.name} must exist in dist/")
        ok = False
        continue
    with zipfile.ZipFile(zip_path) as z:
        jar = next(n for n in z.namelist() if n.endswith(".jar"))
        with zipfile.ZipFile(io.BytesIO(z.read(jar))) as j:
            plugin = ET.fromstring(j.read("META-INF/plugin.xml"))
    pairs = {
        "id": (entry.get("id"), plugin.findtext("id")),
        "version": (entry.get("version"), plugin.findtext("version")),
        "since-build": (entry.find("idea-version").get("since-build"), plugin.find("idea-version").get("since-build")),
        "until-build": (entry.find("idea-version").get("until-build"), plugin.find("idea-version").get("until-build")),
    }
    for field, (index_value, zip_value) in pairs.items():
        if index_value != zip_value:
            print(f"BAD {entry.get('id')}: {field} is {index_value!r} in the index but {zip_value!r} in {zip_path.name}")
            ok = False
    if ok:
        print(f"OK  {entry.get('id')} {entry.get('version')}")
sys.exit(0 if ok else 1)
