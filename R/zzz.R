
#-----------------------------------------------------------------------------
# Global State Vars (can be controlled globally with options(stremr.optname = ))
#-----------------------------------------------------------------------------
gvars <- new.env(parent = emptyenv())
gvars$verbose <- FALSE      # verbose mode (print all messages)
gvars$opts <- list()        # named list of package options that is controllable by the user (set_all_stremr_options())
gvars$misval <- NA_integer_ # the default missing value for observations (# gvars$misval <- -.Machine$integer.max)
gvars$misXreplace <- 0L     # the default replacement value for misval that appear in the design matrix
gvars$tolerr <- 10^-12      # tolerance error: assume for abs(a-b) < gvars$tolerr => a = b
gvars$sVartypes <- list(bin = "binary", cat = "categor", cont = "contin")
gvars$noCENScat <- 0L       # the reference category that designates continuation of follow-up

# allowed.fit_package <- c("speedglm", "glm", "h2o", "xgboost")
# allowed.fit_algorithm <- c("glm", "gbm", "randomForest", "drf", "deeplearning")

gvars$opts.allowedVals <- list(estimator = c("speedglm__glm", "glm__glm",
                                             "xgboost__glm", "xgboost__gbm", "xgboost__randomForest",
                                             "h2o__glm", "h2o__gbm", "h2o__randomForest", "h2o__deeplearning"),
                               fit_method = c("none", "cv"), # holdout
                               fold_column = "_character_",
                               bin_method = c("equal.mass", "equal.len", "dhist"),
                               nbins = "_positive_integer_",
                               maxncats = "_positive_integer_",
                               maxNperBin = "_positive_integer_",
                               lower_bound_zero_Q = c(TRUE, FALSE),
                               skip_update_zero_Q = c(TRUE, FALSE),
                               up_trunc_offset = "_numeric_",
                               low_trunc_offset = "_numeric_",
                               eps_tol = "_numeric_"
  )

getopt <- function(optname) return(stremrOptions(o = optname))

#' Querying/setting a single \code{stremr} option
#'
#' To list all \code{stremr} options, just run this function without any parameters provided.
#' To query only one value, pass the first parameter. To set that, use the \code{value} parameter.
#' To see the available range of values or the required type for a specific option, use the flag \code{showvals = TRUE}.
#'
#' The signature of the function \code{\link{set_all_stremr_options}} also lists all available \code{stremr} options.
#'
#' @param o Option name (string). See \code{\link{set_all_stremr_options}}.
#' @param value Value to assign (optional)
#' @param showvals Set to \code{TRUE} (optional) to show the possible range of values or the required type for a specific option name.
#' @export
#' @seealso \code{\link{set_all_stremr_options}}
#' @examples \dontrun{
#' stremrOptions()
#' stremrOptions('estimator')
#' stremrOptions('estimator', showvals = TRUE)
#' stremrOptions('estimator', 'xgboost__gbm')
#' stremrOptions('fit_method', 'cv')
#' }
stremrOptions <- function (o, value, showvals = FALSE)  {
  res <- getOption("stremr")
  allowedVals <- gvars[["opts.allowedVals"]]

  if (missing(value)) {
    if (missing(o)) return(res)
    if (o %in% names(res)) {
      if (!showvals) return(res[[o]]) else return(allowedVals[[o]])
    }

    print("Possible `stremr` options:")
    print(names(res))
    stop(o %+% ": this options does not exist")
  } else {
    if (!o %in% names(res))
      stop(paste("Invalid option name:", o))
    if (is.null(value)) {
      res[o] <- list(NULL)
    }
    else {
      res[[o]] <- value
    }
    do.call("set_all_stremr_options", res)
  }
}

#' Show all current option settings
#' @return Invisibly returns a list of \code{stremr} options.
#' @seealso \code{\link{set_all_stremr_options}}
#' @export
print_stremr_opts <- function() {
  str(gvars$opts)
  invisible(gvars$opts)
}

