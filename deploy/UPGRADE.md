# Upgrading Move Big Rocks Core

How to deploy a new platform release to your instance.

## Overview

The upgrade path is:

1. **Platform repo** builds and tags a new release (automatic on push to `main`)
2. **This repo** (your instance repo) pins the new version in `mbr.instance.yaml`
3. Push to `main` triggers the deploy workflow (blue-green, zero-downtime)

## Prerequisites

- The target version must exist as tagged OCI artifacts in `ghcr.io/movebigrocks/`
- GitHub Actions secrets must be configured (SSH key, DATABASE_DSN, JWT_SECRET, etc.)
- The target server must be reachable

## Step-by-step

### 1. Find the latest platform release

Check the [platform releases on GitHub](https://github.com/MoveBigRocks/platform/tags).

Or from a local clone of the platform repo:

```bash
cd /path/to/platform
git fetch --tags
git tag --sort=-v:refname | head -5
```

To see what changed since your currently pinned version:

```bash
git log v1.0.0..v1.1.0 --oneline
```

### 2. Verify the CI pipeline succeeded

The platform's Release Pipeline must have completed successfully for the target version:

```bash
gh run list --repo MoveBigRocks/platform --workflow production.yml --limit 5
```

A successful run means the OCI artifacts (`mbr-services`, `mbr-migrations`, `mbr-manifest`) are published and tagged.

### 3. Update mbr.instance.yaml

Edit `mbr.instance.yaml` and update all four fields under `spec.deployment.release.core`:

```yaml
    release:
      core:
        version: v1.1.0
        servicesArtifact: ghcr.io/movebigrocks/mbr-services:v1.1.0
        migrationsArtifact: ghcr.io/movebigrocks/mbr-migrations:v1.1.0
        manifestArtifact: ghcr.io/movebigrocks/mbr-manifest:v1.1.0
```

All four lines must reference the same version tag.

### 4. Commit and push

```bash
git add mbr.instance.yaml
git commit -m "Bump core release to v1.1.0"
git push origin main
```

### 5. Monitor the deploy

The push triggers the Production Deploy workflow:

```bash
gh run watch
```

The workflow will:
1. Parse `mbr.instance.yaml` for artifact references
2. Pull OCI artifacts from ghcr.io
3. SSH to the server and deploy to the inactive blue/green slot
4. Health-check the new slot on localhost
5. Switch traffic to the new slot
6. Run smoke tests against the public endpoints

### 6. Verify

After the workflow completes:

```bash
curl -sf https://api.yourdomain.com/health
curl -sf https://admin.yourdomain.com/health
curl -sI https://admin.yourdomain.com/login | head -1
```

## Rollback

To roll back, set `mbr.instance.yaml` back to the previous version, commit, and push. The blue-green deploy will activate the new (old-version) slot.

```bash
git revert HEAD
git push origin main
```

If the deploy workflow itself failed mid-deploy and the server is unhealthy, SSH in and restart the previously active slot:

```bash
ssh mbr@your-server-ip
cat /opt/mbr/.active-slot
sudo systemctl start mbr-blue   # or mbr-green, whichever was last healthy
```

## Blue-Green Slot Reference

| Slot  | Default Port | Binary               | Service            |
|-------|-------------|----------------------|--------------------|
| Blue  | 8080        | `/opt/mbr/mbr-blue`  | `mbr-blue.service`  |
| Green | 8081        | `/opt/mbr/mbr-green` | `mbr-green.service` |

The active slot is recorded in `/opt/mbr/.active-slot`. Each deploy targets the inactive slot, health-checks it, then flips.

Note: If your instance uses non-default ports (e.g. on a shared host), the ports in your service files and Caddyfile will differ.

## Triggering a Redeploy Without a Version Change

Use the GitHub Actions workflow_dispatch trigger:

```bash
gh workflow run production.yml
```

This re-deploys the currently pinned version (useful after config or secret changes).
