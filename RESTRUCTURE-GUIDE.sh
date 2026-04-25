#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# devops-platform-foundation — COMPLETE RESTRUCTURE GUIDE
# Run these commands from the root of your repo
# ═══════════════════════════════════════════════════════════════

# ── STEP 1: Create the new folder structure ─────────────────
mkdir -p apps/sample-app
mkdir -p apps/finops-engine
mkdir -p gitops/argocd-apps
mkdir -p observability/prometheus
mkdir -p observability/loki
mkdir -p observability/grafana

# ── STEP 2: Move existing sample-app manifests ─────────────
# Your current path: gitops/apps/sample-app/manifests.yaml
# New path:          apps/sample-app/manifests.yaml
mv gitops/apps/sample-app/manifests.yaml apps/sample-app/manifests.yaml
rm -rf gitops/apps/

# ── STEP 3: Create finops-engine app manifests ─────────────
# These are lightweight — just the K8s resources that live in the
# platform repo. The app code lives in finops-intelligence-engine repo.
cat > apps/finops-engine/manifests.yaml << 'YAML'
---
apiVersion: v1
kind: Namespace
metadata:
  name: finops-engine
  labels:
    app.kubernetes.io/managed-by: argocd
    project: devops-platform

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: finops-config
  namespace: finops-engine
data:
  USE_MOCK_DATA:          "true"
  LOOKBACK_DAYS:          "30"
  ANOMALY_THRESHOLD_PCT:  "30"
  DAILY_BUDGET_USD:       "10"
  MONTHLY_BUDGET_USD:     "100"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: finops-engine
  namespace: finops-engine
  labels:
    app: finops-engine
spec:
  replicas: 1
  selector:
    matchLabels:
      app: finops-engine
  template:
    metadata:
      labels:
        app: finops-engine
    spec:
      containers:
        - name: finops-engine
          image: devopsplatformacr.azurecr.io/finops-engine:latest
          ports:
            - containerPort: 8501
          envFrom:
            - configMapRef:
                name: finops-config
            - secretRef:
                name: finops-secrets
          resources:
            requests:
              cpu:    100m
              memory: 256Mi
            limits:
              cpu:    500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /_stcore/health
              port: 8501
            initialDelaySeconds: 30
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /_stcore/health
              port: 8501
            initialDelaySeconds: 15
            periodSeconds: 10

---
apiVersion: v1
kind: Service
metadata:
  name: finops-engine
  namespace: finops-engine
  labels:
    app: finops-engine
spec:
  selector:
    app: finops-engine
  ports:
    - port: 80
      targetPort: 8501
  type: ClusterIP
YAML

# ── STEP 4: Create ArgoCD Application CRDs ─────────────────
cat > gitops/argocd-apps/sample-app.yaml << 'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
  labels:
    project: devops-platform
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/devops-platform-foundation
    targetRevision: main
    path: apps/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: sample-app
  syncPolicy:
    automated:
      prune:    true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
YAML

cat > gitops/argocd-apps/finops-engine.yaml << 'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: finops-engine
  namespace: argocd
  labels:
    project: devops-platform
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/devops-platform-foundation
    targetRevision: main
    path: apps/finops-engine
  destination:
    server: https://kubernetes.default.svc
    namespace: finops-engine
  syncPolicy:
    automated:
      prune:    true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
YAML

# ── STEP 5: Observability Helm values ──────────────────────
cat > observability/prometheus/values.yaml << 'YAML'
grafana:
  adminPassword: "admin123"
  persistence:
    enabled: false
  sidecar:
    dashboards:
      enabled: true
prometheus:
  prometheusSpec:
    retention: 7d
    resources:
      requests:
        cpu:    200m
        memory: 400Mi
alertmanager:
  enabled: true
YAML

cat > observability/loki/values.yaml << 'YAML'
grafana:
  enabled: false
prometheus:
  enabled: false
loki:
  persistence:
    enabled: false
promtail:
  enabled: true
YAML

# ── STEP 6: Copy GitHub Actions workflows ──────────────────
# Move the old combined pipeline out, bring in the two new ones:
rm -f .github/workflows/platform-ci-cd.yml

# Copy platform-infra.yml and platform-apps.yml into .github/workflows/
# (download from chat and copy here)

# ── STEP 7: Update .github/workflows files ─────────────────
# Replace YOUR_USERNAME in all argocd-apps yamls:
sed -i '' 's/YOUR_USERNAME/your-actual-github-username/g' \
  gitops/argocd-apps/sample-app.yaml \
  gitops/argocd-apps/finops-engine.yaml

# ── STEP 8: Commit everything ───────────────────────────────
git add .
git commit -m "refactor: split pipelines into platform-infra + platform-apps, restructure apps/ folder"
git push

echo ""
echo "═══════════════════════════════════════════════════════"
echo " FINAL REPO STRUCTURE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "devops-platform-foundation/"
echo "├── .github/workflows/"
echo "│   ├── platform-infra.yml   ← Terraform + ArgoCD + Observability"
echo "│   └── platform-apps.yml    ← Detects changed app, deploys it"
echo "│"
echo "├── terraform/environments/dev/"
echo "│   ├── main.tf"
echo "│   ├── variables.tf"
echo "│   └── outputs.tf"
echo "│"
echo "├── apps/                    ← ONE FOLDER PER APP"
echo "│   ├── sample-app/"
echo "│   │   └── manifests.yaml   ← Deployment, Service, HPA, ConfigMap"
echo "│   └── finops-engine/"
echo "│       └── manifests.yaml   ← Deployment, Service, ConfigMap"
echo "│"
echo "├── gitops/argocd-apps/      ← ArgoCD Application CRDs"
echo "│   ├── sample-app.yaml      ← Points ArgoCD at apps/sample-app/"
echo "│   └── finops-engine.yaml   ← Points ArgoCD at apps/finops-engine/"
echo "│"
echo "├── observability/"
echo "│   ├── prometheus/values.yaml"
echo "│   └── loki/values.yaml"
echo "│"
echo "└── docs/adr/"
echo "    ├── ADR-001-gitops-tool-choice.md"
echo "    ├── ADR-002-prometheus-over-azure-monitor.md"
echo "    └── ADR-003-helm-over-raw-manifests.md"
echo ""
echo "═══════════════════════════════════════════════════════"
echo " HOW THE TWO PIPELINES WORK TOGETHER"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "platform-infra.yml triggers when:"
echo "  · terraform/** changes  → runs validate → plan (PR) → apply (merge)"
echo "  · observability/** changes → reinstalls Helm charts"
echo "  · Manual: Actions tab → Run workflow → choose apply/destroy/observability-only"
echo ""
echo "platform-apps.yml triggers when:"
echo "  · apps/sample-app/** changes  → deploys ONLY sample-app"
echo "  · apps/finops-engine/** changes → deploys ONLY finops-engine"
echo "  · Both change in one commit → deploys BOTH in parallel"
echo "  · Manual: Actions tab → Run workflow → type app name"
echo ""
echo "═══════════════════════════════════════════════════════"
echo " ADDING A NEW APP (Project 3, 4 etc)"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "1. mkdir apps/aiops-agent"
echo "2. Create apps/aiops-agent/manifests.yaml"
echo "3. Create gitops/argocd-apps/aiops-agent.yaml"
echo "4. git push"
echo "→ platform-apps.yml auto-detects the new app and deploys it"
echo "→ ArgoCD picks it up from gitops/argocd-apps/aiops-agent.yaml"
echo "→ Zero changes to either pipeline file needed"
