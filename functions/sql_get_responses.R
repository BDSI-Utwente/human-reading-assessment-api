library(tidyverse)
library(dbplyr)
library(RMariaDB)


# create sql backend
create_db_connection <- function(
    host = Sys.getenv("DB_HOST"),
    port = Sys.getenv("DB_PORT"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASS"),
    dbname = Sys.getenv("DB_NAME")) {
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = host,
    port = port,
    user = user,
    password = password,
    dbname = dbname,

    # be specific that we expect a MySQL backend
    mysql = TRUE,

    # enforce SSL (but don't check certificates)
    client.flag = RMariaDB::CLIENT_SSL
  )
}

# we have answers for each user-text-question-option pair,
# but we're only really interested in the number of responses
# to each text, and the texts the (current) respondent has
# already seen.

# assuming that each student only ever answers each question
# once, we can ignore responses to questions/options and just
# look at unique pairings of student/text ids to get accurate
# counts for each.

# we also need to get a list of all questions, particularly
# early on when not all questions will have been mentioned,
# and to incorporate possible new questions.

#' Sample next item_id for a given student.
#'
#' Randomly samples an item that has not yet been presented
#' to the current student. Items are weighted inversely to their
#' exposure rate to encourage roughly uniform exposure during
#' testing.
get_next_text_id <- function(con, student_id, texts) {
  # we'll be matching local and remote data sources, so collect
  # all the remote data to local first.
  .tbl <- tbl(con, "Answers")

  # get response counts for all texts
  response_counts <- .tbl |>
    distinct(student_id, sanity_text_id) |>
    count(sanity_text_id) |>
    collect()

  # get list of texts seen by this student
  texts_seen <- .tbl |>
    filter(student_id == student_id) |>
    distinct(sanity_text_id) |>
    collect()

  weights <- response_counts |>
    # ensure all available texts are included
    full_join(texts, by = join_by(sanity_text_id)) |>
    # set exposure count to 0 for items that have never been exposed
    replace_na(list(n = 0)) |>
    # filter out seen texts
    anti_join(texts_seen, by = join_by(sanity_text_id)) |>
    # calculate weights based on inverse exposure rate (+1)
    transmute(sanity_text_id, weight = 1 / (n + 1))

  # randomly sample an item id
  sample(weights$sanity_text_id, 1, prob = weights$weight)
}
