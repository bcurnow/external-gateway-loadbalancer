# Auto-Generation Architecture Update

## Summary

The chart has been updated to support **auto-generation of Gateway and HTTPRoutes** from `externalServices`, making it extremely simple to use while maintaining full customization capability.

## How It Works

### Auto-Generation Logic

**Gateway Template**:
- If `gateway` section with a `name` field is **provided**: Uses custom gateway
- If `gateway` section is **omitted**: Auto-generates default gateway based on externalServices
  - Analyzes all services to determine required protocols (HTTP, HTTPS)
  - Creates listeners for each protocol on standard ports (80 for HTTP, 443 for HTTPS)
  - For HTTPS, assumes TLS secret named `gateway-cert`
  - Uses Cilium as default gateway class

**HTTPRoutes Template**:
- If `routes` section is **provided as a non-empty list**: Uses custom routes
- If `routes` section is **omitted**: Auto-generates default routes based on externalServices
  - Creates one HTTPRoute per externalService
  - Auto-generates hostname: `{service-name}.local`
  - Handles multi-endpoint services with automatic load balancing (weighted refs)
  - Routes to the service's configured port

### Configuration Scenarios

#### 1. Minimal Configuration (Auto-Generated Gateway + Routes)
```yaml
externalServices:
  - name: "api"
    port: 80
    protocol: "HTTP"
    endpoints: ["api.example.com"]

# gateway and routes sections are omitted - they will be auto-generated!
```

Result: Gateway listening on HTTP:80 + auto-generated route with hostname `api.local`

#### 2. Custom Gateway + Auto-Generated Routes
```yaml
externalServices: [...]

gateway:
  name: "my-gateway"
  className: "cilium"
  listeners: [...]

# routes section is omitted - routes will be auto-generated for the custom gateway!
```

Result: Custom gateway + auto-generated routes for each service

#### 3. Auto-Generated Gateway + Custom Routes
```yaml
externalServices: [...]

# gateway section is omitted - gateway will be auto-generated!

routes:
  - name: "custom-route"
    gateway: "external-gateway"
    hostnames: [...]
    rules: [...]
```

Result: Auto-generated gateway + custom routing rules

#### 4. Full Customization (All Custom)
```yaml
externalServices: [...]

gateway:
  name: "my-gateway"
  # ... custom config ...

routes:
  - name: "route1"
    # ... custom config ...
```

Result: Fully custom gateway and routes

## Files Updated

### Templates
- `templates/gateway.yaml`: Added auto-generation logic with protocol detection
- `templates/httproutes.yaml`: Added auto-generation logic with hostname and load balancing support
- `templates/services.yaml`: Fixed template syntax (corrected {{- end }} block)

### Configuration
- `values.yaml`: Added documentation about auto-generation behavior

### Examples
- `examples/simple-http.yaml`: Simplified to minimal config with gateway/routes set to null
- `examples/auto-generated.yaml`: New example showing pure auto-generation scenario
- `examples/https-gateway-http-backends.yaml`: Rewritten to show custom gateway + auto-generated routes pattern
- `examples/https-with-tls.yaml`: Updated with comments explaining custom vs auto-generated

### Documentation
- `examples/README.md`: Updated introduction to explain auto-generation
- Added example 0 for auto-generated scenario

## Key Features

### Auto-Generated Gateway
- Protocol detection: Listens on HTTP and/or HTTPS based on service definitions
- TLS support: For HTTPS services, assumes certificate in `gateway-cert` secret
- Standard ports: 80 for HTTP, 443 for HTTPS
- Cilium default: Uses cilium gateway class by default

### Auto-Generated Routes
- One route per service
- Hostname format: `{service-name}.local`
- Multi-endpoint support: Automatic weighted backend references for load balancing
- Root path matching: All routes default to `PathPrefix: /`

## Use Case: HTTPS Gateway with HTTP Endpoints

The user's original request about "HTTPS gateway with HTTP endpoints" is now fully supported:

```yaml
externalServices:
  - name: "app"
    port: 80              # ← Backend uses HTTP
    protocol: "HTTP"
    endpoints: ["backend.example.com"]

gateway:
  name: "secure-gateway"
  listeners:
    - name: "https"
      protocol: "HTTPS"   # ← Gateway provides HTTPS
      port: 443
      tls:
        mode: "Terminate"
        certificateRefs:
          - name: "gateway-cert"

# routes section is omitted - routes auto-generated for HTTPS gateway → HTTP backend
```

This creates:
- HTTPS listener on port 443 with TLS termination
- HTTPRoute that forwards traffic to HTTP backend on port 80
- Gateway terminates TLS, routes to backend via HTTP

## Template Implementation Details

### Gateway Auto-Generation
```helm
{{- if and .Values.gateway .Values.gateway.name }}
  {{/* Custom gateway provided (has name field) */}}
{{- else if .Values.externalServices }}
  {{/* Auto-generate default gateway */}}
  {{/* Collect unique protocols from services */}}
  {{/* Create listeners for HTTP/HTTPS based on protocols found */}}
{{- end }}
```

Key: Checks for presence of `gateway.name` field, not just presence of gateway section

### HTTPRoute Auto-Generation
```helm
{{- if gt (len (.Values.routes | default list)) 0 }}
  {{/* Custom routes provided (non-empty list) */}}
{{- else if .Values.externalServices }}
  {{/* Auto-generate routes from services */}}
  {{/* Create one route per service */}}
  {{/* Auto-generate hostnames and backend refs */}}
{{- end }}
```

Key: Checks if routes is a non-empty list

## Testing

Templates have been validated with `helm template`:

```bash
# Test auto-generated scenario
helm template test . -f examples/auto-generated.yaml

# Test custom gateway + auto-generated routes
helm template test . -f examples/https-with-tls.yaml

# Test minimal scenario
helm template test . -f examples/simple-http.yaml
```

All scenarios produce valid Kubernetes manifests with auto-generated or custom resources as expected.

## Backward Compatibility

⚠️ **Breaking Change**: The `enabled` section has been completely removed. Auto-generation is now based on presence of configuration sections:

- **Gateway**: Auto-generated if the `gateway` section is omitted. If `gateway` is provided, it must have a `name` field to be used as custom.
- **Routes**: Auto-generated if the `routes` section is omitted. If `routes` is provided as a non-empty list, custom routes are used.

Existing deployments using the old `enabled` flags will need to be updated to omit the `gateway`/`routes` sections for auto-generation, or provide full custom definitions.

## Benefits

1. **Simplicity**: Just define services, no `gateway: null` needed
2. **Flexibility**: Override any part with custom configuration
3. **Intelligent Defaults**: Gateway protocol detection, standard port assignment
4. **Clear Intent**: Configuration shows exactly what gets created
5. **Advanced Patterns**: Easy to do HTTPS gateway with HTTP endpoints without duplication
6. **Minimal Boilerplate**: No explicit null assignments or enabled flags
