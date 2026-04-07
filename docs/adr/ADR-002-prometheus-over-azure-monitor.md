ADR-002: Prometheus over Azure Monitor native for metrics
Status
Accepted
Context
AKS natively integrates with Azure Monitor (Container Insights) for metrics and logs. We also evaluated the open-source kube-prometheus-stack as an alternative.
Decision
Use Prometheus + Grafana (kube-prometheus-stack) instead of Azure Monitor Container Insights as the primary metrics platform.
Reasoning
Vendor independence: Prometheus is the CNCF standard for Kubernetes metrics. Skills and dashboards are portable across AWS EKS, GKE, and on-prem clusters. Azure Monitor locks dashboards and query language (KQL) to Azure.
Cost: Azure Monitor Container Insights charges per GB of data ingested into Log Analytics. At scale this becomes significant. Prometheus running in-cluster has no per-GB cost — only the compute cost of the Prometheus pod itself.
Ecosystem: The kube-prometheus-stack includes pre-built Grafana dashboards for Kubernetes, node, and pod metrics out of the box. Achieving the same in Azure Monitor requires manual KQL dashboard construction.
Loki integration: Grafana natively integrates Prometheus metrics and Loki logs in a single UI with unified querying. Replicating this in Azure Monitor requires switching between Container Insights and Log Analytics workspaces.
Portfolio signal: Prometheus + Grafana is the standard observability stack in product companies. Demonstrating fluency with it signals readiness for product engineering environments, not just Azure-native consulting work.
Trade-offs
* Azure Monitor is zero-maintenance — no Prometheus pods to manage.
* Container Insights provides richer AKS-specific telemetry (node pool health, upgrade readiness) that Prometheus does not cover natively.
* For production at enterprise scale, a hybrid approach (Prometheus for application metrics, Azure Monitor for AKS control-plane telemetry) is ideal.
Consequences
* Prometheus and Grafana pods consume ~400MB memory on the cluster.
* Team must maintain Helm values and alert rules in Git (mitigated by storing all config in observability/ folder under GitOps control).
