#!/usr/local/bin/Rscript

#' @title Set an entrypoin / Source R codes - for Openwhisk and AWS lambda
#' @description When the docker containers run, they start this R code very first time.
#'              This is necessary because it sets library("FaaSr") so that users code can use the FaaSr library and
#'              user's functions would be downloaded from the user's github repository and then they are sourced by
#'              this function. 
#' @param JSON payload is passed as an input when the docker container starts.

library("jsonlite")
library("githubinstall")
library("FaaSr")

faasr <- commandArgs(TRUE)
faasr_source <- fromJSON(faasr)
actionname <- faasr_source$FunctionList[[faasr_source$FunctionInvoke]]$Actionname

gits <- faasr_source$FunctionGitRepo[[actionname]]
if (length(gits)==0){NULL} else{
for (file in gits){
	command <- paste("git clone --depth=1",file)
	system(command, ignore.stderr=TRUE)
	}
}
	
packages <- faasr_source$FunctionCRANPackage[[actionname]]
if (length(packages)==0){NULL} else{
for (package in packages){
	install.packages(package)
	}
}

ghpackages <- faasr_source$FunctionGitHubPackage[[actionname]]
if (length(ghpackages)==0){NULL} else{
for (ghpackage in ghpackages){
	githubinstall("ghpackage")
	}
}

r_files <- list.files(pattern="\\.R$", recursive=TRUE, full.names=TRUE)
for (rfile in r_files){
    if (rfile != "./faasr_start_invoke_openwhisk_aws-lambda.R" && rfile != "./faasr_start_invoke_github-actions.R" && rfile != "./R_packages.R") {
	  try(source(rfile),silent=TRUE)
	}
}


faasr_start(faasr)

