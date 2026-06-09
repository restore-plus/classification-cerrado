set.seed(777)

library(glue)
library(sits)

#
# Setup directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
cubes_dir <- file.path(base_dir, "cubes")
samples_dir <- file.path(base_dir, "timeseries")

# Setup versions
samples_version <- "cer-v12b"
samples_file <- file.path(samples_dir, glue("samples-{samples_version}.rds"))
# The data is copied from v12a and then modified below
v12a_file <- file.path(samples_dir, "samples-cer-v12a.rds")

# Replace Mangrove samples by Cerradao
if (!file.exists(samples_file)) {
  v12b <- readRDS(v12a_file)
  v12b$label[v12b$label == "Mangrove"] <- "Cerradao"
  saveRDS(v12b, samples_file)
}
