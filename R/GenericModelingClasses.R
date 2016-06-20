#----------------------------------------------------------------------------------
# Classes that control modelling of the multivariate joint probability model P(sA|sW).
#----------------------------------------------------------------------------------

#' @importFrom assertthat assert_that

# ---------------------------------------------------------------------------------
# S3 constructors for the summary model classes:
# ---------------------------------------------------------------------------------
newsummarymodel <- function(reg, DataStorageClass.g0, ...) { UseMethod("newsummarymodel") }
# Summary model constructor for binary outcome sA[j]:
newsummarymodel.binary <- function(reg, ...) BinaryOutcomeModel$new(reg = reg, ...)
# Summary model constructor for generic regression with multivariate outcome, but one set of predictors
newsummarymodel.generic <- function(reg, DataStorageClass.g0, ...) GenericModel$new(reg = reg, DataStorageClass.g0 = DataStorageClass.g0, ...)
# Summary model constructor for continuous outcome sA[j]:
newsummarymodel.contin <- function(reg, DataStorageClass.g0, ...) ContinModel$new(reg = reg, DataStorageClass.g0 = DataStorageClass.g0, ...)
# Summary model constructor for categorical outcome sA[j]:
newsummarymodel.categor <- function(reg, DataStorageClass.g0, ...) CategorModel$new(reg = reg, DataStorageClass.g0 = DataStorageClass.g0, ...)
# Summary model constructor for stratification (by reg$subset_exprs):
newsummarymodel.stratify <- function(reg, DataStorageClass.g0, ...) StratifiedModel$new(reg = reg, DataStorageClass.g0 = DataStorageClass.g0, ...)

