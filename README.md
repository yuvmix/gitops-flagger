# GitOps Flagger

This is a demonstration of using Flux to perform Continuous Deployment on Kubernetes.


## Introduction

### What is GitOps?

GitOps is a methodology that uses Git as a source of truth for declarative infrastructure and configuration. In Kubernetes, this means using `git push` instead of `kubectl apply`.

### What is Progressive Delivery?

Progressive Delivery is the next step from only using GitOps. By using GitOps alone, updating a configuration file would simply override the current configuration in the runtime. What we want is to gradually progress the deployment in order to reduce the **blast radius** of risks that software updates may cause.

This can be done with Flagger as the Progressive Delivery tool that uses a Service Mesh such as Istio for the network configurations.

Common progressive deployment methods are canaries, feature flags and A/B testing.

In this demo, we'll be using minikube, Flux, Flagger and Istio. 

The application we'll run is a Flask application which uses HashiCorp Vault to obtain dynamic credentials for MongoDB, as well as use Vault's Transit secrets engine to encrypt the data sent to MongoDB.
The code for the application can be found [here](https://github.com/raakatz/vault-mongodb).

### Flagger

Flagger watches a Deployment/StatefulSet. It immediatly scales down the original Deployment and create its own Deployment with a "-primary" suffix, as well as primary and canary Services and VirtualServices and DestinationRules for them.

When a new Deployment is applied, Flagger automatically adjusts the relevant resources to balance traffic to the canary, and continuously analyses it to increate the percents for positive metrics, or rollback for negative metrics. These can be custom application metrics, latency respones, REST responses, etc.

![Flagger Overview](/docs/images/flagger-overview.png)

## Prerequisites

1. You'll need a Kubernetes cluster with 2 CPUs and 4GB of RAM that supports LoadBalancer Service type. With minikube, this can be used with `minikube tunnel -c &`

2. You'll need a fork of this repo.

3. Flux CLI, can be downloaded from [here](https://fluxcd.io/flux/cmd/)

4. [yq](https://github.com/mikefarah/yq)

5. Run a pre-check with `flux check --pre`

## Setup

Bootstrap your cluster to get all of its configurations from this repo (your fork)

```bash
flux bootstrap git \
  --author-email=<YOUR-EMAIL> \
  --url=ssh://git@github.com/<YOUR-USERNAME>/gitops-flagger \
  --path=clusters/my-cluster
```

At bootstrap, Flux generates an SSH key and prints the public key.
In order to sync your cluster state with git you need to copy the public key and create a deploy key with write 
access on your GitHub repository. On GitHub go to _Settings > SSH and GPG Keys_ click on _New SSH key_ and paste Flux's key.
Type _y_ on Flux's prompt.

Flux will bootstrap the following resources in the right order of dependency:
* Istio Control Plane and Gateway in "istio-system" Namespace
* Flagger components in "flagger-system" Namespace
* HashiCorp Vault in "vault" Namespace
* Terraform runner that configures Vault
* Webapp and database in "prod" Namespace
* Canary for webapp

You can track Flux's progress with

```bash
watch flux get kustomization
```

You can see Flux's logs with

```bash
flux logs --all-namespaces --follow
```

Check if Flagger has successfully initialized the canaries: 

```
kubectl -n prod get canaries
NAME       STATUS        WEIGHT
webapp     Initialized   0
```

Find the Istio ingress gateway address with:

```bash
kubectl -n istio-system get svc istio-ingress -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Open a browser and navigate to the ingress address, you'll see the frontend UI.

## Canary

We want to issue a new release that changes the button's color to green to see if it grows our business's objectives
Bump the application's version to 0.0.2

```bash
git clone ssh://git@github.com/<YOUR-USERNAME>/gitops-flagger
cd gitops-flagger
yq -i '.images[0].newTag = "0.0.2"' './apps/webapp/kustomization.yaml'
```

Commit and push changes:

```bash
git add . && \
git commit -m "webapp 0.0.2" && \
git push origin main
```

Tell Flux to pull the changes or wait one minute for Flux to detect the changes on its own:

```bash
flux reconcile source git flux-system
```

Watch the live traffic balancing to your application by running:
```bash
export ISTIO_INGRESS_IP=$(kubectl -n istio-system get svc istio-ingress -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
while true; do curl -s http://${ISTIO_INGRESS_IP} | grep button-color; sleep 1; done
```

After a couple of seconds, Flagger detects that the deployment revision changed and starts a new rollout:

```bash
kubectl -n flagger-system logs -f $(kubectl -n flagger-system get pods -l app.kubernetes.io/name=flagger -o name)

New revision detected! Scaling up webapp.prod
Starting canary analysis for webapp.prod
Pre-rollout check conformance-test passed
Advance webapp.prod canary weight 10
...
Advance webapp.prod canary weight 50
Copying webapp.prod template spec to webapp-primary.prod
Promotion completed! Scaling down webapp.prod
```

## Application usage

To see the application in action, use it's UI to "register" and send some data to the database.

You can see the dynamic credentials that the application obtained from Vault by running:

```bash
kubectl -n prod logs $(kubectl -n prod get pods -l app=webapp-primary -o jsonpath="{.items[0].metadata.name}")
```

We'll log in to our database and see the data we entered, with the credit card encrypted

```bash
kubectl -n prod exec -it $(kubectl -n prod get pods -l app.kubernetes.io/component=mongodb -o jsonpath="{.items[0].metadata.name}") -- mongosh -u <user> -p <password> --authenticationDatabase my_database
use my_database;
db.users.find( { } );
```

Set the encryped data as a variable
```bash
export ENCRYPTED=<ENCRYPTED DATA>
```

To see our decrypted data, we'll do so from vault
```bash
kubectl -n vault exec vault-0 -- env VAULT_TOKEN=root VAULT_ADDR=http://localhost:8200 vault write -field=plaintext transit/decrypt/my-key ciphertext=${ENCRYPTED} | base64 -d
```
