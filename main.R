library(plumber)
library(here)
library(tidyverse)
here::i_am("main.R")

# TODO: allow mutually exclusive item sets to be supplied at runtime?
MUTUALLY_EXCLUSIVE_ITEM_SETS = list(
  # Fakta om mat og andre greier
  c(
    "927cf520-4b0b-4714-8c3d-80f4c3bdaae5",
    "3f7d5788-240a-46a6-9028-64f460d82ec8"
  ),

  # Solenergi
  c(
    "7692bfef-fef9-44be-9236-91cd8e17dc0a",
    "1eae341e-6948-476c-9df8-aa758993d147"
  ),

  # Minecraft
  c(
    "ffffece4-14da-4ed0-819a-a7039a0101d1",
    "d6f8be0b-09bc-4a6b-bc3a-81935f1e408a"
  )
)

# if we're on a development environment, AND a .env file exists - load that
if (Sys.getenv("ENVIRONMENT") == "DEVELOPMENT" && file.exists(here(".env"))) {
  dotenv::load_dot_env(here(".env"))
}

# in all cases, we MUST have all the required env values set somehow
stopifnot(sanity_token = !(Sys.getenv("SANITY_TOKEN") == ""))
stopifnot(sanity_project_id = !(Sys.getenv("SANITY_PROJECT_ID") == ""))
stopifnot(db_user = !(Sys.getenv("DB_USER") == ""))
stopifnot(db_pass = !(Sys.getenv("DB_PASS") == ""))
stopifnot(db_name = !(Sys.getenv("DB_NAME") == ""))

# we MUST have a socket or a HOST/PORT combo
socket_set = (Sys.getenv("DB_SOCKET") != "")
host_set = (Sys.getenv("DB_HOST") != "")
port_set = (Sys.getenv("DB_PORT") != "")

if (!socket_set && !(host_set && port_set)) {
  stop("either 'DB_SOCKET' or 'DB_HOST' and 'DB_PORT' must be set")
}

source(here("functions/sql_get_responses.R"))
source(here("functions/sanity_get_texts_and_questions.R"))

texts_cache <- tibble()
params_cache <- tibble()
cache_timestamp = NULL

.check_cache <- function() {
  if (
    is.null(cache_timestamp) ||
      (lubridate::now() - cache_timestamp) > lubridate::days(1)
  ) {
    update_texts_cache()
  }
}

#* @post /refresh_texts_cache
#* @serializer unboxedJSON
#* @response 200 timestamp and contents of refreshed texts cache
#* Trigger a refresh of the texts cache
#*
#* Triggers a refresh of the texts cache from sanity CMS. This
#* should happen automatically periodically in normal circumstances.
update_texts_cache <- function(req, res) {
  questions_cache <<- get_question_metadata()

  params_cache <<- questions_cache |>
    unnest(params, keep_empty = TRUE)

  texts_cache <<- questions_cache |>
    distinct(sanity_text_id)

  cache_timestamp <<- lubridate::now()

  list(
    msg = I("Text cache was succesfully updated."),
    texts = texts_cache$sanity_text_id,
    timestamp = lubridate::format_ISO8601(lubridate::with_tz(
      cache_timestamp,
      "UTC"
    ))
  )
}

#* @param user_id:int*
#* @param n_texts:int
#* @get /next_texts
#* @serializer unboxedJSON
#* @response 200 next_text_id, cache_timestamp and elapsed_time
#* Get next text id
#*
#* Get next text id for the provided user. Uses texts_cache as the source
#* for available texts, disregards texts the user has already seen, then
#* randomly samples an eligible unseen text. Sampling weights are inversely
#* proportional to overall exposure, to ensure an even exposure across texts.
function(req, res, user_id, n_texts = 2) {
  .start <- lubridate::now()
  con <- create_db_connection()
  .check_cache()

  # cast input types
  user_id <- as.integer(user_id)
  n_texts <- as.integer(n_texts)

  if (user_id < 0) {
    stop("A valid user id is required.")
  }

  # TODO: Check if user id exists?
  next_text_ids = get_next_text_ids(
    con = con,
    student_id = user_id,
    texts = texts_cache,
    mutually_exclusive_item_sets = MUTUALLY_EXCLUSIVE_ITEM_SETS,
    n_texts = n_texts
  )
  DBI::dbDisconnect(con)

  list(
    next_text_ids = next_text_ids,
    cache_timestamp = lubridate::format_ISO8601(lubridate::with_tz(
      cache_timestamp,
      "UTC"
    )),
    elapsed_time = as.numeric(lubridate::now() - .start)
  )
}

#* Get ability estimate
#*
#* Obtain ability estimate for the given user_id, for responses within the
#* given timeframe. If start or end are not given, the time frame will be
#* open-ended. If neither start nor end are given, all responses by that
#* user will be used.
#*
#* @get /ability_estimate
#* @param user_id:int*
#* @param start:string
#* @param end:string
#* @serializer unboxedJSON
function(req, res, user_id, start = "", end = "") {
  .start <- lubridate::now()
  con <- create_db_connection()
  .check_cache()

  if (user_id < 0) {
    stop("A valid user id is required.")
  }

  # get estimate
  estimate <- get_ability_estimate(con, user_id, start, end)

  # disconnect
  DBI::dbDisconnect(con)

  # return estimate
  estimate$elapsed_time <- as.numeric(lubridate::now() - .start)
  estimate$cache_timestamp <- lubridate::format_ISO8601(lubridate::with_tz(
    cache_timestamp,
    "UTC"
  ))
  return(estimate)
}