## ---------------------------------------------------------------------
#' Generic R6 class for modeling (fitting and predicting) P(A=a|W=w) where A can be a multivariate (A[1], ..., A[k]) and each A[i] can be binary, categorical or continous
#'
#' This R6 class Class for defining, fitting and predicting the probability model
#'  \code{P(A|W)} under \code{g_star} or under \code{g_0} for variables
#'  (\code{A,W}). Defines and manages the factorization of the multivariate conditional
#'  probability model \code{P(A=a|...)} into univariate regression models
#'  \code{A[j] ~ A[j-1] + ... + A[1] + W}. The class \code{self$new} method automatically
#'  figures out the correct joint probability factorization into univariate conditional
#'  probabilities based on name ordering provided by (\code{A_nms}, \code{W_nms}).
#'  When the outcome variable \code{A[j]} is binary, this class will automatically call
#'  a new instance of \code{\link{BinaryOutcomeModel}} class.
#'  Provide \code{self$fit()} function argument \code{data} as a \code{\link{DataStorageClass}} class object.
#'  This data will be used for fitting the model \code{P(A|W)}.
#'  Provide \code{self$fit()} function argument \code{newdata} (also as \code{DataStorageClass} class) for predictions of the type
#'  \code{P(A=1|W=w)}, where \code{w} values are coming from \code{newdata} object.
#'  Finally, provide \code{self$predictAeqa} function \code{newdata} argument
#'  (also \code{DataStorageClass} class object) for getting the likelihood predictions \code{P(A=sa|W=w)}, where
#'  both, \code{sa} and \code{sw} values are coming from \code{newdata} object.
#'
#' @docType class
#' @format An \code{\link{R6Class}} generator object
#' @keywords R6 class
#' @details
#' \itemize{
#' \item{\code{n_regs}} - .
#' \item{\code{parfit_allowed}} - .
#' }
#' @section Methods:
#' \describe{
#'   \item{\code{new(reg, ...)}}{...}
#'   \item{\code{length}}{...}
#'   \item{\code{getPsAsW.models}}{...}
#'   \item{\code{getcumprodAeqa}}{...}
#'   \item{\code{copy.fit(GenericModel)}}{...}
#'   \item{\code{fit(data)}}{...}
#'   \item{\code{predict(newdata)}}{...}
#'   \item{\code{predictAeqa(newdata, ...)}}{...}
#'   \item{\code{sampleA(newdata)}}{...}
#' }
#' @section Active Bindings:
#' \describe{
#'   \item{\code{wipe.alldat}}{...}
#' }
#' @export
GenericModel <- R6Class(classname = "GenericModel",
  portable = TRUE,
  class = TRUE,
  public = list(
    reg = NULL,
    outvar = character(),      # outcome name(s)
    predvars = character(),    # names of predictor vars
    n_regs = integer(),        # total no. of reg. models (logistic regressions)
    parfit_allowed = FALSE,    # allow parallel fit of multivar outvar when 1) reg$parfit = TRUE & 2) all.outvar.bin = TRUE
    initialize = function(reg, no_set_outvar = FALSE, ...) {
      self$reg <- reg
      if (!no_set_outvar) self$outvar <- reg$outvar
      self$predvars <- reg$predvars
      # Number of sep. regressions to run, based on the number of outcomes in SingleRegressionFormClass length(reg$outvar)
      # or the number of objects in ListOfRegressionForms
      self$n_regs <- get_n_regs(reg)
      all.outvar.bin <-  all(reg$outvar.class %in% gvars$sVartypes$bin)

      if (reg$parfit & all.outvar.bin & (self$n_regs > 1)) self$parfit_allowed <- TRUE

      if (gvars$verbose) {
        print("#----------------------------------------------------------------------------------")
        print("New instance of GenericModel:")
        print("#----------------------------------------------------------------------------------")
        if ("ListOfRegressionForms" %in% class(reg$RegressionForms)) {
          print("...ListOfRegressionForms..."); if (!is.null(names(reg$RegressionForms))) {print(names(reg$RegressionForms))}
        } else {
          print("Outcomes: " %+% paste(reg$RegressionForms$outvar, collapse = ", "))
          print("Predictors: " %+% paste(reg$RegressionForms$predvars, collapse = ", "))
        }
        print("No. of regressions: " %+% self$n_regs)
        print("All outcomes binary? " %+% all.outvar.bin)
        if (self$parfit_allowed) print("Performing parallel fits: " %+% self$parfit_allowed)
        print("#----------------------------------------------------------------------------------")
      }

      # Factorize the joint into univariate regressions, by dimensionality of the outcome variable (sA_nms):
      for (k_i in 1:self$n_regs) {
        reg_i <- reg$clone()
        reg_i$ChangeManyToOneRegresssion(k_i, reg)
        # Calling the constructor for the summary model P(sA[j]|\bar{sA}[j-1], sW}), dispatching on reg_i class
        PsAsW.model <- newsummarymodel(reg = reg_i, ...)
        private$PsAsW.models <- append(private$PsAsW.models, list(PsAsW.model))
        names(private$PsAsW.models)[k_i] <- "P(sA|sW)."%+%k_i
      }
      invisible(self)
    },
    length = function(){ base::length(private$PsAsW.models) },
    getPsAsW.models = function() { private$PsAsW.models },  # get all summary model objects (one model object per outcome var sA[j])
    getcumprodAeqa = function() { private$cumprodAeqa },  # get joint prob as a vector of the cumulative prod over j for P(sA[j]=a[j]|sW)

    fit = function(data, ...) {
      assert_that(is.DataStorageClass(data))
      # serial loop over all regressions in PsAsW.models:
      if (!self$parfit_allowed) {
        for (k_i in seq_along(private$PsAsW.models)) {
          private$PsAsW.models[[k_i]]$fit(data = data, ...)
        }
      # parallel loop over all regressions in PsAsW.models:
      } else if (self$parfit_allowed) {
        val <- checkpkgs(pkgs=c("foreach", "doParallel", "matrixStats"))
        mcoptions <- list(preschedule = FALSE)
        # NOTE: Each fitRes[[k_i]] will contain a copy of every single R6 object that was passed by reference ->
        # *** the size of fitRes is 100x the size of private$PsAsW.models ***
        fitRes <- foreach::foreach(k_i = seq_along(private$PsAsW.models), .options.multicore = mcoptions) %dopar% {
          private$PsAsW.models[[k_i]]$fit(data = data, ...)
        }
        # copy the fits one by one from BinaryOutcomeModels above into private field for BinaryOutcomeModels
        for (k_i in seq_along(private$PsAsW.models)) {
          private$PsAsW.models[[k_i]]$copy.fit(fitRes[[k_i]])
        }
      }
      invisible(self)
    },
    # P(A=1|W=w): uses private$m.fit to generate predictions
    predict = function(newdata) {
      # if (missing(newdata)) stop("must provide newdata")
      if (!missing(newdata)) assert_that(is.DataStorageClass(newdata))

      # serial loop over all regressions in PsAsW.models:
      if (!self$parfit_allowed) {
        for (k_i in seq_along(private$PsAsW.models)) {
          private$PsAsW.models[[k_i]]$predict(newdata = newdata)
        }
      # parallel loop over all regressions in PsAsW.models:
      } else if (self$parfit_allowed) {
        val <- checkpkgs(pkgs=c("foreach", "doParallel", "matrixStats"))
        mcoptions <- list(preschedule = FALSE)
        # NOTE: Each predRes[[k_i]] will contain a copy of every single R6 object that was passed by reference ->
        # *** the size of fitRes is 100x the size of private$PsAsW.models ***
        predRes <- foreach::foreach(k_i = seq_along(private$PsAsW.models), .options.multicore = mcoptions) %dopar% {
          private$PsAsW.models[[k_i]]$predict(newdata = newdata)
        }
        # copy the predictions one by one from BinaryOutcomeModels above into private field for BinaryOutcomeModels
        for (k_i in seq_along(private$PsAsW.models)) {
          private$PsAsW.models[[k_i]]$copy.predict(predRes[[k_i]])
        }
      }
      invisible(self)
    },
    # WARNING: This method cannot be chained together with other methods (s.a, class$predictAeqa()$fun())
    # Uses daughter objects (stored from prev call to fit()) to get predictions for P(A=obsdat.A|W=w)
    # Invisibly returns the joint probability P(A=a|W=w), also aves it as a private field "cumprodAeqa"
    # P(A=a|W=w) - calculating the likelihood for obsdat.A[i] (n vector of a's):
    predictAeqa = function(newdata, n, ...) {
      # assert_that(!missing(newdata))
      if (!missing(newdata)) {
        assert_that(is.DataStorageClass(newdata))
        n <- newdata$nobs
      }

      if (!self$parfit_allowed) {
        cumprodAeqa <- rep.int(1L, n)
        # loop over all regressions in PsAsW.models:
        for (k_i in seq_along(private$PsAsW.models)) {
          cumprodAeqa <- cumprodAeqa * private$PsAsW.models[[k_i]]$predictAeqa(newdata = newdata, n = n, ...)
        }
      } else if (self$parfit_allowed) {
        val <- checkpkgs(pkgs=c("foreach", "doParallel", "matrixStats"))
        mcoptions <- list(preschedule = TRUE)
        probAeqa_list <- foreach::foreach(k_i = seq_along(private$PsAsW.models), .options.multicore = mcoptions) %dopar% {
          private$PsAsW.models[[k_i]]$predictAeqa(newdata = newdata, ...)
        }
        probAeqa_mat <- do.call('cbind', probAeqa_list)
        cumprodAeqa <- matrixStats::rowProds(probAeqa_mat)
      }
      private$cumprodAeqa <- cumprodAeqa
      return(cumprodAeqa)
    },

    sampleA = function(newdata, ...) {
      assert_that(!missing(newdata))
      assert_that(is.DataStorageClass(newdata))
      n <- newdata$nobs
      # loop over all regressions in PsAsW.models, sample CONDITIONALLY on observations that haven't been put in a specific bin yet
      sampleA_mat <- matrix(0L, nrow = n, ncol = length(private$PsAsW.models))
      for (k_i in seq_along(private$PsAsW.models)) {
        sampleA_newcat <- private$PsAsW.models[[k_i]]$sampleA(newdata = newdata, ...)
        if (k_i == 1L) sampleA_mat[, k_i] <- sampleA_newcat
        # carry forward all previously sampled 1's (degenerate ones a bin a chosen for the first time)
        if (k_i > 1) {
          # if you succeeded at the previous bin, your 1L is carried through till the end:
          sampleA_mat[(sampleA_mat[, k_i - 1] == 1L), k_i] <- 1L
          # if you haven't succeeded at the previous bin, you get a chance to succeed at this category:
          sampleA_mat[(sampleA_mat[, k_i - 1] == 0L), k_i] <- sampleA_newcat[(sampleA_mat[, k_i - 1] == 0L)]
        }
      }
      if (length(private$PsAsW.models) > 1) {
        sampleA_mat[, length(private$PsAsW.models)] <- 1L # make last category a reference category
        sampleA_cat <- rowSums(1L - sampleA_mat) + 1L
      } else {
        sampleA_cat <- as.vector(sampleA_mat)
      }
      return(sampleA_cat)
    },

    # call itself until reaches a terminal model fit with coefficients + regression returned with show()
    get.fits = function() {
      res_models <- NULL
      for (k_i in seq_along(private$PsAsW.models)) {
        res <- private$PsAsW.models[[k_i]]$get.fits()
        if (is.list(res)) res_models <- c(res_models, res)
      }
      return(res_models)
    }
  ),
  active = list(
    # recursively call all saved daughter model fits and wipe out any traces of saved data
    wipe.alldat = function() {
      for (k_i in seq_along(private$PsAsW.models)) {
        private$PsAsW.models[[k_i]]$wipe.alldat
      }
      return(self)
    }
  ),
  private = list(
    deep_clone = function(name, value) {
      # if value is is an environment, quick way to copy:
      # list2env(as.list.environment(value, all.names = TRUE), parent = emptyenv())
      # if a list of R6 objects, make a deep copy of each:
      if (name == "PsAsW.models") {
        lapply(value, function(PsAsW.model) PsAsW.model$clone(deep=TRUE))
      } else if (inherits(value, "R6")) { # to check the value is an R6 object:
        value$clone(deep=TRUE)
      } else {
        value # For all other fields, just return the value
      }
    },
    PsAsW.models = list(),
    fitted.pbins = list(),
    cumprodAeqa = NULL
  )
)


