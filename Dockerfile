# Each successful build replaces the rolling image used as the next build's
# base. Seed it once from v15 as documented in README.md.
FROM mihem/shinyapps_3838:rolling

# Use the current pak resolver, install only the new CRAN dependencies, and
# remove qs now that BTKi data and caches use RDS.
RUN R -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/")' \
  && R -e 'pak::pak(c("stringdist", "visNetwork"), upgrade = FALSE)' \
  && R -e 'if (requireNamespace("qs", quietly = TRUE)) remove.packages("qs")'
