#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# HPA Load Test — Sample App 1
# Run this to trigger CPU spike and watch HPA scale pods up
# ═══════════════════════════════════════════════════════════════
#
# USAGE:
#   bash apps/sample-app-1/load-test.sh
#
# WATCH IN PARALLEL (open 2 more terminals while this runs):
#   Terminal 2: kubectl get hpa -n sample-app-1 -w
#   Terminal 3: kubectl get pods -n sample-app-1 -w
#
# WHAT TO EXPECT:
#   - Load test starts → CPU climbs above 50%
#   - HPA detects breach → adds pods (up to 6)
#   - Load test stops → CPU drops → HPA removes pods after 60s
# ═══════════════════════════════════════════════════════════════

set -e

NAMESPACE="sample-app-1"
SERVICE="sample-app-1"
DURATION="${1:-120}"   # default 120 seconds, override with: bash load-test.sh 60
CONCURRENCY=50

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HPA Load Test — Sample App 1"
echo "  Duration:    ${DURATION}s"
echo "  Concurrency: ${CONCURRENCY} parallel requests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check kubectl is available
if ! command -v kubectl &>/dev/null; then
  echo "❌ kubectl not found. Install it first."
  exit 1
fi

# Check cluster is accessible
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Cannot connect to cluster. Run: az aks get-credentials ..."
  exit 1
fi

# Check namespace exists
if ! kubectl get namespace $NAMESPACE &>/dev/null; then
  echo "❌ Namespace $NAMESPACE not found. Deploy sample-app-1 first."
  exit 1
fi

# Check metrics-server is available (required for HPA)
echo "Checking metrics-server..."
if ! kubectl top nodes &>/dev/null 2>&1; then
  echo "⚠️  metrics-server not responding — installing..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  echo "Waiting 30s for metrics-server to start..."
  sleep 30
fi

echo "✅ Pre-checks passed"
echo ""
echo "Current HPA status:"
kubectl get hpa -n $NAMESPACE
echo ""
echo "Current pods:"
kubectl get pods -n $NAMESPACE
echo ""

# Port-forward the service
echo "Starting port-forward to $SERVICE..."
kubectl port-forward svc/$SERVICE -n $NAMESPACE 8888:80 &
PF_PID=$!
sleep 3

# Cleanup function
cleanup() {
  echo ""
  echo "Stopping load test..."
  kill $PF_PID 2>/dev/null || true
  kill $LOAD_PID 2>/dev/null || true
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Load test complete. Final state:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  kubectl get hpa -n $NAMESPACE
  echo ""
  kubectl get pods -n $NAMESPACE
  echo ""
  echo "Watch scale-down (60s stabilisation window):"
  echo "  kubectl get hpa -n $NAMESPACE -w"
}
trap cleanup EXIT

# Run load using curl in background loop
echo "🚀 Starting load: ${CONCURRENCY} concurrent requests for ${DURATION}s"
echo "   Watch HPA:  kubectl get hpa -n $NAMESPACE -w"
echo "   Watch pods: kubectl get pods -n $NAMESPACE -w"
echo ""

END_TIME=$((SECONDS + DURATION))

# Launch concurrent request loops
for i in $(seq 1 $CONCURRENCY); do
  while [ $SECONDS -lt $END_TIME ]; do
    curl -s http://localhost:8888 > /dev/null 2>&1 || true
  done &
done

LOAD_PID=$!

# Print progress
while [ $SECONDS -lt $END_TIME ]; do
  REMAINING=$((END_TIME - SECONDS))
  printf "\r⏱  Running... ${REMAINING}s remaining"
  sleep 5
  kubectl get hpa -n $NAMESPACE --no-headers 2>/dev/null | \
    awk '{printf " | Replicas: %s/%s | CPU: %s", $6, $5, $3}' || true
done

echo ""