# Dockerfiles and GitHub Actions to build FaaSr containers

## Overview

The steps to build a FaaSr-ready container are encapsulated in the following actions:

* base -> DockerHub: Build a base FaaSr image from a Rocker (or Rocker-derived) image available on Dockerhub, and push to DockerHub
* openwhisk -> DockerHub: Build an OpenWhisk-specific FaaSr image from the base created above, and push to DockerHub
* github-actions -> GHCR: Build a GitHub-actions specific FaaSr image from the base created above, and push to GHCR
* aws-lambda -> ECR: Build an AWS Lambda-specific FaaSr image from the base created above, and push to ECR
* Tag as latest: Optionally tag the openwhisk-, github-actions-, and aws-lambda- images as latest in DockerHub, GHCR, ECR

# Pre-requisites and secrets

You will need at a minimum a DockerHub account (to push images to DockerHub), and optionally GitHub and/or AWS accounts to push to GHCR and ECR

## DockerHub

You need to create and configure two secrets for GitHub Actions to push images to DockerHub on your behalf: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN

## GHCR

You need to configure your GitHub account as follows to enable GHCR (TBD).

You also need a token (TBD)

## AWS

You need to create and configure two secrets for GitHub Actions to push images to ECR on your behalf: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

You need to create and configure a private ECR repository on AWS (TBD).

Notes:
* You need one repository for each AWS region you plan to use (e.g. us-east-1)
* Before pushing images, you need to create a private repository (e.g. using AWS Web interface) with the same name as the images you will push (e.g. aws-lambda-tidyverse)

# Naming convention

## Base image

The name of a base image takes the form: 

base-*descriptor*:*version* 

where *descriptor* is a name that describes the FaaSr image being built (e.g. tidyverse) and version is the FaaSr version user (e.g. 1.1.2). 

Example of a base image name are: base-tidyverse:1.1.2, base-geospatial:1.1.2

## FaaS-specific images

The name of a FaaS-specific image takes the form

*faas-prefix*-*descriptor*:*version*

Where *descriptor* and *version* are the same as above, and *faas-prefix* can be: openwhisk, github-actions, or aws-lambda

Example of FaaS-specific image names: openwhisk-tidyverse:1.1.2, github-actions-geospatial:1.1.2

# Build+push actions and their inputs

## base -> DockerHub

Here you need provide, as action inputs:
* The full path of a Rocker or Rocker-derived base image to build from, e.g. rocker/tidyverse:4.3.1, rocker/geospatial:4.3.1
* The base-*descriptor* name as per above, e.g. base-tidyverse
* The FaaSr *version* as per above, e.g. 1.1.2

If successful, this action pushes an image base-*descriptor*:*version* to the DockerHub account set up in your secrets, e.g.: myhubuser/base-tidyverse:1.1.2

## openwhisk -> DockerHub

This assumes you have created a base image previously, as per base -> DockerHub above

Here you need provide, as action inputs:
* The full user/name:tag of the base FaaSr image (stored in DockerHub), e.g. myhubuser/base-tidyverse:1.1.2
* The *faas-prefix*-*descriptor* name as per above, e.g. openwhisk-tidyverse
* The FaaSr *version* as per above, e.g. 1.1.2
* The FaaSr-Package GitHub repository to install from. FaaS-specific containers in these actions are built from a GitHub repository (and not from CRAN) to allow development and testing. Here you can specify your own development repo (e.g. myghuser/FaaSr-Package). *Note: the version above must match the tag in your code repository to install from*

## github-actions -> GHCR

This assumes you have created a base image previously, as per base -> DockerHub above

Here you need provide, as action inputs:
* The full user/name:tag of the base FaaSr image (stored in DockerHub), e.g. myhubuser/base-tidyverse:1.1.2
* The *faas-prefix*-*descriptor* name as per above, e.g. github-actions-tidyverse
* The FaaSr *version* as per above, e.g. 1.1.2
* The FaaSr-Package GitHub repository to install from. FaaS-specific containers in these actions are built from a GitHub repository (and not from CRAN) to allow development and testing. Here you can specify your own development repo (e.g. myghuser/FaaSr-Package). *Note: the version above must match the tag in your code repository to install from*
* The GHCR image repository to push to, e.g. myghuser

## aws-lambda -> ECR

This assumes you have created a base image previously, as per base -> DockerHub above

Here you need provide, as action inputs:
* The full user/name:tag of the base FaaSr image (stored in DockerHub), e.g. myhubuser/base-tidyverse:1.1.2
* The *faas-prefix*-*descriptor* name as per above, e.g. aws-lambda-tidyverse
* The FaaSr *version* as per above, e.g. 1.1.2
* The FaaSr-Package GitHub repository to install from. FaaS-specific containers in these actions are built from a GitHub repository (and not from CRAN) to allow development and testing. Here you can specify your own development repo (e.g. myghuser/FaaSr-Package). *Note: the version above must match the tag in your code repository to install from*
* The AWS region to push to, e.g. us-east-1
 