# -------------------------------------------------------------------------------------------
# Same code called from ContinModel$new and CategorModel$new:
# From a single categorical/continous outcome regression define a regression class for many binary dummy outcomes.
# First makes a clone of the parent RegressionClass and the recents the previous outvar/outvar.class to new binary outcomes/classes.
# Defines subset_var evaluation for new bins (for fitting the hazard of each new category/dummy)
# NOTE: This subsetting is performed by var name only (which automatically evaluates as !gvars$misval(var)) for speed & memory efficiency
# The code in DataStorageClass$binirize.sVar() will automatically set the indicator Bin_K[i] to NA when Bin_K-1[i] is 1 for the first time.
# Thus, by excluding all observations such that !is.na(Bin_K) we end up fitting the hazard for Bin_K=1.
# -------------------------------------------------------------------------------------------
def_regs_subset <- function(self) {
  bin_regs <- self$reg$clone()  # Instead of defining new RegressionClass, just clone the parent reg object and adjust the outcomes
  bin_regs$reg_hazard <- TRUE   # Don`t add degenerate bins as predictors in each binary regression
  if (!self$reg$pool_cont) {
    add.oldsubset <- TRUE
    new.subsets <- lapply(self$reg$bin_nms,
                              function(var) {
                                res <- var
                                if (add.oldsubset) res <- c(res, self$reg$subset_vars)
                                res
                              })

    new.sAclass <- as.list(rep_len(gvars$sVartypes$bin, self$reg$nbins))
    names(new.sAclass) <- self$reg$bin_nms
    bin_regs$outvar.class <- new.sAclass
    bin_regs$outvar <- self$reg$bin_nms
    bin_regs$predvars <- self$reg$predvars
    bin_regs$subset_vars <- new.subsets
  # Same but when pooling across bin indicators:
  } else {
    bin_regs$outvar.class <- gvars$sVartypes$bin
    bin_regs$outvar <- self$outvar
    bin_regs$outvars_to_pool <- self$reg$bin_nms
    if (gvars$verbose)  {
      print("pooled bin_regs$outvar: "); print(bin_regs$outvar)
      print("bin_regs$outvars_to_pool: "); print(bin_regs$outvars_to_pool)
      print("bin_regs$subset_vars: "); print(bin_regs$subset_vars)
    }
  }
  bin_regs$resetS3class()
  return(bin_regs)
}


