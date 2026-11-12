# helm-7dtd

Kubernetes Helm chart for deploying a dedicated [7 Days to Die](https://7daystodie.com/) game server. Based on the container image [`vinanrra/7dtd-server`](https://github.com/vinanrra/Docker-7DaysToDie).

## Features

- **StatefulSet Architecture**: Deploys as a single-replica `StatefulSet` with rolling updates to avoid volume multi-attach contention on node failovers.
- **K8s-Native Persistence**: Defaults to `PersistentVolumeClaim` (PVC) for world saves, server files, LinuxGSM config, and dedicated backup storage, with support for pre-existing claims (`existingClaim`) and `hostvol` paths.
- **Structured Environment & Mod Configuration**: Clean YAML sections for LinuxGSM server settings, overhaul mods (Undead Legacy, Darkness Falls), Alloc's Server Fixes, BepInEx, and custom mod URLs.
- **Startup & Readiness Probes**: Built-in `startupProbe` allows up to 30 minutes for initial SteamCMD download (~12 GB) and RWG world generation, while `readinessProbe` verifies the game TCP listener (`26900`).
- **Flexible Networking**: Supports `LoadBalancer` (with `loadBalancerClass`, static IP, and `externalTrafficPolicy`), `NodePort`, and `hostNetwork`, with opt-in toggles for WebAdmin (`8080`), Telnet (`8081`), and Alloc Fixes Web Map (`8082`).
- **OCI Distribution**: Packaged and published directly to GitHub Container Registry (GHCR) as an OCI artifact.

## Installation

### Helm CLI (OCI)

```bash
helm install 7dtd-server oci://ghcr.io/evilhamsterman/helm-7dtd \
  --version 1.1.0 \
  --set server.timeZone="America/Los_Angeles"
```

### GitOps with Flux

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: evilhamsterman-charts
  namespace: flux-system
spec:
  type: oci
  interval: 1h
  url: oci://ghcr.io/evilhamsterman
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: 7dtd-server
  namespace: games
spec:
  interval: 1h
  chart:
    spec:
      chart: helm-7dtd
      version: "1.1.0"
      sourceRef:
        kind: HelmRepository
        name: evilhamsterman-charts
        namespace: flux-system
  values:
    server:
      timeZone: "America/Los_Angeles"
    networking:
      serviceType: LoadBalancer
      loadBalancerClass: "tailscale"
```

## Configuration

### Image & Server Settings

| Parameter | Description | Default |
|:---|:---|:---|
| `image.repository` | Container image repository | `vinanrra/7dtd-server` |
| `image.tag` | Container image tag | `v0.10.0` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `server.startMode` | Container start mode (`1` start, `3` update & start) | `1` |
| `server.version` | 7 Days to Die Steam branch (`stable`, `latest_experimental`, etc.) | `stable` |
| `server.timeZone` | Container timezone | `America/New_York` |
| `server.puid` | Process user ID for volume ownership | `1000` |
| `server.pgid` | Process group ID for volume ownership | `1000` |
| `server.changeConfigDirOwnership` | Run `chown` on `/home/sdtdserver` at startup | `true` |
| `server.linuxgsmVersion` | Override bundled LinuxGSM tag/branch if non-empty | `""` |
| `server.monitor` | Enable LinuxGSM 5-minute crash monitor cron | `true` |
| `server.testAlert` | Send LinuxGSM test alert on server startup | `false` |

### Server Configuration (`sdtdserver.xml`)

`serverConfig` renders `/home/sdtdserver/serverfiles/sdtdserver.xml` via an `initContainer`. See the [7 Days to Die Dedicated Server Wiki](https://developer.valvesoftware.com/wiki/7_Days_to_Die_Dedicated_Server) for property details.

- **Inherited Defaults**: `ServerName` defaults to `.Release.Name`. `ServerPort`, `WebDashboardEnabled`, `WebDashboardPort`, `TelnetEnabled`, and `TelnetPort` default to the corresponding `networking.*` values. Overriding a port in `serverConfig` updates `sdtdserver.xml` and the pod `containerPort`, while `Service` ports remain driven by `networking.*`.
- **Passwords**: Set `ServerPassword` / `TelnetPassword` directly in values (chart creates a `{{ .Release.Name }}-serverconfig` `Secret`) or reference an existing `Secret` via `ServerPasswordSecret` / `TelnetPasswordSecret` (`name` and `key`).

| Section | Properties |
|:---|:---|
| `serverConfig.serverRepresentation` | `ServerName`, `ServerDescription`, `ServerWebsiteURL`, `ServerPassword`, `ServerPasswordSecret.{name,key}`, `ServerLoginConfirmationText`, `Region`, `Language` |
| `serverConfig.networking` | `ServerPort`, `ServerVisibility`, `ServerDisabledNetworkProtocols`, `ServerMaxWorldTransferSpeedKiBs` |
| `serverConfig.slots` | `ServerMaxPlayerCount`, `ServerReservedSlots`, `ServerReservedSlotsPermission`, `ServerAdminSlots`, `ServerAdminSlotsPermission` |
| `serverConfig.adminInterfaces` | `WebDashboardEnabled`, `WebDashboardPort`, `WebDashboardUrl`, `EnableMapRendering`, `TelnetEnabled`, `TelnetPort`, `TelnetPassword`, `TelnetPasswordSecret.{name,key}`, `TelnetFailedLoginLimit`, `TelnetFailedLoginsBlocktime`, `TerminalWindowEnabled` |
| `serverConfig.folderAndFileLocations` | `AdminFileName`, `UserDataFolder` |
| `serverConfig.otherTechnicalSettings` | `ServerAllowCrossplay`, `EACEnabled`, `IgnoreEOSSanctions`, `HideCommandExecutionLog`, `MaxUncoveredMapChunksPerPlayer`, `PersistentPlayerProfiles`, `MaxChunkAge`, `SaveDataLimit` |
| `serverConfig.world` | `GameWorld`, `WorldGenSeed`, `WorldGenSize`, `GameName`, `GameMode` |
| `serverConfig.difficulty` | `PlayerSafeZoneLevel`, `PlayerSafeZoneHours` |
| `serverConfig.gameRules` | `BuildCreate`, `BedrollDeadZoneSize`, `BedrollExpiryTime`, `AllowSpawnNearFriend`, `CameraRestrictionMode` |
| `serverConfig.performanceRelated` | `MaxSpawnedZombies`, `MaxSpawnedAnimals`, `ServerMaxAllowedViewDistance`, `MaxQueuedMeshLayers` |
| `serverConfig.multiplayer` | `PartySharedKillRange`, `PlayerKillingMode` |
| `serverConfig.landClaimOptions` | `LandClaimCount`, `LandClaimSize`, `LandClaimDeadZone`, `LandClaimExpiryTime`, `LandClaimDecayMode`, `LandClaimOnlineDurabilityModifier`, `LandClaimOfflineDurabilityModifier`, `LandClaimOfflineDelay`, `DynamicMeshEnabled`, `DynamicMeshLandClaimOnly`, `DynamicMeshLandClaimBuffer`, `DynamicMeshMaxItemCache`, `TwitchServerPermission`, `TwitchBloodMoonAllowed`, `SandboxCode` |

### Mods

| Parameter | Description | Default |
|:---|:---|:---|
| `mods.updateMods` | Master switch to allow mod updates on startup (`UPDATE_MODS`) | `false` |
| `mods.urls` | List of `.zip`/`.rar` mod URLs to auto-download (`MODS_URLS`) | `[]` |
| `mods.allocFixes.enabled` | Install Alloc's Server Fixes (`ALLOC_FIXES`) | `true` |
| `mods.allocFixes.update` | Update Alloc's Server Fixes on start (`ALLOC_FIXES_UPDATE`) | `true` |
| `mods.undeadLegacy.enabled` | Install Undead Legacy overhaul mod (`UNDEAD_LEGACY`) | `false` |
| `mods.undeadLegacy.version` | Undead Legacy branch (`stable` or `exp`) | `stable` |
| `mods.undeadLegacy.update` | Update Undead Legacy on start (`UNDEAD_LEGACY_UPDATE`) | `false` |
| `mods.undeadLegacy.url` | Custom Undead Legacy archive URL (`UNDEAD_LEGACY_URL`) | `""` |
| `mods.darknessFalls.enabled` | Install Darkness Falls overhaul mod (`DARKNESS_FALLS`) | `false` |
| `mods.darknessFalls.update` | Update Darkness Falls on start (`DARKNESS_FALLS_UPDATE`) | `false` |
| `mods.darknessFalls.url` | Custom Darkness Falls git URL (`DARKNESS_FALLS_URL`) | `""` |
| `mods.bepinex.enabled` | Install BepInEx plugin framework (`BEPINEX`) | `false` |
| `mods.bepinex.update` | Update BepInEx on start (`BEPINEX_UPDATE`) | `false` |

### Storage

Persistence is split across primary volumes and a dedicated backup volume managed under `backups.storage`:

1. **`storage.data`**: World saves, generated maps, and player profiles (mounted to `/home/sdtdserver/.local/share/7DaysToDie`). Upstream `check_space.sh` requires at least 12 GiB of available free space on this mount during initial install.
2. **`storage.server`**: Server binaries, `sdtdserver.xml`, and `Mods/` (mounted to `/home/sdtdserver/serverfiles`).
3. **`storage.lgsmConfig`**: LinuxGSM instance configuration (mounted to `/home/sdtdserver/lgsm/config-lgsm/sdtdserver`).

| Parameter | Description | Default |
|:---|:---|:---|
| `storage.data.kind` | Storage type: `persistentVolumeClaim`, `hostvol`, or `emptyDir` | `persistentVolumeClaim` |
| `storage.data.pvc.size` | Size requested for world data PVC (must leave >= 12 GiB free) | `15Gi` |
| `storage.data.pvc.storageClassName` | StorageClass name (uses default if empty) | `""` |
| `storage.data.pvc.existingClaim` | Name of pre-existing PVC to bind | `""` |
| `storage.data.hostvol.path` | Host path when `kind: hostvol` | `/data/7dtd-data` |
| `storage.server.kind` | Storage type: `persistentVolumeClaim`, `hostvol`, or `emptyDir` | `persistentVolumeClaim` |
| `storage.server.pvc.size` | Size requested for server binary PVC | `20Gi` |
| `storage.server.pvc.storageClassName` | StorageClass name (uses default if empty) | `""` |
| `storage.server.pvc.existingClaim` | Name of pre-existing PVC to bind | `""` |
| `storage.server.hostvol.path` | Host path when `kind: hostvol` | `/data/7dtd-server` |
| `storage.lgsmConfig.kind` | Storage type: `persistentVolumeClaim`, `hostvol`, or `emptyDir` | `persistentVolumeClaim` |
| `storage.lgsmConfig.pvc.size` | Size requested for LinuxGSM config PVC | `1Gi` |
| `storage.lgsmConfig.pvc.storageClassName` | StorageClass name (uses default if empty) | `""` |
| `storage.lgsmConfig.pvc.existingClaim` | Name of pre-existing PVC to bind | `""` |
| `storage.lgsmConfig.hostvol.path` | Host path when `kind: hostvol` | `/data/7dtd-lgsm-config` |

### Backups

When `backups.enabled: true`, backup storage under `backups.storage` is mounted to `/home/sdtdserver/lgsm/backup`:

| Parameter | Description | Default |
|:---|:---|:---|
| `backups.enabled` | Enable daily cron backups and dedicated backup storage (`BACKUP`) | `true` |
| `backups.hour` | Hour of day (`0`-`23`) to run backup (`BACKUP_HOUR`) | `5` |
| `backups.max` | Retention in days before pruning old `.tar.gz` archives (`BACKUP_MAX`) | `7` |
| `backups.storage.kind` | Storage type: `persistentVolumeClaim`, `hostvol`, or `emptyDir` | `persistentVolumeClaim` |
| `backups.storage.pvc.size` | Size requested for backup volume | `10Gi` |
| `backups.storage.pvc.storageClassName` | StorageClass name (uses default if empty) | `""` |
| `backups.storage.pvc.existingClaim` | Name of pre-existing PVC to bind | `""` |
| `backups.storage.hostvol.path` | Host path when `kind: hostvol` | `/data/7dtd-backups` |

### Networking

| Parameter | Description | Default |
|:---|:---|:---|
| `useHostNetworking` | Run pod on host network namespace (bypasses Service) | `false` |
| `networking.serviceType` | Service type (`LoadBalancer`, `NodePort`, `ClusterIP`) | `LoadBalancer` |
| `networking.loadBalancerClass` | Optional LoadBalancer class implementation | `""` |
| `networking.loadBalancerIP` | Static IP for LoadBalancer | `""` |
| `networking.loadBalancerSourceRanges` | Allowed CIDR ranges for LoadBalancer | `[]` |
| `networking.externalTrafficPolicy` | External traffic policy (`Local` or `Cluster`) | `""` |
| `networking.gamePort` | Base game port (exposes TCP/UDP `gamePort`, UDP `gamePort+1`, UDP `gamePort+2`) | `26900` |
| `networking.nodePort` | Fixed base port when using `serviceType: NodePort` | `nil` |
| `networking.webadmin.enabled` | Expose WebAdmin TCP port | `false` |
| `networking.webadmin.port` | WebAdmin TCP port | `8080` |
| `networking.telnet.enabled` | Expose Telnet TCP port | `false` |
| `networking.telnet.port` | Telnet TCP port | `8081` |
| `networking.webserver.enabled` | Expose Alloc Fixes Web Map TCP port | `false` |
| `networking.webserver.port` | Alloc Fixes Web Map TCP port | `8082` |
| `networking.serviceAnnotations` | Annotations for the Service | `{}` |
| `networking.serviceLabels` | Labels for the Service | `{}` |

### Pod Scheduling & Resources

| Parameter | Description | Default |
|:---|:---|:---|
| `resources` | Pod resource requests and limits | `{}` |
| `nodeSelector` | Node selector labels | `{}` |
| `tolerations` | Pod toleration rules | `[]` |
| `affinity` | Pod affinity rules | `{}` |
| `securityContext` | Pod security context | `{}` |
| `priorityClassName` | Priority class name | `""` |
| `podLabels` | Additional labels for pod | `{}` |
| `podAnnotations` | Additional annotations for pod | `{}` |
| `readinessProbe` | Readiness probe configuration (checks `gameport-tcp`) | `tcpSocket (gameport-tcp)` |
| `startupProbe` | Startup probe to accommodate initial Steam download & RWG | `tcpSocket (gameport-tcp)` |
| `livenessProbe` | Liveness probe configuration | `{}` |
| `extraEnvironmentVars` | Additional environment variables for container | `{}` |
| `extraVolumes` | Additional volumes to mount into the pod | `[]` |

## License

[MIT License](LICENSE)
