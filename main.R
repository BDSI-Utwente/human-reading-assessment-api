library(plumber)
library(here)
here::i_am("main.R")

dotenv::load_dot_env(here(".env"))

stopifnot(sanity_token = !(Sys.getenv("SANITY_TOKEN") == ""))
stopifnot(sanity_project_id = !(Sys.getenv("SANITY_PROJECT_ID") == ""))
stopifnot(db_host = !(Sys.getenv("STAGING_DB_HOST") == ""))
stopifnot(db_port = !(Sys.getenv("STAGING_DB_PORT") == ""))
stopifnot(db_user = !(Sys.getenv("STAGING_DB_USER") == ""))
stopifnot(db_pass = !(Sys.getenv("STAGING_DB_PASS") == ""))
stopifnot(db_name = !(Sys.getenv("STAGING_DB_NAME") == ""))

source(here("functions/sql_get_responses.R"))
source(here("functions/sanity_get_texts_and_questions.R"))

texts <- tibble()
texts_cache_timestamp = NULL

#* @get /refresh_texts_cache
#* @serializer json
#* @response 200 timestamp and contents of refreshed texts cache
#* Trigger a refresh of the texts cache
#*
#* Triggers a refresh of the texts cache from sanity CMS. This
#* should happen automatically periodically in normal circumstances.
update_texts_cache <- function(req, res) {
  texts <<- get_question_metadata() |>
    distinct(item_id) |>
    rename(sanity_text_id = item_id)
  texts_cache_timestamp <<- lubridate::now()

  list(
    msg = I("Text cache was successfully updated."),
    texts = texts$sanity_text_id,
    timestamp = I(texts_cache_timestamp)
  )
}
# run once to initialize
update_texts_cache()


#* @param user_id:int*
#* @get /next_text
#* @serializer unboxedJSON
#* @response 200 next_item_id, texts_cache_timestamp and elapsed_time
#* Get next text id
#*
#* Get next text id for the provided user. Uses texts_cache as the source
#* for available texts, disregards texts the user has already seen, then
#* randomly samples an eligible unseen text. Sampling weights are inversely
#* proportional to overall exposure, to ensure an even exposure across texts.
function(req, res, user_id) {
  con <- create_db_connection()
  .start <- lubridate::now()

  if (user_id < 0) {
    stop("A valid user id is required.")
  }

  # TODO: Check if user id exists?
  next_text_id = get_next_text_id(con, user_id, texts)
  DBI::dbDisconnect(con)

  list(
    next_text_id = next_text_id,
    texts_cache_timestamp = lubridate::format_ISO8601(texts_cache_timestamp),
    elapsed_time = as.numeric(lubridate::now() - .start)
  )
}
