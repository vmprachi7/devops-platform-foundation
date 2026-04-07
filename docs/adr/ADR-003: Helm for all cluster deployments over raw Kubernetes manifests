ADR-003: Helm for all cluster deployments over raw Kubernetes manifests
Status
Accepted
Context
Kubernetes applications can be deployed via raw YAML manifests applied with kubectl apply, or via Helm charts which template and package the manifests.
Decision
Use Helm for all cluster-level deployments (ArgoCD, kube-prometheus-stack, Loki, application charts).
Reasoning
Parameterisation: Helm values files allow environment-specific configuration (dev vs prod resource limits, replica counts, passwords) without duplicating manifests. Raw manifests require either Kustomize overlays or manual file duplication.
Versioning: Helm chart versions are pinned and auditable. helm history shows every release with timestamps and values. Rolling back is a single command: helm rollback <release> <revision>.
Ecosystem: The majority of production-grade tooling (ArgoCD, Prometheus, Cert-Manager, Ingress-NGINX) ships as Helm charts. Using Helm aligns with how these tools are maintained and documented upstream.
GitOps compatibility: ArgoCD has first-class Helm support. Storing values.yaml files in Git and pointing ArgoCD at a Helm chart + values file is the idiomatic GitOps pattern for infrastructure components.
Trade-offs
* Helm adds a learning curve for developers unfamiliar with Go templating.
* Debugging failed Helm releases requires understanding both the chart template and the rendered output (helm template helps here).
* For very simple, stable deployments (a single ConfigMap, a Namespace), raw manifests are simpler and raw YAML is used in those cases.
Consequences
* All Helm values are stored in observability/ and gitops/ folders, version-controlled, and managed by ArgoCD.
* helm list -A provides a live inventory of everything deployed on the cluster.
