# tooler

Checks the latest versions of tools (GitHub releases) and VS Code extensions listed in a config file and writes an HTML overview with the installed version, the latest version (highlighted when it differs) and a download link. Runs once and exits, e.g. as a Kubernetes CronJob; serve `/output/index.html` with any web server.

## Usage

```bash
mkdir -p out && chmod 777 out
docker run --rm --read-only \
  -v "$PWD/config.yaml:/config/config.yaml:ro" -v "$PWD/out:/output" \
  ghcr.io/tuxpeople/tooler:latest
```

### config.yaml

```yaml
settings:
  colors:
    update_true: "table-danger"   # CSS class when a newer version exists
    update_false: ""
github:
  - name: "k9s"
    gh_repo: "derailed/k9s"
    version: "v0.32.5"            # installed version
    filter: "k9s_Windows_amd64.zip$"   # regex for the asset; {{VERSION}}, {{ORG}}, {{REPO}} are replaced
vscode:
  - name: "YAML"
    version: "0.0.0"
    extension: redhat.vscode-yaml
```

| Variable | Default | Description |
|---|---|---|
| `CONFIGFILE` | `/config/config.yaml` | Config file |
| `OUTPUTFILE` | `/output/index.html` | Output file (mount a writable volume) |
| `TEMPLATEDIR` | `/defaults` | `header.html` and `footer.html` |

## Image

- Alpine with curl, jq and yq, runs as UID 1000 (any UID works), read-only root filesystem
- Tags: `X.Y.Z`, `X.Y`, `X`, `latest`; Cosign-signed with signed provenance and SBOM
- Releases with release-please; base image updates are released automatically

## Testing

`tests.yml` runs ShellCheck, Hadolint, a smoke test against `tests/config.yaml` (needs access to GitHub and the VS Code marketplace) and a Trivy scan.

```bash
docker build -t tooler:test .
docker run --rm -v "$PWD/tests/config.yaml:/config/config.yaml:ro" -v "$PWD/out:/output" tooler:test
```

## History

Until 2026-11 tooler was built in [tuxpeople/containers](https://github.com/tuxpeople/containers) on `ghcr.io/tuxpeople/baseimage-alpine-light` (tags `git-<sha>`). Since its own repository: plain Alpine base, ShellCheck-clean POSIX script, all values are HTML-escaped before they go into the page, and the script fails clearly on a missing config.
