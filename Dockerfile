# Example shiny app docker file
# https://blog.sellorm.com/2021/04/25/shiny-app-in-docker/

# get shiny server and R from the rocker project
FROM rocker/shiny:4.5.2

# system libraries
# Try to only install system libraries you actually need
# Package Manager is a good resource to help discover system deps
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
  libglpk-dev\
  && rm -rf /var/lib/apt/lists/*


# Delete example files
RUN rm -rf /srv/shiny-server/*

# install R packages required 
# Change the packages list to suit your needs
RUN R -e 'install.packages("renv", repos = "https://packagemanager.posit.co/cran/__linux__/noble/2025-04-09")'

# Copy renv files 
WORKDIR /srv/shiny-server/shiny
COPY renv.lock renv.lock

ENV RENV_PATHS_LIBRARY renv/library

# Restore the R environment
RUN R -e "renv::restore()"

# copy the apps
COPY cerebro_covid19 cerebro_covid19
COPY cerebro_meninges_mouse cerebro_meninges_mouse
COPY cerebro_meninges_rat cerebro_meninges_rat
COPY cerebro_pcnsl cerebro_pcnsl
COPY cerebro_pns_naive cerebro_pns_naive
COPY cerebro_pns_nodicam cerebro_pns_nodicam
COPY cerebro_stroke cerebro_stroke
COPY cerebro_uveitis cerebro_uveitis
COPY ns ns
COPY cerebro_pns_atlas cerebro_pns_atlas
COPY btki btki
