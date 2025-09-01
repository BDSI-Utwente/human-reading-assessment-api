library(tidyverse)
library(dbplyr)
library(RMariaDB)


# create sql backend
create_db_connection <- function(
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS"),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST"),
  port = Sys.getenv("DB_PORT"),
  socket = Sys.getenv("DB_SOCKET")
) {
  # if socket is set, use that
  if (socket != "") {
    DBI::dbConnect(
      RMariaDB::MariaDB(),
      socket = socket,
      user = user,
      password = password,
      dbname = dbname,

      # we expect a MySQL backend
      mysql = TRUE
    )

    # otherwise, use host/port
  } else {
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
get_next_text_ids <- function(
  con,
  student_id,
  texts,
  mutually_exclusive_item_sets = NULL,
  n_texts = 2
) {
  # we'll be matching local and remote data sources, so collect
  # all the remote data to local first.
  .tbl <- tbl(con, "Answers")

  # get list of texts seen by this student
  texts_seen <- .tbl |>
    filter(student_id == student_id) |>
    distinct(sanity_text_id) |>
    collect()

  # get response counts for all texts
  response_counts <- .tbl |>
    distinct(student_id, sanity_text_id) |>
    count(sanity_text_id) |>
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

  # if there are items that are mutually exclusive, make sure we dis-
  # allow any other questions if any question in the exclusive set has
  # been seen.
  if (!is.null(mutually_exclusive_item_sets)) {
    for (exclusive_set in mutually_exclusive_item_sets) {
      # if any of a set has been seen
      if (any(exclusive_set %in% texts_seen$sanity_text_id)) {
        # remove all items in the set from the available choices
        weights <- weights |>
          filter(!(sanity_text_id %in% exclusive_set))
      }
    }
  }

  # randomly sample item ids from the remaining available items,
  # using a naive constrained sampler if needed.
  if (!is.null(mutually_exclusive_item_sets)) {
    ids <- .constrained_sample(
      options = weights$sanity_text_id,
      weights = weights$weight,
      n = n_texts,
      exclusive_sets = mutually_exclusive_item_sets
    )
  } else {
    ids <- sample(
      weights$sanity_text_id,
      size = n_texts,
      prob = weights$weight
    )
  }

  return(ids)
}

.constrained_sample <- function(
  options,
  weights,
  n,
  exclusive_sets,
  max_attempts = 50
) {
  # note that we're more likely to throw away items that are in exclusive
  # sets, possibly leading to them being underexposed. I'm relying on the
  # fact that we'll be weighting by exposure to balance out this effect
  # in the long term - but we will want to validate that this works in
  # practice, probably through simulation.
  # TODO: validate that this naive approach doesn't unduly bias average
  # exposure of items in exclusive sets.

  # Error on length(options) < n
  if (length(options) < n) {
    stop("Number of options is smaller than sample size!")
  }

  # The sample function has a nasty built-in ambiguity when options is
  # numeric and of length 1. To avoid this, we can simply implement a
  # `resample` function as per the docs for `sample`, but a simpler
  # solution is to simply directly return when length(options) == n.
  if (length(options) == n) {
    if (.items_are_mutually_exclusive(options, exclusive_sets)) {
      warning("The only available options are mutually exclusive!")
    }
    return(options)
  }

  .attempt <- 1
  .res <- sample(options, n, FALSE, weights)

  while (.attempt < max_attempts) {
    if (.items_are_mutually_exclusive(.res, exclusive_sets)) {
      .res <- sample(options, n, FALSE, weights)
      .attempt <- .attempt + 1
    } else {
      return(.res)
    }
  }

  warning(
    "Could not find non-mutually exclusive items in ",
    .attempt,
    " iterations, returning final attempt."
  )
  return(.res)
}

.items_are_mutually_exclusive <- function(items, mutually_exclusive_item_sets) {
  for (exclusive_set in mutually_exclusive_item_sets) {
    if (sum(items %in% exclusive_set) >= 2) {
      # at least two items are mutually exclusive
      return(TRUE)
    }
  }

  # no matches, we're good
  return(FALSE)
}

get_ability_estimate <- function(con, student_id, start = "", end = "") {
  .tbl <- tbl(con, "Answers")

  # empty start/end will translate to NA values
  .start <- lubridate::as_datetime(start, tz = "UTC")
  .end <- lubridate::as_datetime(end, tz = "UTC")

  # get response by student after start and before end
  .tbl |>
    filter(
      student_id == .env$student_id,
      is.na(.env$.start) || created_at >= .env$.start,
      is.na(.env$.end) || created_at <= .env$.end
    )

  # get irt model and obtain estimate
  # TODO: implement irt model cache
  # TODO: implement estimate routine
  .est <- rnorm(1, 0, 1)

  # normal-ish around 0.4, sd 0.2
  .est_se <- rgamma(1, 4, 10)

  # return estimate
  list(estimate = .est, se_estimate = .est_se, start = .start, end = .end)
}