## -------------------------------------------------------------------------------------------
#' R6 class for fitting and predicting joint probability for a univariate continuous summary A[j]
#'
#' This R6 class defines and fits a conditional probability model \code{P(A[j]|W,...)} for a univariate
#'  continuous summary measure \code{A[j]}. This class inherits from \code{\link{GenericModel}} class.
#'  Defines the fitting algorithm for a regression model \code{A[j] ~ W + ...}.
#'  Reconstructs the likelihood \code{P(A[j]=a[j]|W,...)} afterwards.
#'  Continuous \code{A[j]} is discretized using either of the 3 interval cutoff methods,
#'  defined via \code{\link{RegressionClass}} object \code{reg} passed to this class constructor.
#'  The fitting algorithm estimates the binary regressions for hazard \code{Bin_A[j][i] ~ W},
#'  i.e., the probability that continuous \code{A[j]} falls into bin \code{i}, \code{Bin_A[j]_i},
#'  given that \code{A[j]} does not belong to any prior bins \code{Bin_A[j]_1, ..., Bin_A[j]_{i-1}}.
#'  The dataset of discretized summary measures (\code{BinA[j]_1,...,BinA[j]_M}) is created
#'  inside the passed \code{data} or \code{newdata} object while discretizing \code{A[j]} into \code{M} bins.
#'
#' @docType class
#' @format An \code{\link{R6Class}} generator object
#' @keywords R6 class
#' @details
#' \itemize{
#' \item{\code{reg}} - .
#' \item{\code{outvar}} - .
#' \item{\code{intrvls}} - .
#' \item{\code{intrvls.width}} - .
#' \item{\code{bin_weights}} - .
#' }
#' @section Methods:
#' \describe{
#'   \item{\code{new(reg, DataStorageClass.g0, DataStorageClass.gstar, ...)}}{...}
#'   \item{\code{fit(data)}}{...}
#'   \item{\code{predict(newdata)}}{...}
#'   \item{\code{predictAeqa(newdata)}}{...}
#' }
#' @section Active Bindings:
#' \describe{
#'   \item{\code{cats}}{...}
#' }
#' @export
ContinModel <- R6Class(classname = "ContinModel",
  inherit = GenericModel,
  portable = TRUE,
  class = TRUE,
  public = list(
    reg = NULL,
    outvar = character(),     # the name of the continous outcome var (sA[j])
    intrvls = NULL,
    intrvls.width = NULL,
    bin_weights = NULL,
    # Define settings for fitting contin sA and then call $new for super class (GenericModel)
    initialize = function(reg, DataStorageClass.g0, DataStorageClass.gstar, ...) {
      self$reg <- reg
      self$outvar <- reg$outvar
      if (is.null(reg$intrvls)) {
        assert_that(is.DataStorageClass(DataStorageClass.g0))
        self$intrvls <- DataStorageClass.g0$detect.sVar.intrvls(reg$outvar,
                                                      nbins = self$reg$nbins,
                                                      bin_bymass = self$reg$bin_bymass,
                                                      bin_bydhist = self$reg$bin_bydhist,
                                                      max_nperbin = self$reg$max_nperbin)
        if (!missing(DataStorageClass.gstar)) {
          assert_that(is.DataStorageClass(DataStorageClass.gstar))
          gstar.intrvls <- DataStorageClass.gstar$detect.sVar.intrvls(reg$outvar,
                                                      nbins = self$reg$nbins,
                                                      bin_bymass = self$reg$bin_bymass,
                                                      bin_bydhist = self$reg$bin_bydhist,
                                                      max_nperbin = self$reg$max_nperbin)
          self$intrvls <- unique(sort(union(self$intrvls, gstar.intrvls)))
        }
        # Define the number of bins (no. of binary regressions to run),
        # new outvar var names (bin names); all predvars remain unchanged;
        self$reg$intrvls <- self$intrvls
      } else {
        self$intrvls <- self$reg$intrvls
      }
      self$reg$nbins <- length(self$intrvls) - 1
      self$reg$bin_nms <- DataStorageClass.g0$bin.nms.sVar(reg$outvar, self$reg$nbins)
      # Save bin widths in reg class (naming the vector entries by bin names):
      self$intrvls.width <- diff(self$intrvls)
      self$intrvls.width[self$intrvls.width <= gvars$tolerr] <- 1
      self$reg$intrvls.width <- self$intrvls.width
      names(self$reg$intrvls.width) <- names(self$intrvls.width) <- self$reg$bin_nms
      if (gvars$verbose)  {
        print("ContinModel outcome: "%+%self$outvar)
      }
      bin_regs <- def_regs_subset(self = self)
      super$initialize(reg = bin_regs, no_set_outvar = TRUE, ...)
    },
    # Transforms data for continous outcome to discretized bins A[j] -> BinA[1], ..., BinA[M] and calls $super$fit on that transformed data
    # Gets passed redefined subsets that exclude degenerate Bins (prev subset is defined for names in A - names have changed though)
    fit = function(data, ...) {
      assert_that(is.DataStorageClass(data))
      # Binirizes & saves binned matrix inside DataStorageClass
      data$binirize.sVar(name.sVar = self$outvar, intervals = self$intrvls, nbins = self$reg$nbins, bin.nms = self$reg$bin_nms)
      if (gvars$verbose) {
        print("performing fitting for continuous outcome: " %+% self$outvar)
        print("freq counts by bin for continuous outcome: "); print(table(data$ord.sVar))
        print("binned dataset: "); print(head(cbind(data$ord.sVar, data$dat.bin.sVar), 5))
      }
      super$fit(data, ...) # call the parent class fit method
      if (gvars$verbose) message("fit for outcome " %+% self$outvar %+% " succeeded...")
      data$emptydat.bin.sVar # wiping out binirized mat in data DataStorageClass object...
      self$wipe.alldat # wiping out all data traces in ContinModel...
      invisible(self)
    },
    # P(A=1|W=w): uses private$m.fit to generate predictions
    predict = function(newdata, ...) {
      # if (missing(newdata)) stop("must provide newdata")
      # assert_that(is.DataStorageClass(newdata))

      if (gvars$verbose) print("performing prediction for continuous outcome: " %+% self$outvar)
      # mat_bin doesn't need to be saved (even though its invisibly returned); mat_bin is automatically saved in datnet.sW.sA - a potentially dangerous side-effect!!!

      if (!missing(newdata)) {
        newdata$binirize.sVar(name.sVar = self$outvar, intervals = self$intrvls, nbins = self$reg$nbins, bin.nms = self$reg$bin_nms)
      }
      super$predict(newdata, ...)
      if (!missing(newdata)) {
        newdata$emptydat.bin.sVar # wiping out binirized mat in newdata DataStorageClass object...
      }
      invisible(self)
    },


    # Convert contin. A vector into matrix of binary cols, then call parent class method: super$predictAeqa()
    # Invisibly return cumm. prob P(A=a|W=w)
    predictAeqa = function(newdata, ...) { # P(A^s=a^s|W^s=w^s) - calculating the likelihood for obsdat.sA[i] (n vector of a`s)
      assert_that(is.DataStorageClass(newdata))
      newdata$binirize.sVar(name.sVar = self$outvar, intervals = self$intrvls, nbins = self$reg$nbins, bin.nms = self$reg$bin_nms)
      if (gvars$verbose) print("performing prediction for categorical outcome: " %+% self$outvar)
      bws <- newdata$get.sVar.bw(name.sVar = self$outvar, intervals = self$intrvls)
      self$bin_weights <- (1 / bws) # weight based on 1 / (sVar bin widths)
      # Option 1: ADJUST FINAL PROB by bw.j TO OBTAIN density at a point f(sa|sw) = P(A=a|W=w):
      cumprodAeqa <- super$predictAeqa(newdata = newdata) * self$bin_weights
      # Alternative 2: ALso integrate the difference of sA value and its left most bin cutoff: x - b_{j-1} and pass it
      # This is done so that we can integrate the constant hazard all the way to the value of x:
        # * (1 - bw.j.sA_diff*(1/self$bin_weights)*probA1) (discrete)
        # * exp(-bw.j.sA_diff*(1/self$bin_weights)*probA1) (continuous)
      # bw.j.sA_diff <- newdata$get.sVar.bwdiff(name.sVar = self$outvar, intervals = self$intrvls)
      # cumprodAeqa <- super$predictAeqa(newdata = newdata, bw.j.sA_diff = bw.j.sA_diff) * self$bin_weights
      newdata$emptydat.bin.sVar # wiping out binirized mat in newdata object...
      self$bin_weights <- NULL # wiping out self$bin_weights...
      self$wipe.alldat # wiping out all data traces in ContinModel...
      private$cumprodAeqa <- cumprodAeqa
      return(cumprodAeqa)
    },
    sampleA = function() {
      stop("not implemented")
    }
  ),
  active = list(
    cats = function() {seq_len(self$reg$nbins)}
  )
)

