# ADR-001: ArgoCD over Flux for GitOps

## Status: Accepted

## Context
Evaluated ArgoCD and Flux v2 as GitOps operators for AKS.

## Decision
Chose ArgoCD.

## Reasoning
- Built-in UI for visualising sync state — essential for demos and stakeholder visibility
- Stronger multi-cluster RBAC model for future expansion  
- UI becomes a portfolio demo asset, not just an ops tool
- Flux is lighter but lacks visual diff capability

## Trade-offs
- ~200MB extra memory vs Flux
- Slightly more complex initial setup