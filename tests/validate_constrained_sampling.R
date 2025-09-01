library(tidyverse)

source("functions/sql_get_responses.R")


bank_sizes <- c(100, 250, 500)
set_sizes <- c(2, 5, 10) # number of items in each exclusive set
set_counts <- c(1, 5, 10, 50) # number of exclusive sets
sample_sizes <- 2
n_questions_options <- c(5, 10, 20)
n_students_options <- c(100, 1000, 3000)

iterations_per_scenario <- 10

# create a table of scenarios, where each row is a
# unique combination of settings (and iteration).
scenarios <- expand_grid(
  bank_size = bank_sizes,
  set_size = set_sizes,
  set_count = set_counts,
  sample_size = sample_sizes,
  iteration = 1:iterations_per_scenario,
  n_questions = n_questions_options,
  n_students = n_students_options
) |>
  # we already know some combinations of settings are simply impossible
  filter(
    (bank_size - set_count * (set_size - 1)) > (sample_size * n_questions)
  )


# runner function does the brunt of the work
# note that this should be easily parralizable
run_scenario <- function(
  bank_size,
  set_size,
  set_count,
  sample_size,
  iteration,
  n_questions,
  n_students
) {
  # create exclusive sets
  .x_items = sample(bank_size, set_size * set_count)
  .x_sets = list()
  .x_set_indices = rep(1:set_count, each = set_size)

  for (j in 1:set_count) {
    .x_sets[[j]] = .x_items[.x_set_indices == j]
  }

  # keep track of exposed items
  # initialize item exposure table to simplify logic
  #  - makes sure all items are included
  #  - solves division by zero for non-exposed items
  exposure <- rep(1, bank_size)
  weights <- rep(1, bank_size)
  students <- 1:n_students
  items <- 1:bank_size

  for (s in students) {
    # each student can only see an item once
    # note that for this simulation we don't care about
    # the responses, only exposure. This is fine, we don't
    # have item parameters yet in the pilot anyway.
    available <- rep(TRUE, bank_size)

    # expose the student to questions
    for (q in 1:n_questions) {
      sampled_items <- .constrained_sample(
        items[available],
        weights[available],
        sample_size,
        .x_sets
      )

      # we assume the user randomly selects an item to take
      # if presented with multiple items.
      if (sample_size > 1) {
        final_item <- sample(sampled_items, 1)
      } else {
        # Note that we can't simply sample from a length-1
        # options vector, because `sample()` will erroneously
        # assume the index of the remaining option is instead
        # the number of allowed options.
        final_item <- sampled_items
      }

      # update state
      available[final_item] <- FALSE
      exposure[final_item] <- exposure[final_item] + 1
      weights[final_item] <- 1 / exposure[final_item]
    }
  }

  result <- tibble(
    items,
    exposure,
    constrained = items %in% .x_items
  )
  result$exclusive_set <- integer(bank_size)
  result$exclusive_set[.x_items] <- .x_set_indices

  tibble_row(
    bank_size = bank_size,
    set_size = set_size,
    set_count = set_count,
    sample_size = sample_size,
    iteration = iteration,
    n_questions = n_questions,
    n_students = n_students,
    result = list(result)
  )
}

library(furrr)
library(future)
future::plan(future::multisession)

sim_results <- furrr::future_pmap(
  scenarios,
  run_scenario,
  .options = furrr_options(seed = TRUE),
  .progress = TRUE
) |>
  list_rbind()

scenarios |>
  bind_cols(sim_results |> select(result)) |>
  rowwise() |>
  mutate(
    summary = list(
      result |>
        mutate(exposure_normalized = exposure / mean(exposure)) |>
        summarize(
          avg_exposure = mean(exposure_normalized),
          sd_exposure = sd(exposure_normalized),
          min_exposure = min(exposure_normalized),
          max_exposure = max(exposure_normalized),
          .by = constrained
        )
    )
  ) |>
  unnest(summary) -> sim_summaries

sim_summaries |>
  group_by(
    constrained,
    sample_size
  ) |>
  summarize(across(avg_exposure:max_exposure, mean))

sim_results$result[[12]] |>
  ggplot(aes(
    x = items,
    y = exposure,
    colour = constrained,
    fill = factor(exclusive_set)
  )) +
  geom_col()
