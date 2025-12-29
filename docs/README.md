# Documentation

User-facing documentation can be published via GitHub Pages (if configured):

- https://averrik.github.io/dbAudit/docs/

## Chapters

- `docs/install.md`: install entrypoint (choose OS)
- `docs/macos.md`: macOS/Linux install details
- `docs/windows.md`: Windows install details
- `docs/quickstart.md`: run a project
- `docs/project-layout.md`: expected project folder structure
- `docs/troubleshooting.md`: common installation/runtime issues
- `docs/logging.md`: log schema, filters, and event reference
- `docs/parsers.md`: parser behavior (type A + type B)
- `docs/audit.md`: audit behavior (structure + values; type-B method inference)

## Quick commands

- Install:
  - macOS/Linux: `sudo bash install/install-mac.sh`
  - Windows (Git Bash): `bash install/install-win.sh`

- Run a project:
  - `dbAudit --project project/<PROJECT>/data`
