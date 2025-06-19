library(plumber)
library(here)
library(tidyverse)
here::i_am("main.R")

dotenv::load_dot_env(here(".env"))

stopifnot(sanity_token = !(Sys.getenv("SANITY_TOKEN") == ""))
stopifnot(sanity_project_id = !(Sys.getenv("SANITY_PROJECT_ID") == ""))
stopifnot(db_host = !(Sys.getenv("DB_HOST") == ""))
stopifnot(db_port = !(Sys.getenv("DB_PORT") == ""))
stopifnot(db_user = !(Sys.getenv("DB_USER") == ""))
stopifnot(db_pass = !(Sys.getenv("DB_PASS") == ""))
stopifnot(db_name = !(Sys.getenv("DB_NAME") == ""))

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
#* @get /next_text
#* @serializer unboxedJSON
#* @response 200 next_text_id, cache_timestamp and elapsed_time
#* Get next text id
#*
#* Get next text id for the provided user. Uses texts_cache as the source
#* for available texts, disregards texts the user has already seen, then
#* randomly samples an eligible unseen text. Sampling weights are inversely
#* proportional to overall exposure, to ensure an even exposure across texts.
function(req, res, user_id) {
  .start <- lubridate::now()
  con <- create_db_connection()
  .check_cache()

  if (user_id < 0) {
    stop("A valid user id is required.")
  }

  # TODO: Check if user id exists?
  next_text_id = get_next_text_id(con, user_id, texts_cache)
  DBI::dbDisconnect(con)

  list(
    next_text_id = next_text_id,
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
  dbDisconnect(con)

  # return estimate
  estimate$elapsed_time <- as.numeric(lubridate::now() - .start)
  estimate$cache_timestamp <- lubridate::format_ISO8601(lubridate::with_tz(
    cache_timestamp,
    "UTC"
  ))
  return(estimate)
}
