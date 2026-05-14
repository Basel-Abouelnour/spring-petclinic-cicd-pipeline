# End To End Pipeline To Deploy Spring PetClinic Sample Application 
## Outline:
1. [Overview about the project](#1-overview-about-the-project)
2. [Containerization with Docker & Docker Compose](#2-containerization-with-docker--docker-compos)
3. [Continious Integration with GitHub Actions](#3-continious-integration-with-github-actions)
4. [Deploying the application in Kubernetes environment](#4-deploying-the-application-in-kubernetes-environment)
5. [Continious Deployment using ArgoCD](#5-continious-deployment-using-argocd)
6. [Running application showcase](#6-running-application-showcase)

## 1. Overview about the project
This project is meant to ease the build, test and deployment process of Spring PetClinic, an application built with java using Spring Boot. 
The Technologies that are used in this application are the following:
|                  | Tools / Technologies               |
| ---------------- | ---------------------------------- |
| Development      | JDK 17, Maven 3                    |
| Containerization | Docker, Docker Compose, Kubernetes |
| CI/CD            | GitHub Actions, ArgoCD             |


## 2. Containerization with Docker & Docker Compose
Docker is used in this step to make the deployment of the application lightwaight, portable, and os independent, the docker file mentioned in this step is located here [Dockerfile](/Dockerfile).

### Builder Stage
- First we need to choose a base image to build our image from, the used image is `dhi.io/maven:3-jdk25-debian13-deva` a Docker Hardened Image which is the recommended maven image from docker hub
- Most of the steps for using this image were mentioned in the [guide](https://hub.docker.com/hardened-images/catalog/dhi/maven/guides) section of the docker hub image page.
- This image provides the full utilities needed to build and package the application using maven.
- After building the application we will copy the final packages from this stage to the runtime stage.
### Runtime Stage
- In the runtime stage we need a lightwaight and distroless Image to minimize the size and security risks for our running application.
- My choice came to `eclipse-temurin:17-jre-alpine-3.23` as it's an official Docker image form docker hub that provides Java Runtime Environment needed for running the appliaction, and also with alpine tag it has a minimized size compared to the other images.
- We will change the container user to `petclinic` , because the default user for this image is Root which could case a security risk.
- Then we change the working directory and copy our package from the `Builder` stage into this stage
- Finally we expose the container port and provide the application starting command.
### Docker Compose 
Docker compose is a docker utility that allows us to package, build, and run multible services from one file, containing their needed volumes and networks. This could be useful for testing functionality in pipelines before deploying to actual working environment. . The mentioned Compose file is located here: [docker-compose.yaml](/docker-compose.yml)

#### services:
1. MySQL:
    - Used a standard Image.
    - Used the provided environment variables from the application.
    - Moved the env to a separate file as pest practice.
    - Added health checks to make sure the container is up and running.
    - Added volume to persist data across container lifecyle.
2. Application:
    - Uses the context of the Dockerfile to build if needed.
    - Uses the generated Image from the Dockerfile
    - Expose only needed port.
    - Separated environment variables from the file.
    - Made sure the application start when MySQL is ready for connection.
    - Restart the application in case of failure.
> Note On Using MySQL: The application has a specific env variable that tells the application to use mysql instead of postgresql.

To build or run the Docker compose file use the following commands:
```bash
docker compose build
docker compose up -d
docker compose ps
```
## 3. Continious Integration with GitHub Actions
GitHub Actions is an automation platform built nativly within GitHub that can execute our needed tests and builds, which is suitable to our Continious Integration Objectives. The workflow file is located here [ci.yaml](.github\workflows\ci.yaml)
The pipeline consists mainly of 3 jobs:
1. Compile and Test the application
    - This job performs the Maven compile and tests to make sure the application is ready for the next step.
2. Build and Push the Docker Image
    - This job builds the image and pushes it into public repository (Docker Hub), the credentials for pushing were saved as a secret in the GitHub repository.
3. Modify the Image tag in Kubernetes Manifests
    - This job changes the tag of the Image in the kubernetes manifests with the newly pushed image and pushes the changes without triggering the CI again.

## 4. Deploying the application in Kubernetes environment
> Note: this step needs kubernetes environment with ingress controller installed.
The used in this project is k3s with traefik, but anything else should work. 

Kubernetes is a Container Orchestration tool that provide a scalability and high availability to our containerized application, the manifests for this step are located in the [k8s folder](/k8s/):
- The structure of the folder is as following
```bash
k8s/
|-- 0-ns.yaml
|-- db.secret.yaml
|-- db.svc.yaml
|-- db.yml
|-- ingress.yaml
|-- petclinic.secret.yaml
|-- petclinic.svc.yaml
`-- petclinic.yml
```
- The Deployments ensure the desired number of the specified application is running.
- The DB service enables internal communication with other pods.
- The Secrets store the critical variables encoded.
- The NodePort service enables access the application from outside the cluster with specifying each node ip with the node port generated.
- The Ingress provides access from outside the cluster with DNS resolution to the desired service.
- All the application workloads are deployed in a separate namespace for better resource control and isolation.
> Note: to access the application from the browser you need to add a DNS local entry in you `/etc/hosts` file in linux. If you're on windows use this command: 
`Add-Content C:\Windows\System32\drivers\etc\hosts "<worker-ip> petclinic.local"`

To create the kubernetes workloads use the following command:
```bash
kubectl apply -f k8s/.
```
## 5. Continious Deployment using ArgoCD
ArgoCD is a Continious Deployment tool that implements the GitOps concept by having only one source of truth for the kubernetes application, which is the GitHub repository.

To Allow ArgoCD communicate with our GitHub repo we can use token based authentication or ssh based authentication. In my case I used ssh keys method.

We create a kubernetes `Application` object to allow ArgoCd track our applicaiton with the following specs:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: petclinic
  namespace: argocd         # namespace of the `application` resource
spec:
  project: default  
  source:
    repoURL: 'git@github.com:Basel-Abouelnour/spring-petclinic-cicd-pipeline.git' # SSH Endpoint for the repo, the endpoint will depend on how you connect.
    path: k8s         # the path to tracked manifests
    targetRevision: main    # the branch to track
  destination:
    server: 'https://kubernetes.default.svc'  # the local k3s cluster to deploy to
    namespace: petclinic    #namespace of my worklowds
  syncPolicy:
    automated:   # enable auto-syncing
      selfHeal: true  # auto-correct any drift from the desired state
      prune: false     # allow deletion of resources that are no longer mentioned in the source
```
Now, once we create this application resource, our application will be automatically deployed to the cluster once the git repository is updated. 
> Note: ArgoCD pulls the changes from the repo periodically, and this period can be controller. I left it to the default in this case.
## 6. Running application showcase
In this section I'll show case an instance of the running application.
1. Docker Compose Running:
![docker compose up -d](/images/docker-compose.png)
2. Successful CI Pipeline
![GitHub Actions Workflow](/images/ci-successful.png)
3. Kubernetes Workloads Running:
![kubectl get all -n petclinic](/images/k8s-get-all.png)
4. ArgoCD Application Synced
![ArgoCD APplication Synced](/images/argocd-sync.png)
5. Application Accessible from Browser
![browser-ingress](/images/browser-ingress.png)
6. Database Working in the application
![broswer-data](/images/browser-data.png)

