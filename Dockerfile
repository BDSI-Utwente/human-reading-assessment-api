FROM rstudio/plumber

LABEL org.opencontainers.image.authors="Karel Kroeze <k.a.kroeze@utwente.nl>"
LABEL org.opencontainers.image.source=https://github.com/bdsi-utwente/human-reading-assessment-api

RUN R -e "install.packages('pak')"
RUN R -e "pak::pak(c('httr2', 'here', 'RMariaDB', 'dotenv', 'tidyverse'))"
RUN mkdir /app

COPY . /app

CMD ["/app/main.R"]