## ---------------------------------------------------------------------
#' R6 class for fitting and predicting joint probability for a univariate categorical summary A[j]
#'
#' This R6 class defines and fits a conditional probability model \code{P(A[j]|W,...)} for a univariate
#'  categorical summary measure \code{A[j]}. This class inherits from \code{\link{GenericModel}} class.
#'  Defines the fitting algorithm for a regression model \code{A[j] ~ W + ...}.
#'  Reconstructs the likelihood \code{P(A[j]=a[j]|W,...)} afterwards.
#'  Categorical \code{A[j]} is first redefined into \code{length(levels)} bin indicator variables, where
#'  \code{levels} is a numeric vector of all unique categories in \code{A[j]}.
#'  The fitting algorithm estimates the binary regressions for hazard for each bin indicator, \code{Bin_A[j][i] ~ W},
#'  i.e., the probability that categorical \code{A[j]} falls into bin \code{i}, \code{Bin_A[j]_i},
#'  given that \code{A[j]} does not fall in any prior bins \code{Bin_A[j]_1, ..., Bin_A[j]_{i-1}}.
#'  The dataset of bin indicators (\code{BinA[j]_1,...,BinA[j]_M}) is created
#'  inside the passed \code{data} or \code{newdata} object when defining \code{length(levels)} bins for \code{A[j]}.
#'
#' @docType class
#' @format An \code{\link{R6Class}} generator object
#' @keywords R6 class
#' @details
#' \itemize{
#' \item{\code{reg}} - .
#' \item{\code{outvar}} - .
#' \item{\code{levels}} - .
#' \item{\code{nbins}} - .
#' }
#' @section Methods:
#' \describe{
#'   \item{\code{new(reg, DataStorageClass.g0, ...)}}{...}
#'   \item{\code{fit(data)}}{...}
#'   \item{\code{predict(newdata)}}{...}
#'   \item{\code{predictAeqa(newdata)}}{...}
#'   \item{\code{sampleA(newdata)}}{...}
#' }
#' @section Active Bindings:
#' \describe{
#'   \item{\code{cats}}{...}
#' }
#' @export
CategorModel <- R6Class(classname = "CategorModel",
  inherit = GenericModel,
  portable = TRUE,
  class = TRUE,
  public = list(
    reg = NULL,
    outvar = character(),     # the name of the categorical outcome var (sA[j])
    levels = numeric(),       # all unique values for sA[j] sorted in increasing order
    nbins = integer(),
    # Define settings for fitting cat sA and then call $new for super class (GenericModel)
    initialize = function(reg, DataStorageClass.g0, ...) {
      self$reg <- reg
      self$outvar <- reg$outvar
      # Define the number of bins (no. of binary regressions to run) based on number of unique levels for categorical sVar:
      if (self$reg$get.reg$censoring & gvars$verbose) {
        message("...fitting a model for categorical censoring...")
      }
      if (is.null(reg$levels)) {
        assert_that(is.DataStorageClass(DataStorageClass.g0))
        self$levels <- self$reg$levels <- DataStorageClass.g0$detect.cat.sVar.levels(reg$outvar)
      } else {
        self$levels <- self$reg$levels
      }
      self$nbins <- self$reg$nbins <- length(self$levels)
      self$reg$bin_nms <- DataStorageClass.g0$bin.nms.sVar(reg$outvar, self$reg$nbins)
      if (gvars$verbose)  {
        print("CategorModel outcome: "%+%self$outvar)
      }
      bin_regs <- def_regs_subset(self = self)
      super$initialize(reg = bin_regs, no_set_outvar = TRUE, ...)
    },

    # Transforms data for categorical outcome to bin indicators A[j] -> BinA[1], ..., BinA[M] and calls $super$fit on that transformed data
    # Gets passed redefined subsets that exclude degenerate Bins (prev subset is defined for names in A - names have changed though)
    fit = function(data, ...) {
      assert_that(is.DataStorageClass(data))
      # Binirizes & saves binned matrix inside DataStorageClass for categorical sVar
      data$binirize.sVar(name.sVar = self$outvar, levels = self$levels)
      if (gvars$verbose) {
        print("performing fitting for categorical outcome: " %+% self$outvar)
        print("freq counts by bin for categorical outcome: "); print(table(data$get.sVar(self$outvar)))
        print("binned dataset: "); print(head(cbind(sA = data$get.sVar(self$outvar), data$dat.bin.sVar), 5))
      }
      super$fit(data) # call the parent class fit method
      if (gvars$verbose) message("fit for " %+% self$outvar %+% " var succeeded...")
      data$emptydat.bin.sVar # wiping out binirized mat in data DataStorageClass object...
      self$wipe.alldat # wiping out all data traces in ContinModel...
      invisible(self)
    },
    # P(A=1|W=w): uses private$m.fit to generate predictions
    predict = function(newdata, ...) {
      if (missing(newdata)) stop("must provide newdata")
      assert_that(is.DataStorageClass(newdata))
      if (gvars$verbose) print("performing prediction for categorical outcome: " %+% self$outvar)
      newdata$binirize.sVar(name.sVar = self$outvar, levels = self$levels)
      super$predict(newdata)
      newdata$emptydat.bin.sVar # wiping out binirized mat in newdata DataStorageClass object...
      invisible(self)
    },
    # Invisibly return cumm. prob P(A=a|W=w)
    # P(A=a|W=w) - calculating the likelihood for obsdat.sA[i] (n vector of a's):
    predictAeqa = function(newdata, ...) {
      assert_that(is.DataStorageClass(newdata))
      if (gvars$verbose) print("performing prediction for categorical outcome: " %+% self$outvar)
      newdata$binirize.sVar(name.sVar = self$outvar, levels = self$levels)
      cumprodAeqa <- super$predictAeqa(newdata = newdata)
      newdata$emptydat.bin.sVar # wiping out binirized mat in newdata object...
      self$wipe.alldat # wiping out all data traces in ContinModel...
      private$cumprodAeqa <- cumprodAeqa
      return(cumprodAeqa)
    },
    sampleA = function(newdata) {
      assert_that(is.DataStorageClass(newdata))
      sampleA <- self$levels[super$sampleA(newdata = newdata)] # bring the sampled variable back to its original scale / levels:
      return(sampleA)
    }
  ),
  active = list(
    cats = function() {seq_len(self$reg$nbins)}
  )
)

