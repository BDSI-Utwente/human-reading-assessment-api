get_exposure_per_question <- function() {
  tryCatch(
    {
      dotenv::load_dot_env(".env")
      con <- create_db_connection()
      tbl_answers <- tbl(con, "Answers")
      texts <- get_question_titles()

      responses <- tbl_answers |>
        distinct(student_id, sanity_text_id) |>
        count(sanity_text_id) |>
        collect()

      left_join(responses, texts, by = "sanity_text_id") |>
        mutate(pct = n / sum(n)) |>
        arrange(desc(pct))
    },
    finally = {
      DBI::dbDisconnect(con)
    }
  )
}

get_student_text_answers <- function() {
  tryCatch(
    {
      dotenv::load_dot_env(".env")
      con <- create_db_connection()
      tbl_answers <- tbl(con, "Answers")
      texts <- get_question_titles()

      responses <- tbl_answers |>
        distinct(student_id, sanity_text_id, .keep_all = TRUE) |>
        select(student_id, created_at, sanity_text_id) |>
        collect()

      right_join(responses, texts, by = "sanity_text_id") |>
        arrange(created_at)
    },
    finally = {
      DBI::dbDisconnect(con)
    }
  )
}

write_csv(get_exposure_per_question(), "exposure.csv")
write_csv(get_student_text_answers(), "responses.csv")
