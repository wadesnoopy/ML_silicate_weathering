# This file is to predict silw
# 2020-11-12

# clear environment -------------------------------------------------------

rm(list = ls())

library(readr)
library(data.table)
library(ggplot2)
library(tictoc)
library(stringr)
library(sf)

library(RColorBrewer)
library(scales)
library(DataExplorer)

# ML related
library(mlr)
library(MLmetrics) # for R2_score, MSE and RMSE
library(grid) # grob
library(doParallel)
library(parallelMap) # for mlr
library(iml)
library(rstudioapi)
library(rprojroot) # get the current file location (only works with Rscript or source)

run_flag <- "cluster"

if (run_flag == "cluster"){
  current_path <- thisfile()
  setwd(dirname(current_path))
}else{
  current_path <- getActiveDocumentContext()$path
  setwd(dirname(current_path))
}


# source functions --------------------------------------------------------

source("../ml_functions.R")


# count time --------------------------------------------------------------
time_start <- Sys.time()

# read in data ------------------------------------------------------------

element_name <- "alk"

dt <- fread(file.path("..", "input", paste0("ml_", element_name, ".csv")))


# delete variables --------------------------------------------------------

names(dt)

const_delete <- c("MonitoringLocationIdentifier", "lon", "lat", "annual", "spring", "summer", "fall", "winter", "L_water", "U_sediment_water", "R_silicate")

name_total <- str_subset(names(dt), "flo1k|runoff|silw")

name_flo1k <- str_subset(names(dt), "flo1k")

name_runoff <- name_flo1k

# name_runoff <- setdiff(name_total, name_flo1k)

soil_moisture_delete <- str_subset(names(dt), "willmott|terra")

cols_delete <- c(const_delete, name_runoff, soil_moisture_delete)

dt[, (cols_delete) := NULL]


# delete time variables ---------------------------------------------------

time_select <- "annual"

time_par_select <- time_all <- str_subset(names(dt), time_select)

time_par_all <- str_subset(names(dt), "annual|spring|summer|fall|winter")

time_par_delete <- setdiff(time_par_all, time_par_select)

dt[, (time_par_delete) := NULL]

# replace selected time with blank

cols_old <- names(dt)

cols_new <- str_replace(string = cols_old, pattern = paste0("_", time_select), replacement = "")

setnames(dt, old = cols_old, new = cols_new)


# rename independent variables --------------------------------------------
names(dt)

old_name <- c("tavg", "prec", "wind", "vapr", "srad", "pet")

old_moi <- str_subset(names(dt), "moisture")

old_runoff <- str_subset(names(dt), "runoff")

old_name <- c(old_name, old_moi, old_runoff)

new_name <- c("Temperature", "Precipitation", "Wind_speed", "Vapor_pressure", "Solar_radiation", "Potential_evapotranspiration", "Soil_moisture", "Runoff")

setnames(dt, old = old_name, new = new_name)

names(dt)


# rename target variable --------------------------------------------------------

silw_name <- str_subset(names(dt), "silw")

setnames(dt, old = silw_name, new = "Silicate_weathering_flux")

names(dt)


# filter the target variable ----------------------------------------------

# delete NA
dt <- na.omit(dt, c("Silicate_weathering_flux"))

# delete negative value
dt <- dt[Silicate_weathering_flux > 0, ]

sum(is.na(dt$Silicate_weathering_flux))

# first linear

dim(dt)

hist(dt$Silicate_weathering_flux, breaks = 50, main = NULL)

quantile(dt$Silicate_weathering_flux, probs = seq(0, 1, 0.01))

# dt <- dt[Silicate_weathering_flux <= quantile(dt$Silicate_weathering_flux, probs = 0.99),]
# hist(dt$Silicate_weathering_flux, breaks = 50, main = NULL)

dim(dt)

# then log and filter using quantile rule

dt[, Silicate_weathering_flux:= log10(Silicate_weathering_flux)]

hist(dt$Silicate_weathering_flux, breaks = 50, main = NULL)


silw_log_25 <- quantile(dt$Silicate_weathering_flux, probs = 0.25)

silw_log_75 <- quantile(dt$Silicate_weathering_flux, probs = 0.75)

silw_log_diff <- silw_log_75 - silw_log_25

iqd <- 3

silw_log_low <- silw_log_25 - iqd * silw_log_diff

silw_log_high <- silw_log_75 + iqd * silw_log_diff


dt <- dt[Silicate_weathering_flux >= silw_log_low & Silicate_weathering_flux <= silw_log_high, ]

hist(dt$Silicate_weathering_flux, breaks = 50, main = NULL)

dim(dt)


# now we configure scenarios -----------------------------------------------

# ### pristine
# 
# dt <- dt[Population < 10 & L_cultivated_vegetation < 5 & L_urban < 1, ]
# 
# # delete those
# dt[, c("Population", "L_cultivated_vegetation", "L_urban") := NULL]
# 
# # note that the sequence is also changed based on cols_select.
# cols_select <- c(c("Runoff", "Soil_moisture", "Temperature", "Precipitation", "Slope"), str_subset(names(dt), "L_"), str_subset(names(dt), "R_"), "Silicate_weathering_flux")
# 
# 
# # the importance permuatation should automatically take care of the last column of target variable (fixed)
# dt <- dt[, ..cols_select]


