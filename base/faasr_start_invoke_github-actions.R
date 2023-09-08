#' @title Set an entrypoin / Prepare parameters / Source R codes - for Github actions
#' @description When the docker containers run, they start this R code very first time.
#'              This is necessary because it sets library("FaaSr") so that users code can use the FaaSr library and
#'              user's functions would be downloaded from the user's github repository and then they are sourced by
#'              this function. In case of github actions, Secrets(Credentials) for S3(storage), Lambda, Openwhisk, and
#'              Github actions itself and Payload should be called by "replace_values" and "get_payload".
#' @param secrets should be stored in the github repository as secrets.
#' @param JSON payload should be stored in the github repository and the path should be designated.

library("httr")
library("jsonlite")
library("FaaSr")

# Recursive function to replace values
replace_values <- function(user_info, secrets) {
  
  for (name in names(user_info)) {
    if (name == "FunctionList") {
      next
    }
    # If the value is a list, call this function recursively
    if (is.list(user_info[[name]])) {
      user_info[[name]] <- replace_values(user_info[[name]], secrets)
    } else {
      # If the value exists in the secrets, replace it
      if (user_info[[name]] %in% names(secrets)) {
        user_info[[name]] <- secrets[[user_info[[name]]]]
      }
    }
  }
  
  return(user_info)
}

# REST API get faasr payload json file from repo

get_github <- function(token, path){
  parts <- strsplit(path, "/")[[1]]
  if (length(parts) < 2) {
    cat("{\"get_github_raw\":\"github path should contain at least two parts\"}")
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
  pat <- token
  url <- paste0("https://api.github.com/repos/", repo, "/tarball")
  tar_name <- paste0(reponame,".tar.gz")
  response1 <- GET(
    url = url,
    encode = "json",
    add_headers(
      Authorization = paste("token", pat),
      Accept = "application/vnd.github.v3+json",
      "X-GitHub-Api-Version" = "2022-11-28"
    ),
    write_disk(tar_name)
  )
  if (status_code(response1) == "200") {
    cat("{\"get_github\":\"Successful\"}")
    lists <- untar(tar_name, list=TRUE)
    untar(tar_name, file=paste0(lists[1],path))
    unlink(tar_name, force=TRUE)
  } else if (status_code(response1)=="401"){
    cat("{\"get_github\":\"Bad credentials - check github token\"}")
    stop()
  } else {
    cat("{\"get_github\":\"Not found - check github repo: ",username,"/",repo,"\"}")
    stop()
  }
}


get_github_raw <- function(token, path=NULL) {
  # GitHub username and repo
  if (is.null(path)){
    github_repo <- Sys.getenv("PAYLOAD_REPO")
  } else{
    github_repo <- path
  }
  
  parts <- strsplit(github_repo, "/")[[1]]
  if (length(parts) < 3) {
    cat("{\"get_github_raw\":\"github path should contain at least three parts\"}")
    stop()
  }
  username <- parts[1]
  repo <- parts[2]
  
  path <- paste(parts[3: length(parts)], collapse = "/")
  pat <- token
  url <- paste0("https://api.github.com/repos/", username, "/", repo, "/contents/", path)

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

  # Check if the request was successful
  if (status_code(response1) == "200") {
    cat("{\"get_github_raw\":\"Successful\"}")
    # Parse the response content
    content <- content(response1, "parsed")
    
    # The content of the file is in the 'content' field and is base64 encoded
    file_content <- rawToChar(base64enc::base64decode(content$content))
    return(file_content)

    #faasr <- fromJSON(file_content)
    #return (faasr)
    
  } else if (status_code(response1)=="401"){
    cat("{\"get_github_raw\":\"Bad credentials - check github token\"}")
    stop()
  } else {
    cat("{\"get_github_raw\":\"Not found - check github repo: ",username,"/",repo,"\"}")
    stop()
  }
}


secrets <- fromJSON(Sys.getenv("SECRET_PAYLOAD"))
token <- secrets[["PAYLOAD_GITHUB_TOKEN"]]


.faasr <- fromJSON(get_github_raw(token))

.faasr$InvocationID <- Sys.getenv("INPUT_ID")
.faasr$FunctionInvoke <- Sys.getenv("INPUT_INVOKENAME")
.faasr$FaaSrLog <- Sys.getenv("INPUT_FAASRLOG")
#cat("exec.R: faasr-invocationID is: ", faasr$InvocationID, "\n")
#cat("exec.R: faasr-FunctionInvoke is: ", faasr$FunctionInvoke, "\n")

# Replace secrets to faasr
#cat("exec.R: will update user payload\n")
faasr_source <- .faasr
faasr_source$ComputeServers <- replace_values(faasr_source$ComputeServers, secrets$computeservers)
faasr_source$DataStores <- replace_values(faasr_source$DataStores, secrets$datastores)


# back to json formate
.faasr <- toJSON(faasr_source, auto_unbox = TRUE)
funcname <- faasr_source$FunctionInvoke

gits <- faasr_source$FunctionGitRepo[[funcname]]
if (length(gits)==0){NULL} else{
  if (!is.null(token)){
      for (path in gits){
        if (endsWith(path, ".git")) {
          command <- paste("git clone --depth=1",path)
          check <- system(command, ignore.stderr=TRUE)
	  if (check!=0){
	  cat(paste0("{\"faasr_start_invoke_github-actions\":\"no repo found, check repository: ",repo,"\"}\n"))
	  stop()
	  }
        } else {
          file_name <- basename(path)
          if (endsWith(file_name, ".R") || endsWith(file_name, ".r")){
            content <- get_github_raw(token, path)
            eval(parse(text=content))
          }else{
            get_github(token, path)
          }
        }
      }
  } else {
    for (path in gits){
      if (endsWith(path, ".git")){
	command <- paste("git clone --depth=1", path)
	check <- system(command, ignore.stderr=TRUE)
	if (check!=0){
	  cat(paste0("{\"faasr_start_invoke_github-actions\":\"no repo found, check repository: ",repo,"\"}\n"))
	  stop()
	}
      } else {
	parts <- strsplit(path, "/")[[1]]
	repo <- paste0(parts[1],"/",parts[2])
	cat(paste0("{\"faasr_start_invoke_github-actions\":\"no token found, try cloning a git from \"https://github.com/",repo,".git\"}\n"))
	command <- paste0("git clone --depth=1 https://github.com/",repo,".git")
	check <- system(command, ignore.stderr=TRUE)
	if (check!=0){
	  cat(paste0("{\"faasr_start_invoke_github-actions\":\"no repo found, check repository: ",repo,"\"}\n"))
	  stop()
	}
      }
    }
  }
}
	
packages <- faasr_source$FunctionCRANPackage[[funcname]]
if (length(packages)==0){NULL} else{
for (package in packages){
	install.packages(package)
	}
}

ghpackages <- faasr_source$FunctionGitHubPackage[[funcname]]
if (length(ghpackages)==0){NULL} else{
for (ghpackage in ghpackages){
	devtools::install_github(ghpackage, force=TRUE)
	}
}


r_files <- list.files(pattern="\\.R$", recursive=TRUE, full.names=TRUE)
for (rfile in r_files){
    if (rfile != "./faasr_start_invoke_openwhisk_aws-lambda.R" && rfile != "./faasr_start_invoke_github-actions.R" && rfile != "./R_packages.R") {
	  try(source(rfile),silent=TRUE)
	}
}

faasr_start(.faasr)

