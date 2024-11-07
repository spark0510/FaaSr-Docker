# BASE_IMAGE is the full name of the base image e.g. faasr/base-tidyverse:1.1.2
ARG BASE_IMAGE
# Start from specified base image
FROM $BASE_IMAGE

# FAASR_VERSION FaaSr version to install from - this must match a tag in the GitHub repository e.g. 1.1.2
ARG FAASR_VERSION
# FAASR_INSTALL_REPO is tha name of the user's GitHub repository to install FaaSr from e.g. janedoe/FaaSr-Package-dev
ARG FAASR_INSTALL_REPO

RUN rm /action/FaaSr.schema.json
ADD https://raw.githubusercontent.com/spark0510/FaaSr-package/branch74-issue89/schema/FaaSr.schema.json /action/

RUN rm /action/faasr_start_invoke_github-actions.R
ADD https://raw.githubusercontent.com/spark0510/FaaSr-Docker/refs/heads/main/base/faasr_start_invoke_github-actions.R /action/


# Install FaaSr from specified repo and tag
RUN Rscript -e "args <- commandArgs(trailingOnly=TRUE); library(devtools); install_github(paste0(args[1],'@',args[2]),force=TRUE)" $FAASR_INSTALL_REPO $FAASR_VERSION

# GitHub Actions specifics
WORKDIR /action

CMD ["Rscript", "faasr_start_invoke_github-actions.R"]
