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
samples_version <- "cer-v10a"
samples_file <- file.path(samples_dir, glue("samples-{samples_version}.rds"))

# Setup parallel cluster
multicores <- 77
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

if (!file.exists(samples_file)) {
  message("- loading cube")

  cube_y1_dir <- file.path(cubes_dir, "2017")
  cube_y2_dir <- file.path(cubes_dir, "2018")
  cube_y1 <- sits_cube(
    source     = "BDC",
    collection = "LANDSAT-OLI-16D",
    tiles      = cerrado_tiles,
    data_dir   = cube_y1_dir,
    progress   = FALSE
  )
  cube_y2 <- sits_cube(
    source     = "BDC",
    collection = "LANDSAT-OLI-16D",
    tiles      = cerrado_tiles,
    data_dir   = cube_y2_dir,
    progress   = FALSE
  )
  cube_2y <- sits_merge(cube_y1, cube_y2)

  message("- extract ts")
  v10a <- readRDS(file.path(samples_dir, "samples-cer-v8.rds"))
  v10a$start_date <- as.Date("2017-01-01")
  v10a <- sits_get_data(
    cube = cube_2y,
    samples = v10a,
    multicores = multicores
  )

  saveRDS(v10a, samples_file)
}
