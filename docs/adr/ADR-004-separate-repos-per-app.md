# ADR-004: Separate repos per application vs monorepo

## Status
Accepted

## Context
Needed to decide how to structure repositories across the platform:
- Option A: All app manifests live in devops-platform-foundation (monorepo)
- Option B: Each app has its own repo, platform repo owns only platform
- Option C: Hybrid — platform owns platform + sample apps, product apps own themselves

## Decision
Adopted Option C (hybrid):
- `devops-platform-foundation` owns: Terraform, ArgoCD, Observability, sample apps
- `finops-intelligence-engine` owns: app code, Dockerfile, k8s manifests
- `agentic-aiops` (future) owns: app code, Dockerfile, k8s manifests
- ArgoCD watches each repo independently

## Reasoning

**Platform concerns are different from app concerns.**
Infrastructure changes (Terraform, Helm values) need a different review
process, different CODEOWNERS, and different deployment cadence than
application code changes. Mixing them creates noise and slows both down.

**App teams own their deployment manifests.**
The team that owns the finops-engine Python code should own the k8s
manifests that define how it runs. Separating them into the platform
repo creates an unnecessary dependency — a Python change requires a PR
in a different repo to update the image tag.

**ArgoCD handles multi-repo natively.**
ArgoCD Application CRDs can point at any repo. The platform repo's
`gitops/argocd-apps/finops-engine.yaml` registers the finops repo
as a source — ArgoCD watches both repos independently.

**Sample apps stay in the platform repo deliberately.**
`sample-app-1` (HPA) and `sample-app-2` (canary) exist purely to
demonstrate platform capabilities, not as real applications. They have
no separate code repo — their manifests ARE the app. Keeping them in
the platform repo makes sense.

## Trade-offs
- Slightly more complex ArgoCD repo registration (multiple repos vs one)
- Each app team needs write access to their own repo, read access to platform
- Secret management must be handled per-repo for GitHub Actions

## Consequences
- devops-platform-foundation GitHub Actions only deploy sample apps
- finops-intelligence-engine GitHub Actions build + push image, ArgoCD deploys
- Adding Project 3 (aiops-agent): create new repo, add one ArgoCD Application
  CRD to platform repo's gitops/argocd-apps/ — zero other platform changes