#' Setting all possible \code{stremr} options at once.
#'
#' Options that control \code{stremr} package.
#' \strong{Calling this function will reset all unspecified options (omitted arguments) to their default values}!
#' The preferred way to set options for \code{stremr} is to use \code{\link{stremrOptions}}, which allows specifying individual options without having to reset all other options.
#' To reset all options to their defaults simply run \code{set_all_stremr_options()} without any parameters/arguments.
#' @param estimator Specify default estimator for model fitting.
#' To see the range of possible choices run \code{stremrOptions("estimator", showvals = TRUE)}.
# @param fit_package Specify the default package for performing model fitting: c("speedglm", "glm", "h2o", "xgboost").
# @param fit_algorithm Specify the default fitting algorithm: c("glm", "gbm", "randomForest", "deeplearning")
#' @param fit_method Specify the default method for model selection.
#' Possible options are \code{"none"} - no model selection and no cross-validation (when using only a single model, e.g., \code{speedglm__glm})
#' or \code{"cv"} - perform V-fold cross-validation to select the best model based on lowest MSE.
#' Note that when code{fit_method = "cv"}, the argument \code{fold_column} also needs to be specified.
#' @param fold_column The column name in the input data (ordered factor) that contains the fold IDs to be used as part of the validation sample.
#' Use the provided function \code{\link{define_CVfolds}} to
#' define such folds or define the folds using your own method.
#' @param bin_method The method for choosing bins when discretizing and fitting the conditional continuous summary
#'  exposure variable \code{sA}. The default method is \code{"equal.len"}, which partitions the range of \code{sA}
#'  into equal length \code{nbins} intervals. Method \code{"equal.mass"} results in a data-adaptive selection of the bins
#'  based on equal mass (equal number of observations), i.e., each bin is defined so that it contains an approximately
#'  the same number of observations across all bins. The maximum number of observations in each bin is controlled
#'  by parameter \code{maxNperBin}. Method \code{"dhist"} uses a mix of the above two approaches,
#'  see Denby and Mallows "Variations on the Histogram" (2009) for more detail.
# @param parfit Default is \code{FALSE}. Set to \code{TRUE} to use \code{foreach} package and its functions
#  \code{foreach} and \code{dopar} to perform
#  parallel logistic regression fits and predictions for discretized continuous outcomes. This functionality
#  requires registering a parallel backend prior to running \code{stremr} function, e.g.,
#  using \code{doParallel} R package and running \code{registerDoParallel(cores = ncores)} for integer
#  \code{ncores} parallel jobs. For an example, see a test in "./tests/RUnit/RUnit_tests_04_netcont_sA_tests.R".
#' @param nbins Set the default number of bins when discretizing a continuous outcome variable under setting
#'  \code{bin_method = "equal.len"}.
#'  If left as \code{NA} the total number of equal intervals (bins) is determined by the nearest integer of
#'  \code{nobs}/\code{maxNperBin}, where \code{nobs} is the total number of observations in the input data.
#' @param maxncats Max number of unique categories that a categorical exposure / censoring or monitoring variable can have.
#' If the variable has more unique values than \code{maxncats}, it is automatically determined to be a continuous variable.
# @param poolContinVar Set to \code{TRUE} for fitting a pooled regression which pools bin indicators across all bins.
# When fitting a model for binirized continuous outcome, set to \code{TRUE}
# for pooling bin indicators across several bins into one outcome regression?
#' @param maxNperBin Max number of observations for a single bin of a discretized continuous variable (applies directly when
#'  \code{bin_method="equal.mass"} and indirectly when \code{bin_method="equal.len"}, but \code{nbins = NA}).
#' @param lower_bound_zero_Q Set to \code{TRUE} to bound the observation-specific Qs during the TMLE update step away from zero (with minimum value set at 10^-4).
#' Can help numerically stabilize the TMLE intercept estimates in some small-sample cases. Has no effect when \code{TMLE} = \code{FALSE}.
#' @param skip_update_zero_Q Set to \code{FALSE} to perform TMLE update with glm even when all of the Q's are zero.
#' When set to \code{TRUE} the TMLE update step is skipped if the predicted Q's are either all 0 or near 0, with TMLE intercept being set to 0.
#' @param up_trunc_offset The upper bound for the TMLE offset during the TMLE GLM update step.
#' @param low_trunc_offset The lower bound for the TMLE offset during the TMLE GLM update step.
#' @param eps_tol Used for TMLE GLM update step. Set the tolerance for testing that the outcomes (\code{Qkplus1}) are all 0 or are all 1.
#' @return Invisibly returns a list with old option settings.
#' @seealso \code{\link{stremrOptions}}, \code{\link{print_stremr_opts}}
#' @export
# fit_package = c("speedglm", "glm", "xgboost", "h2o"),
# fit_algorithm = c("glm", "gbm", "randomForest", "drf", "deeplearning"),
# poolContinVar = FALSE,
# , "holdout"
set_all_stremr_options <- function(
                            estimator = c("speedglm__glm", "glm__glm",
                                          "xgboost__glm", "xgboost__gbm", "xgboost__randomForest",
                                          "h2o__glm", "h2o__gbm", "h2o__randomForest", "h2o__deeplearning"),
                            fit_method = c("none", "cv"),
                            fold_column = NULL,
                            bin_method = c("equal.mass", "equal.len", "dhist"),
                            nbins = 10,
                            maxncats = 20,
                            maxNperBin = 500,
                            lower_bound_zero_Q = TRUE,
                            skip_update_zero_Q = TRUE,
                            up_trunc_offset = 20,
                            low_trunc_offset = -10,
                            eps_tol = 10^-5
                            ) {

  old.opts <- gvars$opts

  # fit_package <- fit_package[1L]
  # fit_algorithm <- fit_algorithm[1L]
  estimator <- estimator[1L]
  fit_method <- fit_method[1L]
  bin_method <- bin_method[1]

  if (!(estimator %in% gvars$opts.allowedVals[["estimator"]])) stop("estimator must be one of: " %+% paste0(gvars$opts.allowedVals[["estimator"]], collapse=", "))
  # if (!(fit_package %in% allowed.fit_package)) stop("fit_package must be one of: " %+% paste0(allowed.fit_package, collapse=", "))
  # if (!(fit_algorithm %in% allowed.fit_algorithm)) stop("fit_algorithm must be one of: " %+% paste0(allowed.fit_algorithm, collapse=", "))
  if (!(fit_method %in% gvars$opts.allowedVals[["fit_method"]])) stop("fit_method must be one of: " %+% paste0(gvars$opts.allowedVals[["fit_method"]], collapse=", "))
  if (!(bin_method %in% gvars$opts.allowedVals[["bin_method"]])) stop("bin_method must be one of: " %+% paste0(gvars$opts.allowedVals[["bin_method"]], collapse=", "))

  opts <- list(
    estimator = estimator,
    # fit_package = fit_package,
    # fit_algorithm = fit_algorithm,
    fit_method = fit_method,
    fold_column = fold_column,
    bin_method = bin_method,
    # parfit = parfit,
    nbins = nbins,
    maxncats = maxncats,
    # poolContinVar = poolContinVar,
    maxNperBin = maxNperBin,
    lower_bound_zero_Q = lower_bound_zero_Q,
    skip_update_zero_Q = skip_update_zero_Q,
    up_trunc_offset = up_trunc_offset,
    low_trunc_offset = low_trunc_offset,
    eps_tol = eps_tol
  )

  gvars$opts <- opts
  options(stremr = opts)
  invisible(old.opts)
}

