#!/bin/bash
# Quick setup script for external-gateway-loadbalancer

set -e

echo "=========================================="
echo "External Gateway Load Balancer Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    echo "  Install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo -e "${GREEN}✓ kubectl${NC}"

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm not found${NC}"
    echo "  Install helm: https://helm.sh/docs/intro/install/"
    exit 1
fi
echo -e "${GREEN}✓ helm${NC}"

# Check kubernetes connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "  Ensure kubectl is configured: kubectl config use-context <context>"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes connection${NC}"
echo ""

# Gateway Controller selection
echo -e "${YELLOW}Select Gateway Controller:${NC}"
echo "1) Cilium (recommended)"
echo "2) Istio"
echo "3) NGINX Ingress Controller"
echo "4) Kong"
echo "5) Skip (already installed)"
read -p "Enter choice (1-5): " controller_choice

case $controller_choice in
    1)
        echo -e "${YELLOW}Installing Cilium...${NC}"
        helm repo add cilium https://helm.cilium.io
        helm repo update
        helm install cilium cilium/cilium \
          --set kubeProxyReplacement=true \
          --namespace kube-system
        echo -e "${GREEN}✓ Cilium installed${NC}"
        ;;
    2)
        echo -e "${YELLOW}Installing Istio...${NC}"
        if ! command -v istioctl &> /dev/null; then
            echo "istioctl not found. Please install from: https://istio.io/latest/docs/setup/getting-started/"
            exit 1
        fi
        istioctl install --set profile=demo -y
        echo -e "${GREEN}✓ Istio installed${NC}"
        ;;
    3)
        echo -e "${YELLOW}Installing NGINX Ingress Controller...${NC}"
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
        echo -e "${GREEN}✓ NGINX Ingress Controller installed${NC}"
        ;;
    4)
        echo -e "${YELLOW}Installing Kong...${NC}"
        helm repo add kong https://charts.konghq.com
        helm repo update
        helm install kong kong/kong --namespace kong --create-namespace
        echo -e "${GREEN}✓ Kong installed${NC}"
        ;;
    5)
        echo -e "${YELLOW}Skipping Gateway Controller installation${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac
echo ""

# Install Gateway API CRDs
echo -e "${YELLOW}Installing Gateway API CRDs...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
echo -e "${GREEN}✓ Gateway API CRDs installed${NC}"
echo ""

# Select example
echo -e "${YELLOW}Select example to deploy:${NC}"
echo "1) Simple HTTP"
echo "2) HTTPS with TLS"
echo "3) Multiple Services with Path Routing"
echo "4) Header-Based Routing"
echo "5) Weighted Load Balancing"
echo "6) Skip deployment"
read -p "Enter choice (1-6): " example_choice

NAMESPACE="default"
RELEASE_NAME="external-gateway"

case $example_choice in
    1)
        EXAMPLE_FILE="simple-http.yaml"
        ;;
    2)
        echo -e "${YELLOW}TLS example selected${NC}"
        echo "You will need to create a TLS secret first:"
        echo "  kubectl create secret tls gateway-cert --cert=path/to/tls.crt --key=path/to/tls.key"
        echo ""
        read -p "Continue? (y/n): " confirm
        if [[ $confirm != [yY] ]]; then
            echo "Skipping deployment"
            exit 0
        fi
        EXAMPLE_FILE="https-with-tls.yaml"
        ;;
    3)
        EXAMPLE_FILE="multi-service-path-routing.yaml"
        ;;
    4)
        EXAMPLE_FILE="header-based-routing.yaml"
        ;;
    5)
        EXAMPLE_FILE="weighted-load-balancing.yaml"
        ;;
    6)
        echo -e "${YELLOW}Skipping deployment${NC}"
        echo ""
        echo "To deploy manually, run:"
        echo "  helm install $RELEASE_NAME . \\"
        echo "    -f ./examples/<example>.yaml \\"
        echo "    --namespace $NAMESPACE \\"
        echo "    --create-namespace"
        echo ""
        echo "Documentation:"
        echo "  - Chart docs: ./values.yaml"
        echo "  - Examples: ./examples/README.md"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Deploy chart
echo -e "${YELLOW}Deploying Helm chart...${NC}"
EXAMPLE_PATH="./examples/$EXAMPLE_FILE"

if [ ! -f "$EXAMPLE_PATH" ]; then
    echo -e "${RED}Example file not found: $EXAMPLE_PATH${NC}"
    exit 1
fi

helm install $RELEASE_NAME . \
    -f "$EXAMPLE_PATH" \
    --namespace $NAMESPACE \
    --create-namespace

echo -e "${GREEN}✓ Helm chart deployed${NC}"
echo ""

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
echo ""

echo "Services:"
kubectl get services -n $NAMESPACE -l app.kubernetes.io/name=external-gateway-loadbalancer

echo ""
echo "Gateway:"
kubectl get gateway -n $NAMESPACE

echo ""
echo "HTTP Routes:"
kubectl get httproute -n $NAMESPACE

echo ""
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Port-forward the gateway:"
echo "   kubectl port-forward -n $NAMESPACE svc/ingress-istio 8080:80"
echo ""
echo "2. Test the route:"
echo "   curl -H 'Host: api.local' http://localhost:8080/"
echo ""
echo "3. View more examples:"
echo "   cat ./external-gateway-chart/examples/README.md"
echo ""
echo "4. Manage deployment:"
echo "   helm upgrade $RELEASE_NAME ./external-gateway-chart -f <values.yaml>"
echo "   helm uninstall $RELEASE_NAME --namespace $NAMESPACE"
echo ""
