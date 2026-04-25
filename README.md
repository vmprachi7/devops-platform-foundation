# devops-platform-foundation

> Production-grade Kubernetes platform on Azure — provisioned with Terraform,
> delivered via ArgoCD GitOps, observed through Prometheus + Grafana + Loki.
> Two sample apps demonstrate HPA autoscaling and canary deployments.

![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?logo=terraform)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange?logo=argo)
![Azure](https://img.shields.io/badge/Azure-AKS-0078D4?logo=microsoftazure)
![Grafana](https://img.shields.io/badge/Grafana-Observability-F46800?logo=grafana)

---

## What this repo is

This is the **platform layer** — it owns infrastructure, GitOps configuration,
observability, and two sample apps that demonstrate platform capabilities.

Application repos (finops-engine, agentic-aiops, idp-platform) are independent.
ArgoCD watches each app repo directly — this repo only registers them as a
one-time pointer.

```
devops-platform-foundation/          finops-intelligence-engine/
├── Terraform → AKS + ACR           ├── Python app code
├── ArgoCD → installed + configured  ├── Dockerfile
├── Observability → Prom+Graf+Loki   ├── k8s/ ← ArgoCD watches this
├── apps/                            └── CI/CD ← fully autonomous
│   ├── sample-app-1/ (HPA demo)
│   └── sample-app-2/ (canary demo)
└── gitops/argocd-apps/
    ├── sample-app-1.yaml  ← watches this repo
    ├── sample-app-2.yaml  ← watches this repo
    └── finops-engine.yaml ← watches finops repo (one-time pointer)
```

---

## Repository structure

```
devops-platform-foundation/
├── .github/
│   └── workflows/
│       ├── platform-infra.yml     Terraform + ArgoCD + Observability
│       └── platform-apps.yml      Sample app deployments only
│
├── terraform/
│   └── environments/dev/
│       ├── main.tf                AKS, ACR, Log Analytics, role assignments
│       ├── variables.tf           All configurable inputs
│       └── outputs.tf             Cluster name, ACR endpoint
│
├── apps/
│   ├── sample-app-1/
│   │   ├── manifests.yaml         Nginx + HPA (scales 2→6 on CPU > 50%)
│   │   └── load-test.sh           Triggers autoscaling for demo
│   └── sample-app-2/
│       └── manifests.yaml         Canary: 4 stable + 1 canary = 80/20 traffic
│
├── gitops/
│   └── argocd-apps/
│       ├── sample-app-1.yaml      ArgoCD Application CRD
│       ├── sample-app-2.yaml      ArgoCD Application CRD
│       └── finops-engine.yaml     Pointer to finops repo (one-time registration)
│
├── observability/
│   ├── prometheus/values.yaml     kube-prometheus-stack Helm values
│   └── loki/values.yaml           Loki-stack Helm values
│
└── docs/
    └── adr/
        ├── ADR-001-gitops-tool-choice.md
        ├── ADR-002-prometheus-over-azure-monitor.md
        ├── ADR-003-helm-over-raw-manifests.md
        └── ADR-004-separate-repos-per-app.md
```

---

## Prerequisites

### Mac — install all tools

```bash
brew install azure-cli terraform kubectl helm git argocd
brew install --cask visual-studio-code
```

### Verify

```bash
az --version && terraform --version && kubectl version --client && helm version
```

### Azure free account

Go to [portal.azure.com](https://portal.azure.com) → Start free.
You get $200 credit for 30 days + 12 months of free services.
Note your **Subscription ID** from the portal — you'll need it below.

---

## Option A — Run locally (manual setup)

Use this when you want to understand each step or demo without GitHub Actions.

### Step 1 — Clone

```bash
git clone https://github.com/vmprachi7/devops-platform-foundation.git
cd devops-platform-foundation
```

### Step 2 — Azure login

```bash
az login
az account show   # confirm correct subscription
```

### Step 3 — Create Service Principal

```bash
# Create SP with Contributor role
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"

# Output — save immediately, password shown once:
# {
#   "appId":    "..."   → ARM_CLIENT_ID
#   "password": "..."   → ARM_CLIENT_SECRET  ← save now
#   "tenant":   "..."   → ARM_TENANT_ID
# }

# Add User Access Administrator (needed for AKS→ACR role assignment)
az role assignment create \
  --assignee "YOUR_SP_APP_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

### Step 4 — Set environment variables

```bash
export ARM_CLIENT_ID="your-appId"
export ARM_CLIENT_SECRET="your-password"
export ARM_TENANT_ID="your-tenant"
export ARM_SUBSCRIPTION_ID="your-subscription-id"

# Make permanent across terminal sessions
echo 'export ARM_CLIENT_ID="your-appId"'         >> ~/.zshrc
echo 'export ARM_CLIENT_SECRET="your-password"'  >> ~/.zshrc
echo 'export ARM_TENANT_ID="your-tenant"'        >> ~/.zshrc
echo 'export ARM_SUBSCRIPTION_ID="your-sub-id"'  >> ~/.zshrc
source ~/.zshrc
```

### Step 5 — Provision infrastructure

```bash
cd terraform/environments/dev

terraform init
terraform validate
terraform plan        # review what will be created
terraform apply -auto-approve
# Takes 5–8 minutes
```

**Resources created:**
| Resource | Name |
|---|---|
| Resource Group | `devops-platform-rg` |
| AKS Cluster | `devops-platform-aks` (1 node, Standard_B2s) |
| Container Registry | `devopsplatformacr` |
| Log Analytics | `devops-platform-aks-logs` |

### Step 6 — Configure kubectl

```bash
az aks get-credentials \
  --resource-group devops-platform-rg \
  --name devops-platform-aks

kubectl get nodes
# Expected: STATUS = Ready
```

### Step 7 — Install metrics-server (required for HPA)

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl wait --for=condition=ready pod \
  -l k8s-app=metrics-server \
  -n kube-system --timeout=60s
```

### Step 8 — Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=180s

# Get admin password
argocd admin initial-password -n argocd
```

Access the UI:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Username: admin   Password: from above
```

### Step 9 — Register repos + deploy apps

```bash
# Login via CLI
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$PASS" --insecure

# Register this repo
argocd repo add https://github.com/vmprachi7/devops-platform-foundation \
  --username vmprachi7 \
  --password YOUR_GITHUB_PAT

# Apply all ArgoCD Application CRDs (deploys sample-app-1 and sample-app-2)
kubectl apply -f gitops/argocd-apps/sample-app-1.yaml
kubectl apply -f gitops/argocd-apps/sample-app-2.yaml

# Watch ArgoCD sync
argocd app list
```

### Step 10 — Install observability stack

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

# Prometheus + Grafana
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values observability/prometheus/values.yaml \
  --wait --timeout 5m

# Loki
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values observability/loki/values.yaml \
  --wait --timeout 3m
```

### Step 11 — Verify full stack

```bash
kubectl get nodes                         # 1 node Ready
kubectl get pods -n argocd                # all Running
kubectl get pods -n monitoring            # prometheus, grafana, loki Running
kubectl get pods -n sample-app-1          # 2 pods Running
kubectl get pods -n sample-app-2          # 5 pods Running (4 stable + 1 canary)
argocd app list                           # both apps Synced + Healthy
```

### Access dashboards

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080

# Grafana
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000   admin / admin123

# Sample App 1
kubectl port-forward svc/sample-app-1 -n sample-app-1 8081:80
# http://localhost:8081

# Sample App 2
kubectl port-forward svc/sample-app-2 -n sample-app-2 8082:80
# http://localhost:8082  (refresh several times to hit canary)
```

---

## Option B — Run via GitOps (GitHub Actions)

Use this to demonstrate full CI/CD automation.

### Step 1 — Add GitHub Secrets

Go to: **repo → Settings → Secrets and variables → Actions → New secret**

| Secret | How to get it |
|---|---|
| `ARM_CLIENT_ID` | `az ad sp show --display-name terraform-sp --query appId -o tsv` |
| `ARM_CLIENT_SECRET` | saved when SP was created |
| `ARM_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `ARM_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |
| `AZURE_CREDENTIALS` | see below |

```bash
# Generate AZURE_CREDENTIALS (copy entire JSON output)
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/$(az account show --query id -o tsv)" \
  --sdk-auth
```

### Step 2 — Create production environment

Go to: **repo → Settings → Environments → New environment**
- Name: `production`
- Enable: Required reviewers → add yourself
- This adds a manual approval gate before Terraform applies

### Step 3 — Trigger platform infrastructure pipeline

Go to: **Actions → Platform Infrastructure → Run workflow**

Select action: `apply`

This single workflow run:
1. Runs `terraform apply` → provisions AKS + ACR + Log Analytics
2. Installs ArgoCD + registers repos
3. Installs metrics-server
4. Installs Prometheus + Grafana + Loki
5. Applies ArgoCD Application CRDs → both sample apps deploy automatically

### Step 4 — Trigger app pipeline (optional — apps deploy via ArgoCD automatically)

Go to: **Actions → Platform Sample Apps → Run workflow**

Select app: `all` or `sample-app-1` or `sample-app-2`

### Step 5 — Watch GitOps in action

```bash
# Get credentials locally
az aks get-credentials \
  --resource-group devops-platform-rg \
  --name devops-platform-aks

# Port-forward ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 → watch both apps synced and healthy.

Make a change to `apps/sample-app-1/manifests.yaml` → push → ArgoCD auto-syncs within 3 minutes. No `kubectl apply` needed.

---

## Demo: HPA autoscaling (sample-app-1)

```bash
# Terminal 1 — watch pods scale
kubectl get pods -n sample-app-1 -w

# Terminal 2 — watch HPA
kubectl get hpa -n sample-app-1 -w

# Terminal 3 — run load test
bash apps/sample-app-1/load-test.sh
```

**What happens:**
1. Load test sends 50 concurrent requests
2. CPU climbs above 50%
3. HPA detects breach → adds pods (up to 6)
4. Load stops → HPA removes pods after 60s stabilisation window

---

## Demo: Canary deployment (sample-app-2)

```bash
kubectl port-forward svc/sample-app-2 -n sample-app-2 8082:80
# Open http://localhost:8082 and refresh 5 times
# ~1 in 5 requests hits the canary (orange page)
```

**To increase canary traffic:**
```bash
# Edit apps/sample-app-2/manifests.yaml
# Change canary replicas: 1 → 2  (now 67/33 split)
git commit -m "canary: increase to 2 replicas (33% traffic)"
git push
# ArgoCD syncs automatically — no manual kubectl needed
```

**To promote canary to stable:**
```bash
# Set stable replicas: 4 → 0, canary replicas: 2 → 4
# Update version labels: stable track → v2.0
git commit -m "release: promote v2.0 canary to stable"
git push
```

**To rollback:**
```bash
# Set canary replicas: 0
git commit -m "rollback: remove canary"
git push
```

---

## Azure roles required

| Role | Scope | Why |
|---|---|---|
| `Contributor` | Subscription | Create all Azure resources |
| `User Access Administrator` | Subscription | Assign AcrPull from AKS to ACR |

---

## Teardown — save Azure credits

```bash
cd terraform/environments/dev
terraform destroy -auto-approve
```

Or via GitHub Actions: **Actions → Platform Infrastructure → Run workflow → destroy**

Recreate the full stack in ~10 minutes using Option A or Option B above.

---

## Architecture Decision Records

| ADR | Decision |
|---|---|
| [ADR-001](docs/adr/ADR-001-gitops-tool-choice.md) | ArgoCD over Flux |
| [ADR-002](docs/adr/ADR-002-prometheus-over-azure-monitor.md) | Prometheus over Azure Monitor native |
| [ADR-003](docs/adr/ADR-003-helm-over-raw-manifests.md) | Helm for cluster deployments |
| [ADR-004](docs/adr/ADR-004-separate-repos-per-app.md) | Separate repos per application |

---

## Projects built on this platform

| Repo | What it does | Status |
|---|---|---|
| [devops-platform-foundation](https://github.com/vmprachi7/devops-platform-foundation) | Platform base | ✅ This repo |
| finops-intelligence-engine | Azure cost anomaly detection + AI | 🚧 In progress |
| agentic-aiops | Autonomous observability + runbook AI | 🔜 Planned |
| idp-platform | AI-native internal developer platform | 🔜 Planned |

---

## Interview talking points

**On GitOps:**
> "No one on this platform runs kubectl apply manually. Every change goes
> through a Git commit — ArgoCD detects the drift and reconciles the cluster.
> selfHeal means if someone manually changes something in the cluster, ArgoCD
> reverts it within 3 minutes. Git is the single source of truth."

**On the canary setup:**
> "I implemented canary without a service mesh — pure replica-ratio traffic
> splitting. One Service selects both stable and canary pods via a shared label.
> With 4 stable and 1 canary pod, Kubernetes distributes 80/20 naturally.
> To promote: change replica counts in Git and push. ArgoCD does the rest."

**On HPA:**
> "Resource requests are set deliberately — 50m CPU per pod. HPA watches actual
> vs requested and scales when utilisation exceeds 50%. The scale-down
> stabilisation window is 60 seconds to prevent thrashing. PodDisruptionBudget
> ensures at least 1 pod stays available during any scale event."

**On cost:**
> "Standard_B2s costs roughly $0.04/hour. I destroy the cluster with
> terraform destroy when not working and recreate in 8 minutes. This mirrors
> how I approached cost optimisation at Capgemini — treat cloud spend like
> code, measure and control it."

---

*Built by Prachi · Senior DevOps & Platform Engineer*
*[LinkedIn](https://linkedin.com/in/prachi) · [GitHub](https://github.com/vmprachi7)*