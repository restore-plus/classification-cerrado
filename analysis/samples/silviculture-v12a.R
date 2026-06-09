library(glue)
library(sits)
library(terra)

# Set terra options for large rasters
terra::terraOptions(memfrac = 0.3, verbose = TRUE)

# Setup versions
samples_version <- "cer-v12a"
n_silviculture <- 50

tc_dir <- "~/classification-cerrado/data/derived/ext-maps/tc/cer/v1"
tc_tif <- file.path(
  tc_dir,
  "tc_30m_cer_2018-01-01_2018-12-31_class_v1.tif"
)
tc_segreg_tif <- file.path(
  tc_dir,
  "tc_30m_cer_2018-01-01_2018-12-31_class_segreg.tif"
)
tc_segregbuffer_tif <- file.path(
  tc_dir,
  "tc_30m_cer_2018-01-01_2018-12-31_class_segregbuffer.tif"
)
samples_dir <- "~/classification-cerrado/data/derived/timeseries"
sample_file <- "new_silviculture_samples.rds"

start_date <- "2017-01-01"
end_date <- "2018-12-31"

legend <- data.frame(
  class = c(9L),
  name = c("Silviculture")
)

tc <- terra::rast(tc_tif)

if (!file.exists(tc_segreg_tif)) {
  tc_segreg <- terra::segregate(
    tc,
    classes = legend$class,
    keep = TRUE,
    other = 0L,
    filename = tc_segreg_tif,
    overwrite = FALSE,
    NAflag = 0L,
    datatype = "INT1U",
    gdal = c(
      "COMPRESS=ZSTD",
      "PREDICTOR=2",
      "BIGTIFF=YES",
      "TILED=YES",
      "BLOCKXSIZE=512",
      "BLOCKYSIZE=512",
      "SPARSE_OK=YES"
    )
  )
} else {
  tc_segreg <- terra::rast(tc_segreg_tif)
}

if (!file.exists(tc_segregbuffer_tif)) {
  tc_segreg_buffer <- terra::focal(
    tc_segreg,
    w = 7L,
    fun = "min",
    na.rm = FALSE,
    na.policy = "omit",
    fillvalue = 0L,
    filename = tc_segregbuffer_tif,
    overwrite = FALSE,
    wopt = list(
      datatype = "INT1U",
      gdal = c(
        "COMPRESS=ZSTD",
        "PREDICTOR=2",
        "BIGTIFF=YES",
        "TILED=YES",
        "BLOCKXSIZE=512",
        "BLOCKYSIZE=512",
        "SPARSE_OK=YES"
      )
    )
  )
} else {
  tc_segreg_buffer <- terra::rast(tc_segregbuffer_tif)
}

set.seed(777)

samples_lst <- lapply(seq_len(terra::nlyr(tc_segreg_buffer)), function(i) {
  samples <- as.data.frame(terra::spatSample(
    tc_segreg_buffer[[i]],
    size = n_silviculture * 5,
    method = "random",
    replace = FALSE,
    na.rm = TRUE,
    as.raster = FALSE,
    as.df = FALSE,
    as.points = TRUE,
    values = FALSE,
    cells = FALSE,
    xy = TRUE,
    exhaustive = TRUE
  ))
  samples$label <- legend$name[i]
  samples
})

samples <- dplyr::bind_rows(samples_lst)
samples <- terra::vect(samples, geom = c("x", "y"), crs = terra::crs(tc_segreg_buffer))

# ---- select samples in silviculture class in v11a map ----

v11a_dir <- "~/classification-cerrado/data/derived/classifications/tempcnn-cer-v11a-raster/2018/mosaic"
v11a_file <- file.path(
  v11a_dir,
  "LANDSAT_OLI_MOSAIC_2017-01-01_2018-12-01_class_tempcnn-cer-v11a-raster.tif"
)

v11a <- terra::rast(v11a_file)
names(v11a) <- "v11a"

samples <- terra::extract(v11a, samples, bind = TRUE)

legend2 <- data.frame(
  class = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
  name = c("Annual_Crop", "Cerradao", "Cerrado", "Nat_NonVeg", "Open_Cerrado", "Pasture", "Perennial_Crop", "Silviculture", "Sugarcane", "Water")
)

samples <- samples[samples$v11a == 8, ] # select silviculture class
samples$v11a <- NULL

# ---- prepare samples for sits ----

samples <- terra::project(samples, "EPSG:4326")
samples <- data.frame(
  as.data.frame(terra::crds(samples)),
  start_date = start_date,
  end_date = end_date,
  as.data.frame(samples)
)
names(samples) <- c("longitude", "latitude", "start_date", "end_date", "label")
samples <- samples[sample(nrow(samples), n_silviculture), ]

write.csv(samples, file.path(samples_dir, glue("samples-silviculture-{samples_version}.csv")), row.names = FALSE)
