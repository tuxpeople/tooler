# CLAUDE.md

tooler writes an HTML overview of tool versions (`root/app/tooler.sh`, POSIX sh), packaged as an Alpine image. The pipeline follows [tuxpeople/template-python-app](https://github.com/tuxpeople/template-python-app).

## Commands

```bash
docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:v0.11.0 -s sh /mnt/root/app/tooler.sh
docker build -t tooler:test .
docker run --rm -v "$PWD/tests/config.yaml:/config/config.yaml:ro" -v "$PWD/out:/output" tooler:test
```

## Rules

- **POSIX sh** (Alpine/busybox), ShellCheck-clean; no bashisms.
- **Security first:** everything from the config or from remote pages goes through `html_escape` before it is written into the HTML page.
- **Image:** runs as UID 1000 (any UID works), read-only root filesystem; `/output` must be a writable volume.
- **Commits:** Conventional Commits; they drive release-please (`feat` → minor, `fix` → patch, `!` → major, `deps` → patch). Use `chore`/`ci`/`docs` for changes that should not produce a release.
- **release-as** in `release-please-config.json` is only for the first release; remove it afterwards.
- **Actions** are pinned by commit SHA (`@<sha> # vX.Y.Z`); Renovate keeps them up to date.
