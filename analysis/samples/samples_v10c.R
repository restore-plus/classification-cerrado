set.seed(777)

library(glue)
library(sits)

#
# Setup directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
samples_dir <- file.path(base_dir, "timeseries")

# Setup versions
samples_version <- "cer-v10c"
samples_file <- file.path(samples_dir, glue("samples-{samples_version}.rds"))

# Setup parallel cluster
multicores <- 10
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

if (!file.exists(samples_file)) {
  message("- balance samples")
  v10c <- sits_reduce_imbalance(
    readRDS(file.path(samples_dir, "samples-cer-v8.rds")),
    n_samples_over = 200L,
    n_samples_under = 3000L
  )
  v10c$label_samples <- NULL
  saveRDS(v10c, samples_file)
}
