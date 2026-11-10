# Web page wrapper

`play.html` loads a Godot web export inside a claude.ai artifact. The export's engine is stored
gzipped and base64-encoded (`index.wasm.gz.b64.txt`, `index.pck.b64.txt`) because artifacts only
serve standard web file types up to 15 MB; the page decodes them when Godot asks for them.
The exported files themselves are not kept in the repository; re-export to regenerate them.
