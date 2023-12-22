#' @title Set an entrypoin / Prepare parameters / Source R codes - for Github actions
#' @description When the docker containers run, they start this R code very first time.
#'              This is necessary because it sets library("FaaSr") so that users code can use the FaaSr library and
#'              user's functions would be downloaded from the user's github repository and then they are sourced by
#'              this function. In case of github actions, Secrets(Credentials) for S3(storage), Lambda, Openwhisk, and
#'              Github actions itself and Payload should be called by "replace_values" and "get_payload".
#'              This file consists of helper functions.
#' @param secrets should be stored in the github repository as secrets.
#' @param JSON payload should be stored in the github repository and the path should be designated.

library("httr")
library("jsonlite")
library("FaaSr")

# REST API get faasr payload json file from repo

faasr_get_github <- function(path){
  parts <- strsplit(path, "/")[[1]]
  if (length(parts) < 2) {
    cat("{\"faasr_get_github\":\"github path should contain at least two parts\"}\n")
    stop()
  }
  
  username <- parts[1]
  reponame <- parts[2]
  repo <- paste0(username,"/",reponame)
  if (length(parts) > 2) {
    path <- paste(parts[3: length(parts)], collapse = "/")
  } else {
    path <- NULL
  }
  url <- paste0("https://api.github.com/repos/", repo, "/tarball")
  tar_name <- paste0(reponame,".tar.gz")
  response1 <- GET(
    url = url,
    encode = "json",
    add_headers(
      Accept = "application/vnd.github.v3+json",
      "X-GitHub-Api-Version" = "2022-11-28"
    ),
    write_disk(tar_name)
  )
  if (status_code(response1) == "200") {
    cat("{\"faasr_get_github\":\"Successful\"}\n")
    lists <- untar(tar_name, list=TRUE)
    untar(tar_name, file=paste0(lists[1],path))
    unlink(tar_name, force=TRUE)
  } else if (status_code(response1)=="401"){
    cat("{\"faasr_get_github\":\"Bad credentials - check github token\"}\n")
    stop()
  } else {
    cat("{\"faasr_get_github\":\"Not found - check github repo: ",username,"/",repo,"\"}\n")
    stop()
  }
}


faasr_get_github_raw <- function(token=NULL, path=NULL) {
  # GitHub username and repo
  if (is.null(path)){
    github_repo <- Sys.getenv("PAYLOAD_REPO")
  } else{
    github_repo <- path
  }
  
  parts <- strsplit(github_repo, "/")[[1]]
  if (length(parts) < 3) {
    cat("{\"faasr_get_github_raw\":\"github path should contain at least three parts\"}\n")
    stop()
  }
  username <- parts[1]
  repo <- parts[2]
  
  path <- paste(parts[3: length(parts)], collapse = "/")
  pat <- token
  url <- paste0("https://api.github.com/repos/", username, "/", repo, "/contents/", path)

  # Send the POST request
  if (is.null(pat)){
    response1 <- GET(
      url = url,
      encode = "json",
      add_headers(
        Accept = "application/vnd.github.v3+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      )
    )
  } else {
  # Send the POST request
    response1 <- GET(
      url = url,
      encode = "json",
      add_headers(
        Authorization = paste("token", pat),
        Accept = "application/vnd.github.v3+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      )
    )
  }
  # Check if the request was successful
  if (status_code(response1) == "200") {
    cat("{\"faasr_get_github_raw\":\"Successful\"}\n")
    # Parse the response content
    content <- content(response1, "parsed")
    
    # The content of the file is in the 'content' field and is base64 encoded
    file_content <- rawToChar(base64enc::base64decode(content$content))
    return(file_content)

    #faasr <- fromJSON(file_content)
    #return (faasr)
    
  } else if (status_code(response1)=="401"){
    cat("{\"faasr_get_github_raw\":\"Bad credentials - check github token\"}\n")
    stop()
  } else {
    cat("{\"faasr_get_github_raw\":\"Not found - check github repo: ",username,"/",repo,"\"}\n")
    stop()
  }
}

# function to help to get files from "git repository"
faasr_install_git_repo <- function(gits){
  if (length(gits)==0){
    cat("{\"faasr_install_git_repo\":\"No git repo dependency\"}\n")
  } else{
    for (path in gits){
      if (endsWith(path, ".git") && startsWith(path, "http")) {
        command <- paste("git clone --depth=1",path)
        check <- system(command, ignore.stderr=TRUE)
        if (check!=0){
	        cat(paste0("{\"faasr_start_invoke_github-actions\":\"no repo found, check repository url: ",repo,"\"}\n"))
	        stop()
        }
      } else {
        file_name <- basename(path)
        if (endsWith(file_name, ".R") || endsWith(file_name, ".r")){
          content <- faasr_get_github_raw(path=path)
          eval(parse(text=content))
        }else{
          faasr_get_github(path)
        }
      }
    }
  }
}

# function to help install "CRAN packages"
faasr_install_cran <- function(packages, lib_path=NULL){
  if (length(packages)==0){
    cat("{\"faasr_install_cran\":\"No CRAN package dependency\"}\n")
  } else{
    for (package in packages){
	    install.packages(package, lib=lib_path)
	  }
  }
}

# function to help install "git packages"
faasr_install_git_package <- function(ghpackages, lib_path=NULL){
  if (length(ghpackages)==0){
    cat("{\"faasr_install_git_package\":\"No git package dependency\"}\n")
  } else{
    for (ghpackage in ghpackages){
	    withr::with_libpaths(new=lib_path, devtools::install_github(ghpackage, force=TRUE))
	  }
  }
}

# function to help "source" the R files in the system 
faasr_source_r_files <- function(){
  r_files <- list.files(pattern="\\.R$", recursive=TRUE, full.names=TRUE)
  for (rfile in r_files){
    if (rfile != "./faasr_start_invoke_helper.R" && rfile != "./faasr_start_invoke_openwhisk.R" && rfile != "./faasr_start_invoke_aws-lambda.R" && rfile != "./faasr_start_invoke_github-actions.R" && rfile != "./R_packages.R") {
	    tryCatch(expr=source(rfile), error=function(e){
    		print(e)
	    })
    }
  }
}

