# Each successful build replaces the rolling image used as the next build's
# base. Seed it once from v15 as documented in README.md.
FROM mihem/shinyapps_3838:rolling

# The rolling base already contains the installed library. pak checks the full
# manifest and performs the minimum necessary installation work.
COPY packages.R /tmp/packages.R

RUN R -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/")' \
  && Rscript /tmp/packages.R \
  && rm /tmp/packages.R
