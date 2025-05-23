% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/main.R
\name{order_variant_string}
\alias{order_variant_string}
\title{Reorders a variant string}
\usage{
order_variant_string(x)
}
\arguments{
\item{x}{a variant string or vector of variant strings.}
}
\description{
Reorders a variant string in alphabetical order of genes, and then
alphabetical order of amino acids at each heterozygous locus. This can be
useful when checking for duplicated strings as the same information may be
presented in a different order.
}
