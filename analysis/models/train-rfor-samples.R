set.seed(777)

library(sits)

#
# General definitions
#

# Samples
samples_file <- "data/derived/timeseries/samples-cer-v4a-som-clear.rds"

# Output dir
base_output_dir <- "data/derived"

# Model version
model_version <- "rf-cer-v4a-som-clear"


#
# 1. Create output directories
#
model_dir <- file.path(base_output_dir, "models")


#
# 2. Load samples
#
samples_ts <- readRDS(samples_file)


#
# 3. Train model
#
model <- sits_train(
    samples = samples_ts,
    ml_method = sits_rfor()
)


#
# 4. Save model
#
saveRDS(model, file.path(model_dir, paste0(model_version, ".rds")))