# DevOps Platform Foundation — Complete Project Documentation

> **Status:** Foundation complete · GitOps pipeline live · Observability stack running
> **Author:** Prachi · Senior DevOps & Platform Engineer
> **Last updated:** April 2026

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [What Was Built](#3-what-was-built)
4. [Full Setup Guide](#4-full-setup-guide)
5. [Azure Roles & Permissions](#5-azure-roles--permissions)
6. [GitHub Secrets Setup](#6-github-secrets-setup)
7. [Verification Checklist](#7-verification-checklist)
8. [Screenshots to Take](#8-screenshots-to-take-for-portfolio)
9. [Teardown & Recreate](#9-teardown--recreate)
10. [Architecture Decision Records](#10-architecture-decision-records)
11. [Interview Talking Points](#11-interview-talking-points)
12. [Next Phases Roadmap](#12-next-phases-roadmap)

---

## 1. Project Overview

### What this is

A production-grade GitOps platform on Azure Kubernetes Service — provisioned
with Terraform, deployed via ArgoCD, observed through Prometheus + Grafana +
Loki. This is the shared foundation for three portfolio projects:

| Project | Description |
|---|---|
| Foundation (this) | AKS + GitOps + Observability |
| Project 2 | FinOps Intelligence Engine — AI cost anomaly detection |
| Project 3 | Agentic AIOps — autonomous observability + runbook generator |
| Project 4 | AI-Native Internal Developer Platform (IDP) |

### Why it stands out

Most DevOps portfolios show tool lists. This project shows decisions:
- Every architectural choice has a written ADR explaining the trade-off
- The GitOps loop is fully automated — no manual kubectl apply ever
- The stack is designed to be extended, not just demonstrated
- Cost-conscious by design — destroy/recreate in 8 minutes

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Developer                               │
│                    git push / pull request                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Repository                          │
│           terraform/ · gitops/ · observability/ · docs/         │
└──────────┬──────────────────────────────────┬───────────────────┘
           │ triggers                          │ watches
           ▼                                   ▼
┌─────────────────────┐            ┌───────────────────────────┐
│   GitHub Actions    │            │          ArgoCD           │
│                     │            │                           │
│  On Pull Request:   │            │  Watches gitops/ folder   │
│  · terraform fmt    │            │  Auto-syncs on git push   │
│  · terraform valid  │            │  Self-heals cluster drift │
│  · terraform plan   │            │  Visual diff UI           │
│  · post PR comment  │            │                           │
│                     │            └─────────────┬─────────────┘
│  On merge to main:  │                          │ deploys
│  · terraform apply  │                          │
└─────────────────────┘                          │
           │ provisions                          │
           ▼                                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AKS Cluster (Azure)                        │
│                                                                 │
│  ┌──────────────────┐      ┌──────────────────────────────────┐  │
│  │  sample-app ns   │      │        monitoring ns             │  │
│  │                  │      │                                  │  │
│  │  · Deployment    │      │  · Prometheus (metrics)          │  │
│  │  · Service       │      │  · Grafana (dashboards)          │  │
│  │  · HPA (2-5)     │      │  · Loki (logs)                   │  │
│  │  · ConfigMap     │      │  · Alertmanager (alerts)         │  │
│  └──────────────────┘      └──────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────┐      ┌──────────────────────────────────┐  │
│  │    argocd ns     │      │      [future namespaces]         │  │
│  │  · ArgoCD server │      │  · finops-engine (Project 2)     │  │
│  │  · App controller│      │  · aiops-agent (Project 3)       │  │
│  │  · Redis         │      │  · idp-platform (Project 4)      │  │
│  └──────────────────┘      └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  Azure Container Registry (ACR)  │
│  · Private image registry        │
│  · AKS granted AcrPull via RBAC  │
│  · Managed identity (no secrets) │
└──────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  Log Analytics Workspace         │
│  · AKS control plane logs        │
│  · Container insights            │
│  · 30-day retention              │
└──────────────────────────────────┘
```

### GitOps flow (end to end)

```
1. Developer edits gitops/apps/sample-app/manifests.yaml
2. git push to feature branch
3. GitHub Actions runs: fmt → validate → plan → posts plan to PR
4. PR reviewer sees exact infrastructure diff in PR comment
5. PR merged to main
6. GitHub Actions runs terraform apply (with manual approval gate)
7. ArgoCD detects drift between Git state and cluster state
8. ArgoCD syncs automatically within 3 minutes
9. Change is live — zero manual kubectl apply
10. Prometheus scrapes new pod metrics
11. Grafana dashboards update in real time
```

---

## 3. What Was Built

### Infrastructure (Terraform)

| Resource | Name | Purpose |
|---|---|---|
| Resource Group | `devops-platform-rg` | Container for all Azure resources |
| AKS Cluster | `devops-platform-aks` | 1 node, Standard_B2s, K8s 1.32 |
| Node Pool | `system` | Single node pool, auto-scaling off |
| ACR | `devopsplatformacr` | Private container registry |
| Log Analytics | `devops-platform-aks-logs` | AKS control plane + container logs |
| Role Assignment | AKS → AcrPull → ACR | Managed identity, no credentials |

### Kubernetes workloads

| Namespace | Component | Type |
|---|---|---|
| `argocd` | ArgoCD server, controller, Redis | GitOps operator |
| `monitoring` | kube-prometheus-stack | Metrics + dashboards |
| `monitoring` | Loki + Promtail | Log aggregation |
| `sample-app` | Nginx deployment | Demo app (2 replicas, HPA 2-5) |

### CI/CD pipeline (GitHub Actions)

| Job | Trigger | What it does |
|---|---|---|
| `terraform-validate` | Pull request | fmt check + validate |
| `terraform-plan` | Pull request | Plan + posts diff as PR comment |
| `terraform-apply` | Merge to main | Apply with manual approval gate |
| `k8s-validate` | Pull request | Validates all YAML manifests |

### Repository structure

```
devops-platform-foundation/
├── .github/
│   └── workflows/
│       └── platform-ci-cd.yml
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── modules/
│       ├── aks/
│       ├── acr/
│       └── networking/
├── gitops/
│   ├── apps/
│   │   └── sample-app/
│   │       └── manifests.yaml
│   └── infrastructure/
├── observability/
│   ├── prometheus/
│   │   └── values.yaml
│   ├── grafana/
│   └── loki/
└── docs/
    ├── architecture/
    └── adr/
        ├── ADR-001-gitops-tool-choice.md
        ├── ADR-002-prometheus-over-azure-monitor.md
        └── ADR-003-helm-over-raw-manifests.md
```

---

## 4. Full Setup Guide

Follow these steps every time you recreate the environment from scratch.

### Prerequisites — install on Mac

```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install all tools
brew install azure-cli terraform kubectl helm git argocd
brew install --cask visual-studio-code

# Verify
az --version && terraform --version && kubectl version --client && helm version
```

### Step 1 — Clone repo

```bash
git clone https://github.com/vmprachi7/devops-platform-foundation.git
cd devops-platform-foundation
```

### Step 2 — Azure login

```bash
az login
az account show
# Note the "id" field = your Subscription ID
```

### Step 3 — Set Terraform auth environment variables

```bash
export ARM_CLIENT_ID="your-sp-appId"
export ARM_CLIENT_SECRET="your-sp-password"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"

# Make permanent across terminal sessions
echo 'export ARM_CLIENT_ID="your-sp-appId"' >> ~/.zshrc
echo 'export ARM_CLIENT_SECRET="your-sp-password"' >> ~/.zshrc
echo 'export ARM_TENANT_ID="your-tenant-id"' >> ~/.zshrc
echo 'export ARM_SUBSCRIPTION_ID="your-subscription-id"' >> ~/.zshrc
source ~/.zshrc
```

### Step 4 — Provision infrastructure

```bash
cd terraform/environments/dev

terraform init
terraform fmt
terraform validate
terraform plan          # review output carefully
terraform apply -auto-approve

# Takes 5–8 minutes
```

### Step 5 — Configure kubectl

```bash
az aks get-credentials \
  --resource-group devops-platform-rg \
  --name devops-platform-aks

kubectl get nodes
# Expected: aks-system-XXXXXXXX-vmssXXXXXX   Ready   <none>   Xm   v1.32.X
```

### Step 6 — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=120s

# Get admin password
argocd admin initial-password -n argocd

# Access UI (keep this terminal open)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` — username: `admin`, password from above command.

```bash
# Login via CLI (new terminal tab)
argocd login localhost:8080 --username admin --insecure

# Connect GitHub repo
argocd repo add https://github.com/vmprachi7/devops-platform-foundation \
  --username vmprachi7 \
  --password YOUR_GITHUB_PAT
```

### Step 7 — Deploy sample app via GitOps

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f gitops/apps/sample-app/manifests.yaml

# Watch pods come up
kubectl get pods -n sample-app -w

# Access the app
kubectl port-forward svc/sample-app -n sample-app 8888:80
# Open: http://localhost:8888
```

### Step 8 — Install observability stack

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

# Prometheus + Grafana
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d

# Loki
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false

# Access Grafana (keep terminal open)
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000 — admin / admin123
```

### Step 9 — Verify full stack

```bash
kubectl get nodes
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n sample-app
argocd app list
```

---

## 5. Azure Roles & Permissions

### Service Principal roles required

| Role | Scope | Why it's needed |
|---|---|---|
| `Contributor` | Subscription | Create and manage all Azure resources (RG, AKS, ACR, Log Analytics) |
| `User Access Administrator` | Subscription | Assign AcrPull role from AKS managed identity to ACR |

> Without `User Access Administrator`, Terraform's `azurerm_role_assignment`
> resource fails with a 403 Forbidden error.

### Create Service Principal with both roles

```bash
# Step 1 — Create SP with Contributor
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"

# Save the output:
# appId     → ARM_CLIENT_ID
# password  → ARM_CLIENT_SECRET  (shown ONCE only — save immediately)
# tenant    → ARM_TENANT_ID

# Step 2 — Add User Access Administrator
az role assignment create \
  --assignee "YOUR_SP_APP_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"

# Step 3 — Verify both roles assigned
az role assignment list \
  --assignee "YOUR_SP_APP_ID" \
  --output table
```

### What each Terraform resource needs

| Terraform resource | Azure role required |
|---|---|
| `azurerm_resource_group` | Contributor |
| `azurerm_kubernetes_cluster` | Contributor |
| `azurerm_container_registry` | Contributor |
| `azurerm_log_analytics_workspace` | Contributor |
| `azurerm_role_assignment` | User Access Administrator |

---

## 6. GitHub Secrets Setup

### Add secrets to your repo

Go to: GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Where to get the value |
|---|---|
| `ARM_CLIENT_ID` | `appId` from Service Principal creation |
| `ARM_CLIENT_SECRET` | `password` from Service Principal creation |
| `ARM_TENANT_ID` | `tenant` from Service Principal creation |
| `ARM_SUBSCRIPTION_ID` | `az account show` → `id` field |

### Create production environment (manual approval gate)

Go to: GitHub repo → **Settings → Environments → New environment**
- Name: `production`
- Enable: **Required reviewers** → add yourself
- This means terraform apply needs manual approval — shows production-safe practices

---

## 7. Verification Checklist

Run these commands after every setup to confirm everything is healthy.

### Infrastructure

```bash
# AKS node ready
kubectl get nodes
# EXPECTED: STATUS = Ready

# All namespaces present
kubectl get namespaces
# EXPECTED: argocd, monitoring, sample-app, default, kube-system
```

### ArgoCD

```bash
# All ArgoCD pods running
kubectl get pods -n argocd
# EXPECTED: all STATUS = Running

# App synced
argocd app list
# EXPECTED: sample-app  Synced  Healthy

# App details
argocd app get sample-app
# EXPECTED: Sync Status: Synced, Health Status: Healthy
```

### Sample app

```bash
# Pods running
kubectl get pods -n sample-app
# EXPECTED: 2 pods, STATUS = Running

# HPA status
kubectl get hpa -n sample-app
# EXPECTED: MINPODS=2, MAXPODS=5, REPLICAS=2

# App responding
kubectl port-forward svc/sample-app -n sample-app 8888:80 &
curl http://localhost:8888
# EXPECTED: HTML response with platform info
```

### Observability

```bash
# All monitoring pods running
kubectl get pods -n monitoring
# EXPECTED: prometheus, grafana, alertmanager, loki, promtail all Running

# Prometheus targets healthy
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090 &
# Open: http://localhost:9090/targets
# EXPECTED: all targets green (up)

# Grafana accessible
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80 &
# Open: http://localhost:3000
# EXPECTED: login page, then dashboards visible
```

### GitHub Actions

```bash
# Check latest workflow run
# Go to: github.com/vmprachi7/devops-platform-foundation/actions
# EXPECTED: green checkmarks on all jobs
```

---

## 8. Screenshots to Take (for Portfolio)

Take these screenshots while the cluster is running.
Save them in `docs/screenshots/` and reference them in README.

### Screenshot 1 — AKS node running (Azure Portal)
```
Where: portal.azure.com → search "devops-platform-aks" → Overview
What to capture: cluster status "Running", Kubernetes version, node count
Why: proves real Azure infrastructure, not just local Docker
```

### Screenshot 2 — kubectl get nodes (Terminal)
```
Command: kubectl get nodes
What to capture: node name, STATUS=Ready, Kubernetes version
Why: shows you know how to work with a live cluster
```

### Screenshot 3 — ArgoCD UI — app synced
```
Where: https://localhost:8080 (port-forward argocd-server)
What to capture: sample-app tile showing "Synced" + "Healthy" in green
Why: this is the visual proof of GitOps working — most impactful screenshot
```

### Screenshot 4 — ArgoCD app tree view
```
Where: ArgoCD UI → click on sample-app → click "App Details" tree view
What to capture: the deployment tree (Deployment → ReplicaSet → Pods)
Why: shows ArgoCD's live view of cluster state vs desired state
```

### Screenshot 5 — Grafana — Kubernetes dashboards
```
Where: http://localhost:3000 → Dashboards → Kubernetes / Compute Resources / Cluster
What to capture: CPU usage graph, memory graph, pod count
Why: shows observability setup, directly maps to your Datadog experience
```

### Screenshot 6 — Grafana — pod-level metrics
```
Where: Grafana → Dashboards → Kubernetes / Compute Resources / Namespace (Pods)
Select namespace: sample-app
What to capture: CPU/memory graphs for both sample-app pods
Why: shows resource monitoring at pod level — what you did at Capgemini with Datadog
```

### Screenshot 7 — Prometheus targets
```
Where: http://localhost:9090/targets
What to capture: list of targets, all green/up
Why: shows metrics pipeline is healthy end to end
```

### Screenshot 8 — GitHub Actions — successful pipeline run
```
Where: github.com/vmprachi7/devops-platform-foundation → Actions tab
What to capture: green checkmarks on all 4 jobs (validate, plan, apply, k8s-validate)
Why: shows CI/CD automation — not just infrastructure, but delivery automation
```

### Screenshot 9 — GitHub Actions — PR plan comment
```
How: create a test branch, make a small change to variables.tf, open a PR
Where: the PR page → Comments section
What to capture: the terraform plan output posted as a PR comment
Why: this is the "wow" moment — shows production-safe infra changes
```

### Screenshot 10 — Sample app in browser
```
Where: http://localhost:8888 (port-forward sample-app)
What to capture: the platform info page in browser
Why: end-to-end proof — code in Git → ArgoCD → running app in AKS
```

### Screenshot 11 — Azure Cost (free tier confirmation)
```
Where: portal.azure.com → Cost Management → Cost analysis
What to capture: cost graph showing minimal/zero spend (free tier)
Why: shows FinOps awareness — you built production infra within budget
```

### Optional — GIF recording of GitOps loop
```
Tool: Quicktime (built into Mac) or Loom (free)
What to record:
  1. Edit manifests.yaml in VS Code (change a value)
  2. git commit && git push (terminal)
  3. Switch to ArgoCD UI — watch the sync animation happen live
  4. Refresh http://localhost:8888 — see the change

Duration: 60–90 seconds
Why: this is your portfolio hero asset — replaces 1000 words of explanation
```

---

## 9. Teardown & Recreate

### Teardown (always do this when done working)

```bash
cd terraform/environments/dev
terraform destroy -auto-approve

# Confirm in Azure Portal — resource group should be empty
# This saves your $200 free credit for when you actually need it
```

### Recreate (8–10 minutes, one paste)

```bash
cd terraform/environments/dev && terraform apply -auto-approve && \
az aks get-credentials --resource-group devops-platform-rg --name devops-platform-aks && \
kubectl create namespace argocd && \
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml && \
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s && \
kubectl create namespace monitoring && \
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --set grafana.adminPassword=admin123 && \
helm install loki grafana/loki-stack --namespace monitoring \
  --set grafana.enabled=false --set prometheus.enabled=false && \
kubectl apply -f gitops/apps/sample-app/manifests.yaml && \
kubectl get pods -A
```

---

## 10. Architecture Decision Records

### ADR-001: ArgoCD over Flux

**Decision:** Use ArgoCD as the GitOps operator.
**Reason:** Built-in UI for visualising sync state is critical for demos and
stakeholder visibility. Stronger multi-cluster RBAC. Visual diff capability
that Flux lacks. The UI becomes a portfolio asset, not just an ops tool.
**Trade-off:** ~200MB extra memory vs Flux.

### ADR-002: Prometheus over Azure Monitor native

**Decision:** Use kube-prometheus-stack instead of Azure Monitor Container Insights.
**Reason:** Vendor-independent (portable to EKS, GKE). No per-GB ingestion
cost. kube-prometheus-stack includes pre-built Kubernetes dashboards. Native
Grafana + Loki integration in a single UI.
**Trade-off:** Self-managed Prometheus pods vs zero-maintenance Azure Monitor.

### ADR-003: Helm over raw Kubernetes manifests

**Decision:** Use Helm for all cluster deployments.
**Reason:** Parameterisation without manifest duplication. Versioned releases
with rollback. Aligns with how upstream tools (ArgoCD, Prometheus) are
maintained. First-class ArgoCD support.
**Trade-off:** Go templating learning curve for teams new to Helm.

---

*Documentation maintained by Prachi · devops-platform-foundation*
