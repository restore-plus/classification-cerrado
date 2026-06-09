set.seed(777)

library(sits)

#
# Tiles of Cerrado
#
# cerrado_tiles <- c(
#     "007009", "008009", "008010", "009009", "009010", "009011", "009013", "009014",
#     "010009", "010010", "010011", "010012", "010013", "010014", "010015", "011009",
#     "011010", "011011", "011012", "011013", "011014", "011015", "012008", "012009",
#     "012010", "012011", "012012", "012013", "012014", "012015", "013006", "013007",
#     "013008", "013009", "013010", "013011", "013012", "013013", "013014", "013015",
#     "014005", "014006", "014007", "014008", "014009", "014010", "014011", "014012",
#     "014013", "014014", "014015", "015005", "015006", "015007", "015008", "015009",
#     "015010", "015011", "015012", "015013", "015014", "016004", "016005", "016006",
#     "016007", "016008", "016009", "016010", "016011", "016012", "016013", "017004",
#     "017005", "017006", "017007", "017010", "017011"
# )
cerrado_tiles <- c("011012")
#
# Setup output directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
cubes_dir <- file.path(base_dir, "cubes")
dir.create(cubes_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(cubes_dir))

# Setup cube
cube_bands <- c("BLUE", "GREEN", "RED", "NIR08", "SWIR16", "SWIR22", "CLOUD")
years <- c(2017) # ou 2015:2022

# Setup parallel cluster
memsize <- 128
multicores <- 32L
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

# Define processing chunks
chunk_size <- 8L
tiles <- split(cerrado_tiles, ceiling(seq_along(cerrado_tiles) / chunk_size))

#
# Year loop
#
for (year in years) {
  # Output dir for this year
  output_dir <- file.path(cubes_dir, as.character(year))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(dir.exists(output_dir))

  # Dates
  start_date <- sprintf("%d-01-01", year)
  end_date <- sprintf("%d-12-31", year)

  # Monthly timeline (P1M)
  timeline <- as.Date(sprintf("%d-%02d-01", year, 1:12))

  # Chunk-of-tiles: sits will resume using output_dir
  for (tile_chunk in tiles) {
    message("Year ", year, " | tile(s) ", paste(tile_chunk, collapse = ", "))

    # Load cube
    cube <- sits_cube(
      source     = "BDC",
      collection = "LANDSAT-OLI-16D",
      tiles      = tile_chunk,
      start_date = start_date,
      end_date   = end_date,
      bands      = cube_bands,
      progress   = FALSE
    )

    message("- regularizing")
    cube_reg <- sits_regularize(
      cube       = cube,
      period     = "P1M",
      res        = 30,
      multicores = multicores,
      output_dir = output_dir,
      timeline   = timeline
    )

    message("- creating indices")
    # Generate NDVI
    cube_reg <- sits_apply(
      data       = cube_reg,
      NDVI       = (NIR08 - RED) / (NIR08 + RED),
      output_dir = output_dir,
      multicores = multicores,
      memsize    = memsize,
      progress   = TRUE
    )

    # Generate EVI (https://www.usgs.gov/landsat-missions/landsat-enhanced-vegetation-index)
    cube_reg <- sits_apply(
      data       = cube_reg,
      EVI        = 2.5 * ((NIR08 - RED) / (NIR08 + 6 * RED - 7.5 * BLUE + 1)),
      output_dir = output_dir,
      multicores = multicores,
      memsize    = memsize,
      progress   = TRUE
    )

    # Generate MNDWI
    cube_reg <- sits_apply(
      data       = cube_reg,
      MNDWI      = (GREEN - SWIR16) / (GREEN + SWIR16),
      output_dir = output_dir,
      multicores = multicores,
      memsize    = memsize,
      progress   = TRUE
    )

    # Generate NBR (https://www.usgs.gov/landsat-missions/landsat-normalized-burn-ratio)
    cube_reg <- sits::sits_apply(
      data       = cube_reg,
      NBR        = (NIR08 - SWIR22) / (NIR08 + SWIR22),
      output_dir = output_dir,
      multicores = multicores,
      memsize    = memsize,
      progress   = TRUE
    )
  }
}
