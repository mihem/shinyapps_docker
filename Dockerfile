# Shiny apps Docker image
# App code and data are NOT baked into this image.
# They are bind-mounted from the host at runtime via docker-compose.yml.
# This image provides only: OS, system libraries, and R packages.
#
# Build:
#   docker buildx build -t mihem/shinyapps_3838:v14 .
#
# The --mount=type=cache below keeps the renv package cache (downloaded and
# compiled packages) persistent across builds on the build host. When you add
# a new package to renv.lock, only that package is downloaded/compiled;
# everything else is served from the cache. Requires BuildKit (default since
# Docker 23). If you are on an older Docker: DOCKER_BUILDKIT=1 docker build ...

# get shiny server and R from the rocker project
FROM rocker/shiny@sha256:7e9bf76faa7201fd60e2229e75f2e085030cfd552252570db16b12c9acbf36c9

# system libraries
RUN apt-get update --yes \
  && apt-get upgrade --yes \
  && apt-get install --yes \
  libhdf5-dev \
  cmake \
  pkg-config \
  libnlopt-dev \
  build-essential \
  gfortran \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libglib2.0-dev \
  libjpeg-dev \
  libtiff-dev \
  libcairo2-dev \
  libsqlite3-dev \
  libgit2-dev \
  libssh2-1-dev \
  libmagick++-dev \
  libgsl-dev \
  libglpk-dev \
  && rm -rf /var/lib/apt/lists/*

# Delete example files shipped with the base image
RUN rm -rf /srv/shiny-server/*

# Install renv from a date-pinned binary snapshot
RUN R -e 'install.packages("renv", repos = "https://packagemanager.posit.co/cran/__linux__/noble/2026-04-14")'

WORKDIR /srv/shiny-server/shiny

COPY renv.lock renv.lock

# RENV_PATHS_LIBRARY: where the project library is installed (baked into image)
# RENV_PATHS_CACHE:   where renv caches downloaded/compiled packages
#                     mapped to the BuildKit cache mount so it persists between builds
ENV RENV_PATHS_LIBRARY=/srv/shiny-server/shiny/renv/library
ENV RENV_PATHS_CACHE=/renv-cache

# Restore R packages.
# --mount=type=cache keeps /renv-cache across builds on this machine,
# so only newly added packages are downloaded/compiled on subsequent builds.
RUN --mount=type=cache,target=/renv-cache \
    R -e "renv::restore()"