## ---------------------------------------------------------------------
#' R6 class for fitting and predicting with several stratified models for a single outcome variable (conditional on some covariate values)
#'
#' This R6 class defines and fits a conditional probability model \code{P(A[j]|W,...)} for a summary \code{A[j]}.
#' This class inherits from \code{\link{GenericModel}} class.
#' The stratification criteria is determined by the \code{R} expression in the field \code{subset_exprs}.
#'
#' @docType class
#' @format An \code{\link{R6Class}} generator object
#' @keywords R6 class
#' @details
#' \itemize{
#' \item{\code{reg}} - .
#' \item{\code{outvar}} - .
#' \item{\code{subset_exprs}} - .
#' }
#' @section Methods:
#' \describe{
#'   \item{\code{new(reg, DataStorageClass.g0, ...)}}{...}
#'   \item{\code{fit(data)}}{...}
#'   \item{\code{predict(newdata)}}{...}
#'   \item{\code{predictAeqa(newdata)}}{...}
#'   \item{\code{sampleA(newdata)}}{...}
#' }
#' @section Active Bindings:
#' \describe{
#'   \item{\code{cats}}{...}
#' }
#' @export
StratifiedModel <- R6Class(classname = "StratifiedModel",
  inherit = GenericModel,
  portable = TRUE,
  class = TRUE,
  public = list(
    reg = NULL,
    outvar = character(),     # the name of the categorical outcome var (sA[j])
    # levels = numeric(),       # all unique values for sA[j] sorted in increasing order
    # nbins = integer(),
    subset_exprs = NULL,
    # Define settings for fitting cat sA and then call $new for super class (GenericModel)
    # We produce a regression class with 3 outvars (same) and 3 outvar.class (same)
    # The daughter regression clases resulting from this need to be of class StratifiedRegressionModelClass
    initialize = function(reg, DataStorageClass.g0, ...) {
      self$reg <- reg
      self$outvar <- reg$outvar
      self$subset_exprs <- reg$subset_exprs
      assert_that(length(self$reg$subset_exprs) > 1L)
      assert_that(length(self$reg$outvar) == 1L)
      if (gvars$verbose)  {
        print("StratifiedModel outcome: "%+%self$outvar)
        print("StratifiedModel expressions: ("%+% paste(self$subset_exprs, collapse=",") %+% ")")
      }
      # print("self$reg before stratification:"); self$reg$show()
      stratify_regs <- self$reg$clone()  # Instead of defining new RegressionClass, just clone the parent reg object and adjust the outcomes
      stratify_regs$outvar <- rep_len(self$reg$outvar, length(self$reg$subset_exprs))
      stratify_regs$outvar.class <- as.list(rep_len(self$reg$outvar.class, length(self$reg$subset_exprs)))
      names(stratify_regs$outvar.class) <- stratify_regs$outvar
      # by turning stratify_regs$subset_exprs into a list the subsetting will be performed on subset_exprs during next S3 dispatch on SummaryModel
      stratify_regs$subset_exprs <- as.list(stratify_regs$subset_exprs)
      names(stratify_regs$subset_exprs) <- stratify_regs$outvar
      stratify_regs$reg_hazard <- TRUE
      # print("stratify_regs class:"); stratify_regs$show()
      super$initialize(reg = stratify_regs, no_set_outvar = TRUE, DataStorageClass.g0 = DataStorageClass.g0, ...)
    },
    # Transforms data for categorical outcome to bin indicators sA[j] -> BinsA[1], ..., BinsA[M] and calls $super$fit on that transformed data
    # Gets passed redefined subsets that exclude degenerate Bins (prev subset is defined for names in sA - names have changed though)
    fit = function(data, ...) {
      assert_that(is.DataStorageClass(data))
      if (gvars$verbose) {
        print("performing fitting for outcome based on stratified model for outcome: " %+% self$outvar)
        # print("following subsets are defined: "); print(table(data$get.sVar(self$outvar)))
      }
      super$fit(data, ...) # call the parent class fit method
      if (gvars$verbose) message("fit for " %+% self$outvar %+% " var succeeded...")
      invisible(self)
    },
    # P(A^s=1|W^s=w^s): uses private$m.fit to generate predictions
    predict = function(newdata, ...) {
      # if (missing(newdata)) stop("must provide newdata")
      if (!missing(newdata)) assert_that(is.DataStorageClass(newdata))

      if (gvars$verbose) print("performing prediction for outcome based on stratified model: " %+% self$outvar)
      super$predict(newdata, ...)
      invisible(self)
    },
    # Invisibly return cumm. prob P(sA=sa|sW=sw)
    # P(A=a|W=w) - calculating the likelihood for obsdat.A[i] (n vector of a's):
    predictAeqa = function(newdata, ...) {
      if (!missing(newdata)) assert_that(is.DataStorageClass(newdata))

      if (gvars$verbose) print("performing prediction for outcome based on stratified model: " %+% self$outvar)
      cumprodAeqa <- super$predictAeqa(newdata = newdata, ...)
      private$cumprodAeqa <- cumprodAeqa
      return(cumprodAeqa)
    },
    sampleA = function(newdata) {
      assert_that(is.DataStorageClass(newdata))
      # bring the sampled variable back to its original scale / levels:
      sampleA <- super$sampleA(newdata = newdata)
      return(sampleA)
    }
  ),
  active = list(
    # cats = function() {seq_len(self$reg$nbins)}
  )
)