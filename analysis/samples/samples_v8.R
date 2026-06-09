library(sits)

v4a_som_clean <- readRDS("~/classification-cerrado/data/derived/timeseries/samples-cer-v4a-som-clear.rds")
som_v4a_5x5 <- readRDS("~/r+/som_v4a_5x5.rds")

som_out <- dplyr::filter(som_v4a_5x5$data, id_neuron %in% c(16, 21, 25))

samples_v8 <- dplyr::anti_join(v4a_som_clean, som_out, by = c("longitude", "latitude"))

saveRDS(samples_v8, "~/classification-cerrado/data/derived/timeseries/samples-cer-v8.rds")

# simoes <- readRDS(url("https://github.com/restore-plus/classification-cerrado/raw/refs/heads/main/data/derived/timeseries/samples-simoes-original-complete.rds"))
#
# summary(simoes)
# som_simoes_40x40 <- sits::sits_som_map(
#     data = simoes,
#     grid_xdim = 40,
#     grid_ydim = 40,
#     alpha = 1,
#     rlen = 100,
#     distance = "dtw",
#     som_radius = 2,
#     mode = "batch"
# )
# saveRDS(som_simoes_40x40, "som_simoes_40x40.rds")
#
# natveg <- readRDS(url("https://github.com/restore-plus/classification-cerrado/raw/refs/heads/main/data/derived/timeseries/samples-simoes-natveg-complete.rds"))
# summary(natveg)
#
# jobs <- list(
#     list(samples = natveg, res = 20),
#     list(samples = natveg, res = 30),
#     list(samples = natveg, res = 40)
# )
#
# mirai::daemons(0)
#
# som_lst <- jobs |>
#     stream(function(job) {
#         library(sits)
#
#         samples <- job$samples
#         res <- job$res
#         sits::sits_som_map(
#             data = samples,
#             grid_xdim = res,
#             grid_ydim = res,
#             alpha = 1,
#             rlen = 100,
#             distance = "dtw",
#             som_radius = 2,
#             mode = "batch"
#         )
#     }, backend = mirai_backend()) |>
#     stream_run(1000)
#
# library(sits)
#
# som_simoes_40x40 <- readRDS("som_simoes_40x40.rds")
# som_natveg_40x40 <- readRDS("som_natveg_40x40.rds")
#
# legend <- tibble::tribble(
#     ~name,                                             ~color,
#     "Annual_Crop",                                     "#ffab00",
#     "Campo Natural (Campo Limpo)",                     "#0afb50",
#     "Campo Natural (Campo Rupestre)",                  "#9aff90",
#     "Campo Natural (Campo Sujo)",                      "#00bb20",
#     "Corpos d'Água",                                   "#1111bb",
#     "Floresta",                                        "#007700",
#     "Floresta (Savana-Estépica Florestada)",           "#888800",
#     "Formações Arenosas",                              "#ddab88",
#     "Pasture",                                         "#ffff00",
#     "Perennial_Crop",                                  "#993400",
#     "Silviculture",                                    "#117766",
#     "Sugarcane",                                       "#ab6096",
#     "Vegetação Natural (Babaçual)",                    "#80ff00",
#     "Vegetação Natural (Cerrado Denso)",               "#80ff00",
#     "Vegetação Natural (Cerrado Ralo)",                "#80ff00",
#     "Vegetação Natural (Cerrado Rupestre)",            "#80ff00",
#     "Vegetação Natural (Cerrado Típico)",              "#80ff00",
#     "Vegetação Natural (Parque de Cerrado)",           "#80ff00",
#     "Vegetação Natural (Savana-Estépica Arborizada)",  "#80ff00",
#     "Vegetação Natural (Vereda)",                      "#80ff00",
#     "No_Samples",                                      "#ababab"
# )
#
# plot(som_simoes_40x40, band = "NDVI", legend = legend)
# plot(som_natveg_40x40, band = "NDVI", legend = legend)
#
# plot(sits_som_evaluate_cluster(som_simoes_40x40), legend = legend)
# plot(sits_som_evaluate_cluster(som_natveg_40x40), legend = legend)
#
# nrow(som_simoes_40x40$labelled_neurons)
