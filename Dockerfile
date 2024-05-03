# Example shiny app docker file
# https://blog.sellorm.com/2021/04/25/shiny-app-in-docker/
#https://rstudio.github.io/renv/articles/docker.html

# get shiny server and R from the rocker project
FROM rocker/shiny:4.2.1 AS base

# system libraries
# Try to only install system libraries you actually need
# Package Manager is a good resource to help discover system deps

# Delete example files
RUN rm -rf /srv/shiny-server/*

# install R packages required 
# Change the packages list to suit your needs
RUN R -e 'install.packages("renv", repos = "https://packagemanager.rstudio.com/cran/__linux__/jammy/2024-04-26")'

# Copy renv files 
WORKDIR /srv/shiny-server/shiny
COPY renv.lock renv.lock
COPY cerebro_aie cerebro_aie
COPY cerebro_covid19 cerebro_covid19
COPY cerebro_meninges_mouse cerebro_meninges_mouse
COPY cerebro_meninges_rat cerebro_meninges_rat
COPY cerebro_pcnsl cerebro_pcnsl
COPY cerebro_pns_naive cerebro_pns_naive
COPY cerebro_pns_nodicam cerebro_pns_nodicam
COPY cerebro_stroke cerebro_stroke
COPY cerebro_uveitis cerebro_uveitis
COPY ns ns

ENV RENV_PATHS_LIBRARY renv/library

# Restore the R environment
RUN R -e "renv::restore()"

#second stage
FROM rocker/shiny:4.2.1

WORKDIR /srv/shiny-server/shiny
COPY --from=base /srv/shiny-server/shiny .

COPY cerebro_pns_atlas cerebro_pns_atlas