# ### runoff
# 
# dt <- dt[, c("Runoff") := NULL]

# ### GUM
# 
# U_cols <- str_subset(names(dt), "U_")
# 
# dt[, (U_cols) := NULL]

# ## landcover
# 
# L_cols <- str_subset(names(dt), "L_")
# 
# dt[, (L_cols) := NULL]



## delete variables

dt[, c("lon_snap", "lat_snap", "ws_area") := NULL]

names(dt)




# make pure dt ---------------------------------------------------------
# note that this should be after filter target variable, as if not using GUM, then the 99% will be different

dt <- na.omit(dt)

dim(dt)


# build the model ---------------------------------------------------------

if (run_flag == "cluster"){
  dt_ml <- copy(dt)

}else{
  dt_ml <- dt[1:50, ] # note that this will be deep copy automatically
}



# create a learner --------------------------------------------------------

ml <- makeLearner("regr.ranger")

# get the learner's parameter
getParamSet(ml)

ml$par.vals

ntree_name <- "num.trees"

nodesize_name <- "min.node.size"

#set tunable parameters
# 6 minutes for 200, 500, 1000, and lower 2 upper 8

if (run_flag == "cluster"){
  # num_threads <- 10
  ml_param <- makeParamSet(
    makeDiscreteParam(ntree_name, values = seq(100, 1000, 50)),
    makeIntegerParam(nodesize_name, lower = 1, upper = 6)
    # makeIntegerParam("num.threads", lower = num_threads, upper = num_threads)
  )
}else{
  # num_threads <- 10
  ml_param <- makeParamSet(
    makeIntegerParam(ntree_name, lower = 50, upper = 100),
    makeIntegerParam(nodesize_name, lower = 1, upper = 3)
    # makeIntegerParam("num.threads", lower = num_threads, upper = num_threads)
    
  )
}




# create train task -------------------------------------------------------


trainTask <- makeRegrTask(data = as.data.frame(dt_ml),
                          target = "Silicate_weathering_flux"
)

# grid search
# tunecontrol <- makeTuneControlGrid()

# random search
if (run_flag == "cluster"){
  tunecontrol <- makeTuneControlGrid()
}else{
  tunecontrol <- makeTuneControlRandom(maxit = 10)
}

# 10-fold cross validation
set_cv <- makeResampleDesc(method = "CV", iters = 10)


#hypertuning
tic("ml training starts...")

# parallel computation
parallelStartSocket(cpus = detectCores() - 1)

ml_tune <- tuneParams(learner = ml,
                      task = trainTask,
                      resampling = set_cv,
                      par.set = ml_param,
                      control = tunecontrol
)


parallelStop()

toc()


cat("the best ml is")

ml_tune

# # plot parameter tuning
# plot_hyper_func(model_tune = ml_tune, 
#                 ntree_name = ntree_name, 
#                 nodesize_name = nodesize_name,
#                 out_path = file.path("output", paste0(time_select, "_hyper-parameters.png")),
#                 width = 4,
#                 height = 4)


# set the best tuned model
ml_best <- setHyperPars(ml, par.vals = ml_tune$x)

# save the model to disk
saveRDS(ml_best, file.path("output", paste0(time_select, "_ml", "_best_model.rds")))

# load the model
ml_best <- readRDS(file.path("output", paste0(time_select, "_ml", "_best_model.rds")))


# do resample -------------------------------------------------------------

# method 1 (automatic)

ml_resample <- mlr::resample(learner = ml_best,
                             task = trainTask,
                             resampling = set_cv)



# R2 and residual on cv ---------------------------------------------------------------------

# get the predictions from resample
dt_cv <- data.frame(pred = as.data.frame(ml_resample$pred)$response,
                       real = as.data.frame(ml_resample$pred)$truth)


cat("The R2 score on test cv dataset is", R2_Score(y_pred = dt_cv$pred,
                                                   y_true = dt_cv$real))


cat("The RMSE on test cv dataset is", RMSE(y_pred = dt_cv$pred,
                                           y_true = dt_cv$real))

cat("The mean residual on test cv dataset is", mean(dt_cv$pred - dt_cv$real))


axis_real_par_name <- "Real silicate weathering flux"

axis_pred_par_name <- "Predicted silicate weathering flux"

plot_r2_func(dt_pred_real = dt_cv,
             out_path = file.path("output", paste0(time_select, "_R2_cv.pdf")),
             width = 4,
             height = 4)


plot_residual_func(dt_pred_real = dt_cv,
                   out_path = file.path("output", paste0(time_select, "_residual_cv.pdf")),
                   width = 4,
                   height = 4)


 # train on total ----------------------------------------------------------

ml_train_total_model <- mlr::train(ml_best, trainTask)

# predict on whole data as baseline
ml_pred_train <- predict(ml_train_total_model,
                         newdata = as.data.frame(dt_ml))



# feature importance ------------------------------------------------------

