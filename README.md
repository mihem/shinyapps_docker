# Shiny Apps — MzH Lab

Interactive single-cell transcriptomics atlases and analysis tools, served via Shiny Server on Docker.

**Live:** https://osmzhlab.uni-muenster.de/shiny/  
**Docker Hub:** https://hub.docker.com/repository/docker/mihem/shinyapps_3838

---

## Apps

| App | Description |
|---|---|
| [cerebro_covid19](https://osmzhlab.uni-muenster.de/shiny/cerebro_covid19/) | Single-cell atlas of CSF in Neuro-COVID and controls |
| [cerebro_meninges_mouse](https://osmzhlab.uni-muenster.de/shiny/cerebro_meninges_mouse/) | Single-cell atlas of the dura from mice |
| [cerebro_meninges_rat](https://osmzhlab.uni-muenster.de/shiny/cerebro_meninges_rat/) | Single-cell atlas of the meninges from rat |
| [cerebro_pcnsl](https://osmzhlab.uni-muenster.de/shiny/cerebro_pcnsl/) | Single-cell atlas of primary CNS B-cell lymphoma |
| [cerebro_pns_atlas](https://osmzhlab.uni-muenster.de/shiny/cerebro_pns_atlas/) | Single nuclei sural nerve atlas |
| [cerebro_pns_naive](https://osmzhlab.uni-muenster.de/shiny/cerebro_pns_naive/) | Single-cell atlas of peripheral nerve (naive mice) |
| [cerebro_pns_nodicam](https://osmzhlab.uni-muenster.de/shiny/cerebro_pns_nodicam/) | Single-cell atlas of peripheral nerve (NOD ICAM-1 deficient) |
| [cerebro_stroke](https://osmzhlab.uni-muenster.de/shiny/cerebro_stroke/) | Single-cell atlas of leukocytes in murine experimental stroke |
| [cerebro_uveitis](https://osmzhlab.uni-muenster.de/shiny/cerebro_uveitis/) | Single-cell atlas of intraocular leukocytes in uveitis |
| [cerebro_dura](https://osmzhlab.uni-muenster.de/shiny/cerebro_dura/) | Single-cell atlas of the dura (EAE mice, spatial) |
| [cerebro_PMS](https://osmzhlab.uni-muenster.de/shiny/cerebro_PMS/) | Single-cell atlas of progressive MS |
| [cerebro_in_seq](https://osmzhlab.uni-muenster.de/shiny/cerebro_in_seq/) | IN-Seq dataset |
| [btki](https://osmzhlab.uni-muenster.de/shiny/btki/) | BTKi therapy — PBMC and CSF analysis dashboard |
| [ns](https://osmzhlab.uni-muenster.de/shiny/ns/) | Neurosarcoidosis vs. MS classifier |

Cerebro-based apps use [cerebroApp](https://github.com/romanhaa/cerebroApp) / [cerebroAppLite](https://github.com/mihem/cerebroAppLite).

---

## Repository structure

```
shinyapps_docker/
├── Dockerfile            # Fast incremental build from the rolling image
├── Dockerfile.bootstrap  # Clean rebuild from the pinned Rocker image
├── packages.R            # Complete direct R package manifest
├── docker-compose.yml    # Runtime config: ports, volumes, restart policy
├── apps/                 # All Shiny apps (bind-mounted into container)
│   ├── cerebro_covid19/
│   ├── cerebro_dura/
│   ├── btki/
│   ├── ns/
│   └── ...
├── 1_cerebro_host.R      # Helper: scaffold a new cerebroAppLite app
└── 2_cerebro_h5.R        # Helper: convert .crb expression matrix to HDF5
```

App data files (`.h5`, `.crb`, `.rds`) are **not** in git — they are large binary files that live on the server and are served via the bind mount.

---

## Deployment

### First-time setup on the server

```bash
# Clone repo
git clone <repo-url> /path/to/shinyapps_docker
cd /path/to/shinyapps_docker

# Place data files alongside app code (not tracked in git):
# apps/cerebro_covid19/extdata/v1.4/sc_merge_cerebro.h5
# apps/cerebro_dura/data/...  etc.

# Seed the rolling image once from the last complete image.
docker pull mihem/shinyapps_3838:v15
docker tag mihem/shinyapps_3838:v15 mihem/shinyapps_3838:rolling

# Build the incremental image.
docker compose build shiny

# Start the container
docker compose up -d
```

The container mounts `./apps` into `/srv/shiny-server/shiny` — only the app directories are visible inside the container. Infrastructure files (`Dockerfile`, `renv.lock`, etc.) are not exposed.

If `v15` or another complete rolling image is unavailable, create one from
scratch with the bootstrap Dockerfile:

```bash
docker buildx build --load \
  -f Dockerfile.bootstrap \
  -t mihem/shinyapps_3838:rolling \
  .
```

This clean path installs the system libraries and every package in
`packages.R`, so it is intentionally slower than a routine rolling build.

### Routine deployment (app code change only)

No rebuild needed. Just pull and restart:

```bash
git pull
docker compose restart
```

### After adding a new R package

```bash
git pull
docker compose build shiny
docker compose up -d
```

The Dockerfile starts from the previous `rolling` image. `pak` therefore sees
the existing package library and performs the minimum necessary installation
work. `pak` prefers binaries when available and falls back to source packages
when needed. A failed build does not replace the existing `rolling` image.

### Push a new image to Docker Hub

```bash
VERSION=v17
docker compose build shiny
docker tag mihem/shinyapps_3838:rolling mihem/shinyapps_3838:${VERSION}
docker push mihem/shinyapps_3838:${VERSION}
docker push mihem/shinyapps_3838:rolling
```

`rolling` always points to the newest release. Keep each numbered tag immutable
so an earlier image remains available for rollback.

---

## Adding a new R package

Add the package name to `required_packages` in `packages.R`, then rebuild:

```bash
# On the server:
git pull
docker compose build shiny
docker compose up -d
```

Because the previous `rolling` image is the build base, only the new package
and updates selected by `pak` are installed. `packages.R` remains the complete
manifest used by both the incremental and clean bootstrap builds.

---

## Adding a new app

1. Create the app directory under `apps/`:

   ```bash
   # For a cerebroAppLite app:
   Rscript 1_cerebro_host.R apps/my_new_app

   # Convert expression matrix to HDF5 (optional, for large datasets):
   Rscript 2_cerebro_h5.R apps/my_new_app
   ```

2. Place data files (`.h5`, `.crb`) under `apps/my_new_app/extdata/` on the server.

3. Restart the container — Shiny Server auto-discovers new app subdirectories:

   ```bash
   docker compose restart
   ```

No image rebuild is needed to add an app.

---

## Useful commands

```bash
docker compose up -d          # start / restart in background
docker compose down           # stop and remove container
docker compose logs -f        # stream logs
docker compose ps             # check container status
```
