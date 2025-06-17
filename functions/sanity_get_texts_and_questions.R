library(httr2)
library(tidyverse)


get_question_metadata <- function(
    token = Sys.getenv("SANITY_TOKEN"),
    project_id = Sys.getenv("SANITY_PROJECT_ID")) {
  query_url <- glue::glue(
    "https://{project_id}.api.sanity.io/v2025-06-03/data/query/production"
  )

  response <- httr2::request(query_url) |>
    req_auth_bearer_token(Sys.getenv("SANITY_TOKEN")) |>
    req_url_query(
      query = "*[_type == \"testItem\"]{_id, questions[]}"
    ) |>
    req_perform()

  questions <- response |>
    resp_body_json() |>
    pluck("result") |>
    # attach item._id to each question, and return only questions
    map(\(item) {
      .item_id <- item$`_id`
      item$questions |>
        map(\(q) {
          q$item_id <- .item_id
          q
        })
    }) |>
    list_flatten()

  question_data <- questions |>
    map(extract_question_metadata) |>
    list_rbind()

  question_data
}


extract_question_metadata <- function(q) {
  # basic info
  .extract_question_info <- function(q) {
    tibble_row(
      item_id = q$item_id,
      question_id = q$`_key`,
      type = q$type
    )
  }

  # ability questions
  .extract_multi_choice <- function(q) {
    .answers <- q$answers |>
      map(\(a) tibble_row(answer_id = a$`_key`, correct = a$isCorrect)) |>
      list_rbind()

    .extract_question_info(q) |>
      mutate(answers = list(.answers), scale = "ability")
  }
  # checkboxes is identical to multiChoice, it just allows multiple answers to be correct
  .extract_checkboxes <- .extract_multi_choice
  .extract_freetext <- function(q) {
    .extract_question_info(q) |>
      mutate(scale = "ability")
  }
  # trueOrFalse is actually identical to checkboxes, and also appears to allows multiple binary statements
  .extract_true_or_false <- .extract_checkboxes

  # feedback all seems to have identical scales and tags, nothing interesting to extract?
  .extract_feedback <- function(q) {
    .extract_question_info(q) |>
      mutate(scale = "preference")
  }

  if (q$type == "multiChoice") {
    return(.extract_multi_choice(q))
  } else if (q$type == "checkboxes") {
    return(.extract_checkboxes(q))
  } else if (q$type == "trueOrFalse") {
    return(.extract_true_or_false(q))
  } else if (q$type == "freeText") {
    return(.extract_freetext(q))
  } else if (
    q$type %in% c("scaleFeedback", "freeTextFeedback", "tagsFeedback")
  ) {
    return(.extract_feedback(q))
  } else {
    stop("unknown question type", q$type)
  }
}
