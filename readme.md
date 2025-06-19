# HUMAN Reading Assessment API

This repository is part of the research project HUMAN Reading Assessment, a consortium with the University of Stavanger, Norway, and the University of Twente, the Netherlands. 

## Usage

The Computerized Adaptive Testing API is packaged as a Docker container. The API relies on several external services to get access to questions and parameters (sanity CMS) and responses (SQL database). You will need to supply these yourself.

### docker compose

The recommended procedure is to create copies of `.env.example` and `compose.yml`. Add the required environment variables to `.env.example`, and store it as `.env`. You can then run `docker compose up` to start the service. 

### API docs

The docker container exposes Swagger documentation for all exposed endpoints at `.../__docs__/`. 