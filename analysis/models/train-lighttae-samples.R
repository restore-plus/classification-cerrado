set.seed(777)

library(sits)
library(restoreutils)

#
# General definitions
#
processing_context <- "coids::rolf::cerrado"

# Samples
samples_file <- "data/derived/timeseries/samples-cer-v4a-complete.rds"

# Output dir
base_output_dir <- "data/derived/"

# Model version
model_version <- "ltae-cer-v4a"


#
# 1. Create output directories
#
restoreutils::notify(
  processing_context, paste("train model > started >", model_version)
)

model_dir <- restoreutils::create_data_dir(base_output_dir, "models")

tryCatch({
  if (!file.exists(model_dir / paste0(model_version, ".rds"))) {
    #
    # 2. Load samples
    #
    samples_ts <- readRDS(samples_file)
    
    
    #
    # 3. Train model
    #
    model <- sits_train(
      samples = samples_ts,
      ml_method = sits_lighttae()
    )
    
    
    #
    # 4. Save model
    #
    saveRDS(model, model_dir / paste0(model_version, ".rds"))
  }
  #
  # 5. Cross-validation
  #
  acc_model <- sits_kfold_validate(
    samples_ts,
    folds = 5L,
    ml_method = sits_lighttae(),
    multicores = multicores,
    progress = TRUE
  )
  
  #
  # 6. Save cross-validation
  #
  saveRDS(acc_model, model_dir / paste0(model_version, "_acc.rds"))

}, error = function(e) {
  restoreutils::notify(
    processing_context, paste("train model > error >", conditionMessage(e))
  )
})

restoreutils::notify(
  processing_context, paste("train model > finished >", model_version)
)
