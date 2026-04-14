# Shiny apps Docker image
# App code and data are NOT baked into this image.
# They are bind-mounted from the host at runtime via docker-compose.yml.
# This image provides only: OS, system libraries, and R packages.
#
# Build:
#   docker buildx build -t mihem/shinyapps_3838:v14 .
#
# Packages are installed via pak (parallel, binary-first from P3M).
# The BuildKit cache mount keeps the pak cache across builds so that
# adding one new package only downloads/compiles that package.
# Requires BuildKit (default since Docker 23).

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

# Install pak from P3M binary snapshot
RUN R -e 'install.packages("pak", repos = "https://packagemanager.posit.co/cran/__linux__/noble/2026-04-14")'

# Install all R packages required by the Shiny apps.
# pak resolves all transitive dependencies automatically, installs binaries
# from P3M where available, and compiles from source otherwise.
#
# CRAN / Bioconductor packages: plain name
# GitHub packages:              "owner/repo/subdir@ref"
#
# To add a new package: add it to the list below and rebuild.
# The BuildKit cache mount means only the new package is downloaded/compiled.
RUN --mount=type=cache,target=/root/.cache/R/pkgcache \
    R -e 'pak::pak(c( \
      "ape", \
      "base64enc", \
      "bslib", \
      "cachem", \
      "caret", \
      "circlize", \
      "colourpicker", \
      "ComplexHeatmap", \
      "cowplot", \
      "crayon", \
      "data.table", \
      "DESeq2", \
      "digest", \
      "dplyr", \
      "DT", \
      "effsize", \
      "kevinblighe/EnhancedVolcano", \
      "future", \
      "ggplot2", \
      "ggpmisc", \
      "ggpubr", \
      "ggrepel", \
      "glmnet", \
      "glue", \
      "gridExtra", \
      "HDF5Array", \
      "htmlwidgets", \
      "jsonify", \
      "later", \
      "memoise", \
      "msigdbr", \
      "plotly", \
      "promises", \
      "purrr", \
      "url::https://cran.r-project.org/src/contrib/Archive/qs/qs_0.27.3.tar.gz", \
      "RColorBrewer", \
      "readr", \
      "readxl", \
      "scales", \
      "scRepertoire", \
      "scrypt", \
      "Seurat", \
      "shiny", \
      "shinycssloaders", \
      "shinydashboard", \
      "shinyFeedback", \
      "shinyFiles", \
      "shinyjs", \
      "shinymanager", \
      "shinyWidgets", \
      "speckle", \
      "stringr", \
      "tibble", \
      "tidyr", \
      "tidyverse", \
      "viridis" \
    ))'

# BPCells is installed separately because it is downloaded from GitHub and
# is prone to transient download failures. A separate RUN step means Docker
# can retry just this layer without reinstalling everything above.
RUN --mount=type=cache,target=/root/.cache/R/pkgcache \
    R -e 'pak::pak("bnprks/BPCells/r@main")'
