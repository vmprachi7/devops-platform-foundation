# DevOps Platform Foundation

> A production-grade, GitOps-driven platform on Azure Kubernetes Service — provisioned with Terraform, deployed via ArgoCD, and observed through a full Prometheus + Grafana + Loki stack. Built as the shared foundation for an AI-native Internal Developer Platform (Project 1), a FinOps Intelligence Engine (Project 2), and an Agentic AIOps system (Project 3).

![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?logo=terraform)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange?logo=argo)
![Azure](https://img.shields.io/badge/Azure-AKS-0078D4?logo=microsoftazure)
![Grafana](https://img.shields.io/badge/Grafana-Observability-F46800?logo=grafana)

---

## What this is

Most DevOps portfolios show a list of tools. This project shows **a decision**. Every component here was chosen deliberately — ArgoCD over Flux, Prometheus over Azure Monitor native, modular Terraform over monolithic scripts. The Architecture Decision Records in `/docs/adr/` explain each trade-off.

This foundation is intentionally reusable. Projects 2 and 3 in this portfolio plug directly into this stack without reprovisioning infrastructure.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GitHub Repo                          │
│         (Terraform IaC + Helm values + App manifests)       │
└──────────────┬──────────────────────────┬───────────────────┘
               │ push                     │ sync
               ▼                          ▼
┌──────────────────────┐    ┌─────────────────────────────────┐
│   GitHub Actions     │    │           ArgoCD                │
│  - terraform plan    │    │  - Watches gitops/ folder       │
│  - terraform apply   │    │  - Auto-syncs on git push       │
│  - validate configs  │    │  - Self-heals drift             │
└──────────────────────┘    └────────────────┬────────────────┘
                                             │ deploys
                                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    AKS Cluster (Azure)                      │
│                                                             │
│  ┌─────────────────┐   ┌─────────────────────────────────┐  │
│  │  App Namespaces  │   │      monitoring namespace       │  │
│  │  - sample-app   │   │  - Prometheus (metrics)         │  │
│  │  - project-2    │   │  - Grafana (dashboards)         │  │
│  │  - project-3    │   │  - Loki (logs)                  │  │
│  └─────────────────┘   │  - Alertmanager (alerts)        │  │
│                        └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────┐
│  Azure Container Registry (ACR)  │
│  Private image registry          │
│  AKS granted AcrPull via RBAC    │
└──────────────────────────────────┘
```

---

## Stack

| Layer | Tool | Why |
|---|---|---|
| Cloud | Azure (AKS, ACR, Log Analytics) | Real enterprise cloud — 3 Azure certs, active at Capgemini |
| IaC | Terraform 1.6+ | Modular, version-controlled, repeatable environments |
| GitOps | ArgoCD | UI for drift visibility, stronger RBAC than Flux (see ADR-001) |
| Metrics | Prometheus + kube-prometheus-stack | Industry standard, no vendor lock-in |
| Dashboards | Grafana | Integrates Prometheus + Loki in one UI |
| Logs | Loki | Lightweight, integrates natively with Grafana |
| Package mgmt | Helm | Parameterised deployments, values in Git |
| Registry | Azure Container Registry | Native AKS integration via managed identity |

---

## Prerequisites

Before running this setup, you need the following installed on your machine:

```bash
brew install azure-cli terraform kubectl helm git argocd
```

Verify:

```bash
az --version
terraform --version
kubectl version --client
helm version
argocd version --client
```

---

## Azure Roles Required

The Service Principal created for Terraform needs these roles on your subscription:

| Role | Scope | Purpose |
|---|---|---|
| `Contributor` | Subscription | Create/manage all Azure resources |
| `User Access Administrator` | Subscription | Assign AcrPull role from AKS to ACR |

> Without `User Access Administrator`, the `azurerm_role_assignment` resource in Terraform will fail with a 403 error.

To assign both roles:

```bash
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"

# Then assign User Access Administrator separately
az role assignment create \
  --assignee "YOUR_SP_APP_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

---

## Setup from scratch

Follow these steps in order every time you recreate the environment.

### Step 1 — Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/devops-platform-foundation.git
cd devops-platform-foundation
```

### Step 2 — Authenticate to Azure

```bash
az login
az account show   # confirm correct subscription
```

### Step 3 — Set Terraform environment variables

```bash
export ARM_CLIENT_ID="your-sp-appId"
export ARM_CLIENT_SECRET="your-sp-password"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

> Add these to `~/.zshrc` so they persist across terminal sessions.

### Step 4 — Provision infrastructure with Terraform

```bash
cd terraform/environments/dev

terraform init
terraform fmt
terraform validate
terraform plan        # review what will be created
terraform apply -auto-approve
```

Provisioning takes **5–8 minutes**. Resources created:
- Resource Group: `devops-platform-rg`
- AKS Cluster: `devops-platform-aks` (1 node, Standard_B2s)
- Azure Container Registry: `devopsplatformacr`
- Log Analytics Workspace: `devops-platform-aks-logs`
- Role Assignment: AKS → AcrPull → ACR

### Step 5 — Configure kubectl

```bash
az aks get-credentials \
  --resource-group devops-platform-rg \
  --name devops-platform-aks

kubectl get nodes
# Expected: 1 node in Ready state
```

### Step 6 — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD server to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=120s

# Get admin password
argocd admin initial-password -n argocd
```

Access the ArgoCD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Username: admin
# Password: (from command above)
```

Connect your GitHub repo:

```bash
argocd login localhost:8080 --username admin --insecure

argocd repo add https://github.com/YOUR_USERNAME/devops-platform-foundation \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_PAT
```

> GitHub PAT: github.com → Settings → Developer settings → Personal access tokens → Generate → select `repo` scope.

### Step 7 — Install observability stack (Prometheus + Grafana + Loki)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

# Prometheus + Grafana
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d

# Loki for log aggregation
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false

# Verify all pods running
kubectl get pods -n monitoring
```

Access Grafana:

```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000
# Username: admin  |  Password: admin123
```

### Step 8 — Verify full stack

```bash
kubectl get nodes                    # 1 node Ready
kubectl get pods -n argocd           # all Running
kubectl get pods -n monitoring       # prometheus, grafana, loki all Running
```

---

## Teardown (save Azure credits)

Always destroy when not actively working:

```bash
cd terraform/environments/dev
terraform destroy -auto-approve
```

Recreate the full stack anytime in ~10 minutes using Steps 4–7 above.

---

## Repository structure

```
devops-platform-foundation/
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf          # AKS, ACR, Log Analytics, role assignments
│   │       ├── variables.tf     # All configurable inputs
│   │       └── outputs.tf       # Cluster name, ACR endpoint, kubeconfig
│   └── modules/
│       ├── aks/                 # (planned) reusable AKS module
│       ├── acr/                 # (planned) reusable ACR module
│       └── networking/          # (planned) VNet, subnets
├── gitops/
│   ├── apps/                    # ArgoCD Application manifests
│   └── infrastructure/          # Cluster-level resources (namespaces, RBAC)
├── observability/
│   ├── prometheus/
│   │   └── values.yaml          # Helm values for kube-prometheus-stack
│   ├── grafana/                 # Custom dashboard JSON exports
│   └── loki/                    # Loki configuration
└── docs/
    ├── architecture/            # Architecture diagrams
    └── adr/
        ├── ADR-001-gitops-tool-choice.md
        ├── ADR-002-prometheus-over-azure-monitor.md
        └── ADR-003-helm-over-raw-manifests.md
```

---

## Architecture Decision Records

| ADR | Decision | Status |
|---|---|---|
| [ADR-001](docs/adr/ADR-001-gitops-tool-choice.md) | ArgoCD over Flux for GitOps | Accepted |
| [ADR-002](docs/adr/ADR-002-prometheus-over-azure-monitor.md) | Prometheus over Azure Monitor native | Accepted |
| [ADR-003](docs/adr/ADR-003-helm-over-raw-manifests.md) | Helm for all cluster deployments | Accepted |

---

## Projects built on this foundation

| Project | Description | Status |
|---|---|---|
| [devops-platform-foundation](.) | AKS + GitOps + Observability base | ✅ Complete |
| [finops-intelligence-engine](../finops-intelligence-engine) | Azure cost anomaly detection with AI recommendations | 🚧 In progress |
| [agentic-aiops](../agentic-aiops) | Autonomous observability + AI runbook generator | 🔜 Planned |

---

## Interview talking points

**On architecture decisions:** "I chose ArgoCD over Flux because the visual diff UI is critical for demonstrating GitOps state to non-DevOps stakeholders — it's not just an ops tool, it's a communication tool. The ADR documents the full trade-off reasoning."

**On cost awareness:** "The cluster costs ~$0.10/hour on Standard_B2s. I destroy it with `terraform destroy` when not in use and recreate in 8 minutes. This mirrors how I approached cost optimisation at Capgemini — treat cloud spend like code, measure and control it."

**On reusability:** "This foundation is the base for three portfolio projects. I designed the namespace structure and Helm values so Projects 2 and 3 deploy into this cluster without touching the core infrastructure. That's platform thinking — build once, enable many."

---

*Built by Prachi · Senior DevOps & Platform Engineer · [LinkedIn](https://linkedin.com/in/prachi)*