# returns a function (alternatively a call) that tests for missing values in (sA, sW)
testmisfun <- function() {
  if (is.na(gvars$misval)) {
    return(is.na)
  } else if (is.null(gvars$misval)){
    return(is.null)
  } else if (is.integer(gvars$misval)) {
    return(function(x) {x==gvars$misval})
  } else {
    return(function(x) {x%in%gvars$misval})
  }
}

get.misval <- function() {
  gvars$misfun <- testmisfun()
  gvars$misval
}

set.misval <- function(gvars, newmisval) {
  oldmisval <- gvars$misval
  gvars$misval <- newmisval
  gvars$misfun <- testmisfun()    # EVERYTIME gvars$misval HAS CHANGED THIS NEEDS TO BE RESET/RERUN.
  invisible(oldmisval)
}
gvars$misfun <- testmisfun()

# Allows stremr functions to use e.g., getOption("stremr.verbose") to get verbose printing status
.onLoad <- function(libname, pkgname) {
  ## First test if getOption("stremr") exists already -> then we need to re-use these existing options
  prev.op <- getOption("stremr")

  ## reset all options to their defaults on load if no options have been previously defined:
  if (is.null(prev.op)) {
    set_all_stremr_options()
  } else {
    gvars$opts <- prev.op
  }

  op <- options()
  op.stremr <- list(
    stremr.verbose = gvars$verbose,
    stremr.file.path = tempdir(),
    # stremr.file.name = 'stremr-report-%T-%N-%n'
    stremr.file.name = 'stremr-report-'%+%Sys.Date()
  )
  toset <- !(names(op.stremr) %in% names(op))
  if (any(toset)) options(op.stremr[toset])
  invisible()
}

# Runs when attached to search() path such as by library() or require()
.onAttach <- function(...) {
  if (interactive()) {
  	packageStartupMessage('stremr')
  	# packageStartupMessage('Version: ', utils::packageDescription('stremr')$Version)
  	packageStartupMessage('Version: ', utils::packageDescription('stremr')$Version, '\n')
  	packageStartupMessage(
  "stremr IS IN EARLY DEVELOPMENT STAGE.
Please be to sure to check for frequent updates and report bugs at: http://github.com/osofr/stremr
To install the latest development version of stremr, please type this in your terminal:
  devtools::install_github('osofr/stremr')", '\n')
  	# packageStartupMessage('To see the vignette use vignette("stremr_vignette", package="stremr"). To see all available package documentation use help(package = "stremr") and ?stremr.', '\n')
  	# packageStartupMessage('To see the latest updates for this version, use news(package = "stremr").', '\n')
  }
}