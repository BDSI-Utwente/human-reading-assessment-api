FROM rstudio/plumber

LABEL org.opencontainers.image.authors="Karel Kroeze <k.a.kroeze@utwente.nl>"
LABEL org.opencontainers.image.source=https://github.com/bdsi-utwente/human-reading-assessment-api


RUN R -e "install.packages('pak')"

# use pak to install dependencies and cache them
RUN --mount=type=cache,target=/root/.cache/R/pkgcache/pkg \
    R -e "pak::pak(c('httr2', 'here', 'RMariaDB', 'dotenv', 'tidyverse', 'plumber'))"
RUN mkdir /app

COPY . /app

CMD ["/app/main.R"]