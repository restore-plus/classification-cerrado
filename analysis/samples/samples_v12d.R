library(glue)

#
# Setup directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
samples_dir <- file.path(base_dir, "timeseries")

#
# Setup versions
#
src_version <- "cer-v12b"
dst_version <- "cer-v12d"

src_file <- file.path(samples_dir, glue("samples-{src_version}.rds"))
dst_file <- file.path(samples_dir, glue("samples-{dst_version}.rds"))

#
# Copy samples
#
stopifnot(file.exists(src_file))

file.copy(
  from = src_file,
  to = dst_file,
  overwrite = TRUE
)
