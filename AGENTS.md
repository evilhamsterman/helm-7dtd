# AGENTS.md

Instructions and context for AI coding agents working in the `helm-7dtd` repository.

## Repository Overview

`helm-7dtd` is a Helm chart repository for running dedicated 7 Days to Die servers on Kubernetes.
- **Upstream Image**: `vinanrra/7dtd-server` ([vinanrra/Docker-7DaysToDie](https://github.com/vinanrra/Docker-7DaysToDie))
- **Distribution**: Published as an OCI package to GitHub Container Registry at `oci://ghcr.io/evilhamsterman/helm-7dtd`.
- **Target Environments**: Kubernetes clusters (homelab & enterprise), frequently managed via Flux GitOps.

## Chart Architecture & Templates

- **`chart/templates/statefulset.yaml`**: Deploys the server as a single-replica `StatefulSet` with `RollingUpdate` strategy to guarantee single-pod access to RWO storage and stable network identity. Includes an `initContainer` (`generate-sdtdserver-xml`) reusing the main server image to render `/home/sdtdserver/serverfiles/sdtdserver.xml` from `.Values.serverConfig` and inject passwords from Kubernetes Secrets.
- **`chart/templates/secret.yaml`**: Creates an `Opaque` `Secret` (`{{ .Release.Name }}-serverconfig`) when `ServerPassword` or `TelnetPassword` are provided directly in `.Values.serverConfig` rather than via `*PasswordSecret` references.
- **`chart/templates/_helpers.tpl`**: Template helper (`helm-7dtd.xmlEscape`) for escaping XML attribute values.
- **`chart/templates/persistentvolumeclaim.yaml`**: Creates PersistentVolumeClaims for:
  - World data & saves: `/home/sdtdserver/.local/share/7DaysToDie` (`{{ .Release.Name }}-world-data`, minimum 12 GiB free space required by upstream `check_space.sh`)
  - Server installation & config (`sdtdserver.xml`, `Mods/`): `/home/sdtdserver/serverfiles` (`{{ .Release.Name }}-server-base-data`)
  - LinuxGSM configuration: `/home/sdtdserver/lgsm/config-lgsm/sdtdserver` (`{{ .Release.Name }}-lgsm-config`)
  - Backups: `/home/sdtdserver/lgsm/backup` (`{{ .Release.Name }}-backup-data`)
  - All PVCs support `.existingClaim` to bind pre-existing volumes and bypass manifest creation.
- **`chart/templates/service.yaml`**: Exposes TCP/UDP `gamePort` (default 26900), UDP `gamePort + 1` (26901), UDP `gamePort + 2` (26902), and optional TCP ports for `webadmin` (8080), `telnet` (8081), and Alloc Fixes `webserver` (8082).
- **`chart/values.yaml`**: Chart configuration defaults. Storage defaults to `persistentVolumeClaim` with `hostvol` and `emptyDir` alternatives.

## Backup Management

Backups are powered by the upstream container's cron backup script (`server_backup.sh`):
- Built-in options in `values.yaml` under `backups:` map directly to container environment variables (`BACKUP`, `BACKUP_HOUR`, `BACKUP_MAX`).
- Dedicated backup volume mounts over `/home/sdtdserver/lgsm/backup` configured via `backups.storage`. Setting `backups.enabled: true` enables both the container backup engine and backup storage, requiring valid `backups.storage` configuration.
- Because `server_backup.sh` temporarily stops `sdtdserver` while creating `.tar.gz` archives, `livenessProbe` is left empty by default so backups do not trigger container restarts.

## Local Verification & Testing

A `Taskfile.yml` is provided for common development workflows (run via `task` or `go-task`):

```bash
# Lint the chart
task lint

# Render templates locally
task template

# Package the chart for OCI release
task build

# Publish and tag OCI release
task publish
task tag TAG=latest

# Deploy or upgrade directly from local repo
task deploy -- --values my-values.yaml

# Check status or clean build artifacts
task status
task clean
```

## CI/CD Workflows

- **CI Test (`.github/workflows/ci.yml`)**: Runs on `push` and `pull_request` to `main` touching chart files, Taskfile, or version. Executes `task lint`, `task build` (test packaging), and `task template`.
- **Release (`.github/workflows/deploy-chart.yml`)**: Runs on published GitHub releases (and manual `workflow_dispatch`). Packages the chart, pushes the OCI artifact to `oci://ghcr.io/${OWNER}`, tags `:latest` in GHCR via `crane`, and updates the floating git tag `latest`.
- Version number is tracked in both `version` and `chart/Chart.yaml` (keep both in sync).
