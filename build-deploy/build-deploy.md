# Building and Deploying Docker Images and Helm Charts

This is a collection of general guidelines on how to build and deploy docker images and
helm charts. Note that nerdctl is an open source version of the docker commandline tool, which works
pretty much as a drop-in replacement, and can be used to generate images that can be executed with
the containerd runtime.

## Docker Image Builds and Publication to GHCR

### Building A Docker Image

An image is built using a Dockerfile that contains the necessary commands. Here is a simplified
example:

```Dockerfile
FROM ubuntu:18.04
RUN apt-get update
RUN apt-get install -y apache2
# Connect this image to a GitHub repository
LABEL org.opencontainers.image.source="https://github.com/dataoneorg/my-apache2"
CMD ["apache2ctl", "-D", "FOREGROUND"]
```

If saved as `Dockerfile` to the current directory, it can be built using the `docker build` command:

```shell
docker build -t ghcr.io/dataone/my-apache2:0.1.0 .
```
This command builds the image, and tags it with `ghcr.io/dataone/my-apache2:0.1.0` - [see
the publishing prerequisites, below,](#prerequisites) for more on tagging.

#### Multi-Platform Builds

Multi-platform builds can be supported using docker buildx. First you have to create a builder
targeting the platforms of choice, and then you can use it to build an image for those
architectures. Here's an example showing a build for arm64 and amd64, and pushing the resulting
image to GHCR (you need to be logged in before pushing, as described in the section on [the
publishing prerequisites, below,](#prerequisites)):
```shell
docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder
docker buildx inspect --bootstrap
docker buildx build --platform linux/arm64/v8,linux/amd64 --push -t ghcr.io/dataone/my-apache2:0.1.0 .
```

> #### Running a Container
>
> In Kubernetes, containers are typically created from images automatically, as part of a helm
> deployment. However, it is possible to manually create containers from images, using the
> `docker run` command; e.g.:
>
> ```shell
> docker run -d -p 8080:80 ghcr.io/dataone/my-apache2:0.1.0
> ```
>
> This will run the container in the background and map http://localhost:8080 to port 80 in the
> container.
>
> Other useful commands:
> * Listing local images: `docker image ls`
> * Listing local containers: `docker ps`
> * Stopping a container: `docker stop <id>` (where id is found in the above listing)

###  Publishing Docker Images to the GitHub Container Registry (GHCR)

Containers can be pushed to a container registry using the `docker push` command.

#### Prerequisites

* Before pushing to GHCR, you will need to create and log in with a personal access token (PAT). To
 create: in GH, click on your user icon > Settings > Developer settings > Personal access tokens.
* To log in:

  ```shell
  echo $PAT | docker login ghcr.io -u your-gh-username --password-stdin
  ```

* **IMPORTANT:** before publishing, make sure you have labeled the image correctly, to ensure it
  will be associated with the correct target repo when pushed to GHCR. This label should have been
  included in the Dockerfile used to build the image - see [Building a Docker Image example,
  above](#building-a-docker-image); i.e.:

  ```Dockerfile
  # Connect this image to a GitHub repository
  LABEL org.opencontainers.image.source="https://github.com/dataoneorg/my-apache2"
  ```

#### Push the image

```shell
docker push ghcr.io/nceas/my-apache2:0.1.0
```
* ⚠️ **NOTE**: whenever you publish a new image for the very first time, it may be necessary for a
  GitHub admin to change its visibility from `Private` to `Public` in the package settings. This is
  only a one-time requirement, and will not be necessary for subsequent pushes.

## Helm Charts: Packaging and Publishing to GHCR

### Packaging a Helm Chart

Helm charts are packaged as a gzipped tarball (`*.tgz`), which is created using the `helm package`
command. The chart should be in a directory with the following structure:

```
helm/
  Chart.yaml
  values.yaml
  templates/
  ...etc
```

To package the chart:

```shell
helm package -u ./helm

# where -u updates the dependencies before packaging
```

### Publishing a Helm Chart to GHCR

Helm charts can then be published to GHCR using the `helm push` command.

#### Prerequisites

* Before pushing, you will need to create and log in with a personal access token (PAT), [as
  described above in the section on publishing docker
  images](#publishing-docker-images-to-the-github-container-registry-ghcr).

* **IMPORTANT:** before publishing, make sure you have labeled the chart correctly, to ensure it
  will be associated with the correct target repo when pushed to GHCR. This label should have been
  included in the Chart.yaml (example for the dataone-indexer):

  ```yaml
  apiVersion: v2
  name: my-apache2-app
  description: |
    Helm chart for Kubernetes Deployment of my-apache2-app

  ## OCI Annotations - see https://github.com/helm/helm/pull/11204
  ## This is the URL of the source code repository
  ## and its presence ensures GHCR will associate the chart with the correct repo
  ##
  sources:
  - https://github.com/dataoneorg/dataone-indexer

  # ...etc
  ```

#### Publish the chart
```shell
helm push <my-versioned-chart-name>.tgz oci://ghcr.io/dataoneorg/charts
```

⚠️ **IMPORTANT NOTES:**

1. **Don't forget the `/charts` path segment!** It's a convention we are using across our repos and
   orgs to separate charts from docker images within GHCR.
2. Whenever you publish a new chart for the very first time, it may be necessary for a
   GitHub admin to change its visibility from `Private` to `Public` in the package settings. This is
   only a one-time requirement, and will not be necessary for subsequent pushes.
