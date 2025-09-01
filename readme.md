# HUMAN Reading Assessment API

This repository is part of the research project HUMAN Reading Assessment, a consortium with the University of Stavanger, Norway, and the University of Twente, the Netherlands. 

## Usage

The Computerized Adaptive Testing API is packaged as a Docker container. The API relies on several external services to get access to questions and parameters (sanity CMS) and responses (SQL database). You will need to supply these yourself.

### Environment

The API requires the below environment variables to be supplied. All variables are required, with the exception of DB_HOST/DB_PORT and DB_SOCKET, where either the host/port or the socket needs to be set. If both are set, the socket takes precendence.

```sh
# Sanity configuration for text and question data
SANITY_TOKEN=YOUR_SANITY_TOKEN_HERE
SANITY_PROJECT_ID=YOUR_SANITY_PROJECT_ID_HERE

# Database configuration for response records
DB_USER=username
DB_PASS=password
DB_NAME=database_name

DB_HOST=localhost
DB_PORT=3306

# if a socket is set, that takes precedence
# DB_SOCKET=YOUR_SOCKET_HERE
```

In a development environment, if the environment variable `ENVIRONMENT` is set to `DEVELOPMENT`, and the file `.env` exists next to the main R script, the script will attempt to load environment variables from this file. 

Alternatively, the environment can be supplied directly to the container - the recommended way of doing so is through a compose file. This approach is described below.

### docker compose

The recommended procedure is to create copies of `.env.example` and `compose.yml`. Add the required environment variables to `.env.example`, and store it as `.env`. You can then run `docker compose up` to start the service. 

### API docs

The docker container exposes Swagger documentation for all exposed endpoints at `.../__docs__/`. 