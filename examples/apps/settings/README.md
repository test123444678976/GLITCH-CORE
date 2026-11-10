# GLITCH//CORE Settings — developer preview

This is the first graphical application prototype for GLITCH//CORE. It uses
GTK 3 through PyGObject and is intended for the future MATE desktop session.

## Run

On a development machine with Python 3, GTK 3 and PyGObject installed:

```bash
python3 main.py
```

From the repository root, validate and package it with the initial SDK:

```bash
python3 scripts/glitch-sdk/glitch.py validate examples/apps/settings
python3 scripts/glitch-sdk/glitch.py pack examples/apps/settings --output /tmp/glitch-settings.gcpkg
python3 scripts/glitch-sdk/glitch.py inspect /tmp/glitch-settings.gcpkg
```

## Current limitations

- Requires GTK 3 and PyGObject; these are not bundled in the current rescue ISO.
- Appearance controls only alter this application's preview window.
- System information is project metadata, not live hardware inspection.
- Settings are not persisted and do not modify system-wide configuration.
- This is a prototype, not yet installed into a GLITCH//CORE image.
