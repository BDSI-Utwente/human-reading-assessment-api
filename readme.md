---
author: Karel Kroeze <k.a.kroeze@utwente.nl>
date: 2025-10-03
changelog: 
    - date: 2025-10-03
      desc: added basic dev/deploy instructions
---


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

## Development

The main scripts are set up to automatically use a local `.env` file at runtime, however you may have to load environment variables during development using `dotenv::load_env(...file...)`. You will have to obtain credentials from @Karel-Kroeze or Runar/Lukas at Grensesnitt.

The api is packaged as a docker container and published on ghcr.io. To run, build, and update container images you will need to have docker along with the docker-compose plugin avialable (or an equivalent alternative). With a terminal open in the project folder, you should then be able to run `docker compose` commands to build and run the image; 

```
# build the image
docker compose build 

# run the image for a local server 
# add --build and/or -d options to rebuild the image and detach from the container outputs, respectively:
docker compose up [--build] [-d]
```

To push changes to the container registry, you will have to create a github token, authenticate the docker cli, and link the container to the ghcr.io registry. Follow the instructions for authenticating with a (classic) personal token here: <https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic>

Note that you will need to have write permissions to the BDSi-UTwente organization on GitHub in order to push to the default location. If you want to change the registry, account or name of the image being pushed, please refer to the GitHub packages repository and Docker documentation.

> WARNING: Please triple check if images function correctly before pushing them, and that you haven't accidentally exposed any sensitive information or credentials in the image. 

You should then be able to push images as per the instructions, or simply using: 

```
docker compose build
docker compose push
```

### Deployment

After an image has been pushed, Grensesnitt has to deploy the new image in their environment. Time to send an email! 
