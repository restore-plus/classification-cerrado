library(glue)
library(sits)
library(terra)

# Set terra options for large rasters
terra::terraOptions(memfrac = 0.3, verbose = TRUE)

# Setup versions
samples_version <- "cer-v12a"
n_mangrove <- 200

natveg_dir <- "~/classification-cerrado/data/derived/ext-maps/natveg/cer/v2"
natveg_tif <- file.path(
  natveg_dir,
  "natveg_30m_cer_2018-01-01_2018-12-31_class_v2.tif"
)
natveg_segreg_tif <- file.path(
  natveg_dir,
  "natveg_30m_cer_2018-01-01_2018-12-31_class_segreg.tif"
)
natveg_segregbuffer_tif <- file.path(
  natveg_dir,
  "natveg_30m_cer_2018-01-01_2018-12-31_class_segregbuffer.tif"
)
samples_dir <- "~/classification-cerrado/data/derived/timeseries"
sample_file <- "new_mangrove_samples.rds"

start_date <- "2017-01-01"
end_date <- "2018-12-31"

legend <- data.frame(
  class = c(39L),
  name = c("Mangrove")
)

natveg <- terra::rast(natveg_tif)

if (!file.exists(natveg_segreg_tif)) {
  natveg_segreg <- terra::segregate(
    natveg,
    classes = legend$class,
    keep = TRUE,
    other = 0L,
    filename = natveg_segreg_tif,
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
  natveg_segreg <- terra::rast(natveg_segreg_tif)
}

if (!file.exists(natveg_segregbuffer_tif)) {
  natveg_segreg_buffer <- terra::focal(
    natveg_segreg,
    w = 7L,
    fun = "min",
    na.rm = FALSE,
    na.policy = "omit",
    fillvalue = 0L,
    filename = natveg_segregbuffer_tif,
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
  natveg_segreg_buffer <- terra::rast(natveg_segregbuffer_tif)
}

set.seed(777)

samples_lst <- lapply(seq_len(terra::nlyr(natveg_segreg_buffer)), function(i) {
  samples <- as.data.frame(terra::spatSample(
    natveg_segreg_buffer[[i]],
    size = n_mangrove * 5,
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
samples <- terra::vect(samples, geom = c("x", "y"), crs = terra::crs(natveg_segreg_buffer))

# ---- filter samples in water class in v11a map ----

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

samples <- samples[samples$v11a != 10, ] # remove water class
samples <- samples[samples$v11a != 4, ] # remove nat_nonveg class
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
samples <- samples[sample(nrow(samples), n_mangrove), ]

write.csv(samples, file.path(samples_dir, glue("samples-mangrove-{samples_version}.csv")), row.names = FALSE)
