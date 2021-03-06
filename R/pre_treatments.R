#'Plot the ACP to choose k
#'
#' This function makes a PCA to search the number k of cell types.
#'
#'@param D The matrix patients*probes.
#'
#'@return This function returns the plot of the ACP.
#'
#'@import ggplot2
#'
#'@export
plot_k = function(D){
  X <- bigstatsr::as_FBM(t(D))
  svd <- bigstatsr::big_SVD(X, bigstatsr::big_scale())
  
  ggplot(data.frame(val = svd$d, idx = 1:10), aes(x = idx, y = val)) + 
    geom_line() +
    geom_point() + scale_x_continuous(breaks = 1:10)+
    labs(x = "PC index", y = "Eigenvalues") +
    theme_minimal(base_size = 16)
}



#'Function to compute the p-value of the CF
#'
#' This function makes a linear regression and compute the pvalue
#'
#'@param val expression
#'@param labels counfounding factors
#'
#'@return this function return pvalues
#'
pval_CF <- function(val, labels) {
  tryCatch({
    if (!is.numeric(labels)) labels <- as.factor(labels)
    fit <- stats::lm(X ~ Y, data = data.frame(X = I(val), Y = labels))
    f <- sapply(summary(fit), function(sm) sm$fstatistic)
    stats::pf(f[1, ], f[2, ], f[3, ], lower.tail = FALSE)
  }, error = function(e) NULL)
}

#'Function to remove correlated probes
#'
#' This function searchs the correlated probes by linear model.
#'
#'@param D The matrix patients*probes.
#'@param exp_grp The matrix of experimental data for all the patients.
#'@param threshold The threshold of FDR, probes above this threshold will be conserved.
#'@param ncores Number of cores to use. Default is `nb_cores()`.
#'
#'@return This function return the D matrix without correlated probes.
#'
#'@import foreach
#'
#'@export
CF_detection <- function(D, exp_grp, threshold = 0.15, ncores = nb_cores()){
  exp_grp <- exp_grp[sapply(exp_grp, function(x) mean(is.na(x)) <= 0.8)]
  doParallel::registerDoParallel(ncores)
  on.exit(doParallel::stopImplicitCluster(), add = TRUE)
  pvalues <- foreach(var = exp_grp, .combine = "cbind") %dopar% {
    pval_CF(val = t(D), labels = var)
  }
  adjpvalues <- apply(pvalues, 2, stats::p.adjust, method = "fdr")
  keep_marker <- apply(adjpvalues, 1, min, na.rm = TRUE) > threshold
  return(D[keep_marker, ])
}


#'Function to select probes with a high variance
#'
#' This function select probes with the largest variance 
#'
#'@param D The matrix of dimension patients*probes.
#'@param number number of largest variance probes to keep
#'
#'@return This function return the D matrix with selected probes.
#'
#'@export
feature_selection <- function(D, number = 5000) {
  var <- apply(D, 1, var)
  thr <- sort(var, decreasing = T)[number]
  return(D[var > thr, ])
}