if (run_flag == "cluster"){
  n_iter <- 100
}else{
  n_iter <- 2
}

# manual
dt_imp_manual <- imp_manual_func(dt_ml, ml_pred_train, ml_train_total_model, n_iter)

# save the shap data.table
fwrite(x = dt_imp_manual, file = file.path("output", paste0(time_select, "_imp_manual.csv")))


# for default
num_pars <- ncol(dt_ml) - 1

# change height
if (num_pars > 30){
  fig_height <- 8
}else if (num_pars > 25){
  fig_height <- 7
}else{
  fig_height <- 4
}


# for manual
plot_imp_func(dt_imp = dt_imp_manual,
              out_path = file.path("output", paste0(time_select, "_importance_manual.pdf")),
              width = 4,
              height = fig_height)



# shap values -------------------------------------------------------------

dt_X <- dt_ml[, -c("Silicate_weathering_flux")]

iml_predictor <- Predictor$new(model = ml_train_total_model,
                               data = as.data.frame(dt_X), # only works on data.frame
                               y = dt_ml$Silicate_weathering_flux)

if (run_flag == "cluster"){
  sample_size <- 100
}else{
  sample_size <- 2
}


# use parallel

tic("foreach shap...")

(no_cores <- detectCores() - 1)

cl <- makeCluster(no_cores)

registerDoParallel(cl)

dt_shap_extract_all <- foreach(i = 1:nrow(dt_X), .packages = c("mlr", "iml", "data.table"), .combine = rbind) %dopar% {
  
  shapley_row <- Shapley$new(predictor=iml_predictor, 
                             x.interest = as.data.frame(dt_X[i,]), 
                             sample.size = sample_size)
  
  
  feature_name <- shapley_row$results$feature
  
  feature_value <- as.data.frame(dt_X[i,])
  
  feature_value[which(sapply(feature_value, is.factor))] <- NA
  
  feature_value <- as.numeric(feature_value)
  
  phi_value <- shapley_row$results$phi
  
  data.table(features = feature_name, 
             feature_value = feature_value, 
             shap = phi_value)
  
  # this will cause error
  # cat(i, "row finished\n")
}


# free your cores
stopCluster(cl)

toc()


# save the shap data.table
fwrite(x = dt_shap_extract_all, file = file.path("output", paste0(time_select, "_shap_scatter.csv")))

# plot whole shap
dt_shap_extract_all[, shap_absolute := abs(shap)]

dt_shap_mean <- dt_shap_extract_all[, .(shap_mean = mean(shap_absolute)), by = features]

dt_shap_mean <- dt_shap_mean[order(-shap_mean), ]

dt_shap_mean

# save the shap data.table
fwrite(x = dt_shap_mean, file = file.path("output", paste0(time_select, "_shap_mean.csv")))

plot_shap_func(dt_shap = dt_shap_mean,
               out_path = file.path("output", paste0(time_select, "_importance_shap.pdf")),
               width = 4,
               height = fig_height)


# Create individual shap
# make the value scale from 0 to 1

dt_shap_scatter <- dt_shap_extract_all
  
dt_shap_scatter[, feature_value_scale := (feature_value - min(feature_value)) / (max(feature_value) - min(feature_value)), by = features]


plot_shap_scatter_func(dt_shap = dt_shap_scatter,
                       out_path = file.path("output", paste0(time_select, "_shap_scatter.pdf")),
                       width = 4,
                       height = fig_height)


# pdp ---------------------------------------------------------------------


# filter out factors and characters

feature_names <- names(dt_X)

feature_names_numeric <- feature_names[sapply(feature_names, function(x) is.numeric(dt_X[[x]]))]

grid_size <- 20

axis_pred_par_center_name <- "Centered predicted silicate weathering flux"


# parallel
tic("foreach pdp...")

# this doesn't increase the speed at all. not sure why

(no_cores <- detectCores() - 1)

cl <- makeCluster(no_cores)

registerDoParallel(cl)

if (run_flag == "cluster"){
  num_feature <- length(feature_names_numeric)
}else{
  num_feature <- 2
}

feature_pdp_all <- foreach(i = 1:num_feature, .packages = c("mlr", "iml", "ggplot2", "scales", "data.table")) %dopar% {
  
  feature_name <- feature_names_numeric[i]
  
  # make sure we have some values to calculate
  if (length(unique(dt_ml[[feature_name]])) != 1){
    pdp_feature = FeatureEffect$new(predictor = iml_predictor,
                                    feature = feature_name,
                                    method = "pdp+ice",
                                    grid.size = grid_size)
    
    # change the center
    pdp_feature$center(min(dt_ml[[feature_name]]))
    
    plot_pdp_single_func
    
    plot_pdp_single_func(feature_name = feature_name,
                         pdp_feature = pdp_feature,
                         axis_pred_par_center_name = axis_pred_par_center_name,
                         out_path = file.path("output", paste0(time_select, "_pdp_single_", feature_name, ".pdf")),
                         width = 4,
                         height = 4)
  }
  
}

# free your cores
stopCluster(cl)

toc()



# end the program ---------------------------------------------------------

Sys.time() - time_start


