set.seed(777)

library(glue)
library(sits)

#
# Tiles of Cerrado
#
cerrado_tiles <- c(
  "007009", "008009", "008010", "009009", "009010", "009011", "009013", "009014",
  "010009", "010010", "010011", "010012", "010013", "010014", "010015", "011009",
  "011010", "011011", "011012", "011013", "011014", "011015", "012008", "012009",
  "012010", "012011", "012012", "012013", "012014", "012015", "013006", "013007",
  "013008", "013009", "013010", "013011", "013012", "013013", "013014", "013015",
  "014005", "014006", "014007", "014008", "014009", "014010", "014011", "014012",
  "014013", "014014", "014015", "015005", "015006", "015007", "015008", "015009",
  "015010", "015011", "015012", "015013", "015014", "016004", "016005", "016006",
  "016007", "016008", "016009", "016010", "016011", "016012", "016013", "017004",
  "017005", "017006", "017007", "017010", "017011"
)

#
# Setup directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
cubes_dir <- file.path(base_dir, "cubes")
samples_dir <- file.path(base_dir, "timeseries")

# Setup versions
samples_version <- "cer-v11a"
model_version <- glue("tempcnn-{samples_version}")
raster_version <- "raster"
version <- glue("{model_version}-{raster_version}")

# Hardware
multicores <- 32L
memsize <- 128

# Setup parallel cluster
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

# Define processing chunks
chunk_size <- length(cerrado_tiles)
tiles <- split(cerrado_tiles, ceiling(seq_along(cerrado_tiles) / chunk_size))

# Load samples
samples_file <- file.path(samples_dir, glue("samples-{samples_version}.rds"))
samples <- readRDS(samples_file)
uncert_file <- file.path(samples_dir, glue("high_uncert-{samples_version}.rds"))

# Get labels
labels <- sits_labels(samples)
names(labels) <- seq_along(labels)

# Setup year
year <- 2018
tile_chunk <- tiles[[1]]

classifications_dir <- file.path(base_dir, "classifications", paste0(model_version, "-raster"), year)

message("- loading cube")
cube_bayes <- sits_cube(
  source = "BDC",
  collection = "LANDSAT-OLI-16D",
  data_dir = classifications_dir,
  tiles = tile_chunk,
  bands = "bayes",
  labels = labels,
  version = version
)

# Calculate the uncertainty cube
message("- uncertainty cube")
cube_uncert <- sits_uncertainty(
  cube = cube_bayes,
  type = "margin",
  multicores = multicores,
  memsize = memsize,
  output_dir = classifications_dir,
  version = version,
  progress = TRUE
)

# Find samples with high uncertainty
message("- finding samples")
new_samples <- sits_uncertainty_sampling(
  uncert_cube = cube_uncert,
  n = 2000,
  min_uncert = 0.20,
  max_uncert = 0.80,
  sampling_window = 10,
  multicores = multicores,
  memsize = 2,
  progress = TRUE
)

saveRDS(new_samples, uncert_file)
