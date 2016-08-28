% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/zzz.R
\name{stremrOptions}
\alias{stremrOptions}
\title{Querying/setting a single \code{stremr} option}
\usage{
stremrOptions(o, value)
}
\arguments{
\item{o}{Option name (string). See \code{\link{set_all_stremr_options}}.}

\item{value}{Value to assign (optional)}
}
\description{
To list all \code{stremr} options, just run this function without any parameters provided. To query only one value, pass the first parameter. To set that, use the \code{value} parameter too.
}
\details{
The arguments of \code{\link{set_all_stremr_options}} list all available \code{stremr} options.
}
\examples{
\dontrun{
stremrOptions()
stremrOptions('fit.package')
stremrOptions('fit.package', 'h2o')
}
}
\seealso{
\code{\link{set_all_stremr_options}}
}
