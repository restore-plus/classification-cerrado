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

year <- 2018

cube_y1_dir <- file.path(cubes_dir, as.character(year - 1))
cube_y2_dir <- file.path(cubes_dir, as.character(year))

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

v8 <- readRDS("~/classification-cerrado/data/derived/timeseries/samples-cer-v8.rds")
v10b <- sits_reduce_imbalance(
    v8,
    n_samples_over = 200L,
    n_samples_under = 1000L
)
summary(v10b)

v10a <- v8
v10a$start_date <- as.Date("2017-01-01")


# Setup parallel cluster
memsize <- 256
multicores <- 64L
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

v10b <- sits_get_data(
    cube = cube_y2,
    samples = v10b[v10b$label == "Perennial_Crop", ]
)

saveRDS(v10b, "~/classification-cerrado/data/derived/timeseries/samples-cer-v10b.rds")



v10a <- sits_get_data(
    cube = cube_2y,
    samples = v10a
)

saveRDS(v10a, "~/classification-cerrado/data/derived/timeseries/samples-cer-v10a.rds")





library(parallel)
library(dplyr)
library(sits)

# workers conservadores
n_workers <- 30L
cl <- makeCluster(n_workers)

clusterEvalQ(cl, {
    library(sits)
    library(dplyr)
})

clusterExport(cl, varlist = c("cube", "v4a_som_clean"), envir = environment())

# blocos iniciais
chunk_size <- 500
idx_chunks <- split(
    seq_len(nrow(v8)),
    ceiling(seq_len(nrow(v8)) / chunk_size)
)

safe_get_data <- function(idx) {
    x <- v8[idx, , drop = FALSE]

    tryCatch(
        {
            out <- sits_get_data(
                cube = cube,
                samples = x,
                multicores = 1,
                progress = FALSE
            )
            list(ok = TRUE, result = out, failed = NULL)
        },
        error = function(e_chunk) {
            # fallback: tenta linha a linha
            row_res <- lapply(idx, function(i) {
                xi <- v8[i, , drop = FALSE]

                tryCatch(
                    {
                        outi <- sits_get_data(
                            cube = cube,
                            samples = xi,
                            multicores = 1,
                            progress = FALSE
                        )
                        list(ok = TRUE, result = outi, failed = NULL)
                    },
                    error = function(e_row) {
                        list(
                            ok = FALSE,
                            result = NULL,
                            failed = data.frame(
                                row_id = i,
                                longitude = xi$longitude,
                                latitude = xi$latitude,
                                start_date = xi$start_date,
                                end_date = xi$end_date,
                                label = xi$label,
                                error = conditionMessage(e_row),
                                stringsAsFactors = FALSE
                            )
                        )
                    }
                )
            })

            ok_rows <- Filter(function(z) isTRUE(z$ok), row_res)
            bad_rows <- Filter(function(z) !isTRUE(z$ok), row_res)

            list(
                ok = length(bad_rows) == 0,
                result = if (length(ok_rows) > 0) bind_rows(lapply(ok_rows, `[[`, "result")) else NULL,
                failed = if (length(bad_rows) > 0) bind_rows(lapply(bad_rows, `[[`, "failed")) else NULL
            )
        }
    )
}

res <- clusterApplyLB(cl, idx_chunks, safe_get_data)

stopCluster(cl)

samples_2017 <- bind_rows(lapply(res, `[[`, "result"))

samples_to_bind <- samples_2017

samples_to_bind$start_date <- as.Date("2017-01-01")
samples_to_bind$end_date <- as.Date("2017-12-31")

samples_2y <- dplyr::inner_join(
    v8,
    samples_to_bind,
    by = c(
        "longitude", "latitude",
        "start_date", "end_date",
        "cube"
    )
)

samples_2y_ts <- samples_2y |>
    dplyr::transmute(
        longitude,
        latitude,
        start_date = as.Date("2017-01-01"),
        end_date = as.Date("2018-12-31"),
        label = label.x,
        cube,
        time_series.x,
        time_series.y
    )

samples_2y_ts$time_series <- purrr::map2(
    samples_2y_ts$time_series.x,
    samples_2y_ts$time_series.y,
    function(x, y) {
        dplyr::bind_rows(y, x)
    }
)

samples_2y_final <- samples_2y_ts |>
    dplyr::transmute(
        longitude,
        latitude,
        start_date,
        end_date,
        label,
        cube,
        time_series
    )


samples_2y_final

saveRDS(samples_2y_final, "data/derived/timeseries/samples-cer-v9a.rds")

v4a_som_clean_2y <- readRDS("data/derived/timeseries/samples-cer-v9a.rds")

v9a <- readRDS("data/derived/timeseries/samples-cer-v9a.rds")

summary(v9a)

plot(sits::sits_select(v9a, bands = "NDVI"))

plot(sits::sits_patterns(v9a))


##########################################


failed_points <- bind_rows(
    lapply(res, function(x) x$failed)
)

library(sf)

failed_sf <- st_as_sf(
    failed_points,
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
)

st_write(
    failed_sf,
    "failed_points.gpkg",
    layer = "failed_points",
    delete_layer = TRUE
)

# opcional
n_ok <- nrow(samples_2017)
n_fail <- nrow(failed_points)

print(n_ok)
print(n_fail)


##########################################
library(sits)

sits_parsitssits_parallel()

v4a_som_clean <- readRDS("data/derived/timeseries/samples-cer-v4a-som-clear.rds")

v9b <- sits_reduce_imbalance(v4a_som_clean, n_samples_over = 200L, n_samples_under = 1000L)
v9b$label_samples <- NULL

saveRDS(v9b, "data/derived/timeseries/samples-cer-v9b.rds")
v9b <- readRDS("data/derived/timeseries/samples-cer-v9b.rds")


summary(v9b)

plot(sits::sits_select(v9b, bands = "NDVI"))

plot(sits::sits_patterns(v9b))


v8 <- readRDS("data/derived/timeseries/samples-cer-v8.rds")

summary(v8)
