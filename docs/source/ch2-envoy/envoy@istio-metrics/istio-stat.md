# Istio metrics

## Istio’s own Metrics

### Standard indicator description

> Reference: https://istio.io/latest/docs/reference/config/metrics/

#### Metrics

For HTTP, HTTP/2, and GRPC traffic, Istio generates the following metrics by default:

- **Request Count** (`istio_requests_total`): This is a `COUNTER` incremented for every request handled by an Istio proxy.
- **Request Duration** (`istio_request_duration_milliseconds`): This is a `DISTRIBUTION` which measures the duration of requests.
- **Request Size** (`istio_request_bytes`): This is a `DISTRIBUTION` which measures HTTP request body sizes.
- **Response Size** (`istio_response_bytes`): This is a `DISTRIBUTION` which measures HTTP response body sizes.
- **gRPC Request Message Count** (`istio_request_messages_total`): This is a `COUNTER` incremented for every gRPC message sent from a client.
- **gRPC Response Message Count** (`istio_response_messages_total`): This is a `COUNTER` incremented for every gRPC message sent from a server.

For TCP traffic, Istio generates the following metrics:

- **Tcp Bytes Sent** (`istio_tcp_sent_bytes_total`): This is a `COUNTER` which measures the size of total bytes sent during response in case of a TCP connection.
- **Tcp Bytes Received** (`istio_tcp_received_bytes_total`): This is a `COUNTER` which measures the size of total bytes received during request in case of a TCP connection.
- **Tcp Connections Opened** (`istio_tcp_connections_opened_total`): This is a `COUNTER` incremented for every opened connection.
- **Tcp Connections Closed** (`istio_tcp_connections_closed_total`): This is a `COUNTER` incremented for every closed connection.

#### Labels of Prometheus

- **Reporter**: This identifies the reporter of the request. It is set to `destination` if report is from a server Istio proxy and `source` if report is from a client Istio proxy or a gateway.

- **Source Workload**: This identifies the name of source workload which controls the source, or “unknown” if the source information is missing.

- **Source Workload Namespace**: This identifies the namespace of the source workload, or “unknown” if the source information is missing.

- **Source Principal**: This identifies the peer principal of the traffic source. It is set when peer authentication is used.

- **Source App**: This identifies the source application based on `app` label of the source workload, or “unknown” if the source information is missing.

- **Source Version**: This identifies the version of the source workload, or “unknown” if the source information is missing.

- **Destination Workload**: This identifies the name of destination workload, or “unknown” if the destination information is missing.

- **Destination Workload Namespace**: This identifies the namespace of the destination workload, or “unknown” if the destination information is missing.

- **Destination Principal**: This identifies the peer principal of the traffic destination. It is set when peer authentication is used.

- **Destination App**: This identifies the destination application based on `app` label of the destination workload, or “unknown” if the destination information is missing.

- **Destination Version**: This identifies the version of the destination workload, or “unknown” if the destination information is missing.

- **Destination Service**: This identifies destination service host responsible for an incoming request. Ex: `details.default.svc.cluster.local`.

- **Destination Service Name**: This identifies the destination service name. Ex: “details”.

- **Destination Service Namespace**: This identifies the namespace of destination service.

- **Request Protocol**: This identifies the protocol of the request. It is set to request or connection protocol.

- **Response Code**: This identifies the response code of the request. This label is present only on HTTP metrics.

- **Connection Security Policy**: This identifies the service authentication policy of the request. It is set to `mutual_tls` when Istio is used to make communication secure and report is from destination. It is set to `unknown` when report is from source since security policy cannot be properly populated.

- **Response Flags**: Additional details about the response or connection from proxy. In case of Envoy, see `%RESPONSE_FLAGS%` in [Envoy Access Log](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#config-access-log-format-response-flags) for more detail.

For example, if you want to count the number of failed requests related to upstream circuit breaker:
```
sum(istio_requests_total{response_code="503", response_flags="UO"}) by (source_workload, destination_workload, response_code)
```

- **Canonical Service**: A workload belongs to exactly one canonical service, whereas it can belong to multiple services. A canonical service has a name and a revision so it results in the following labels.

  ```yaml
  source_canonical_service
  source_canonical_revision
  destination_canonical_service
  destination_canonical_revision
  ```

  

- **Destination Cluster**: This identifies the cluster of the destination workload. This is set by: `global.multiCluster.clusterName` at cluster install time.

- **Source Cluster**: This identifies the cluster of the source workload. This is set by: `global.multiCluster.clusterName` at cluster install time.

- **gRPC Response Status**: This identifies the response status of the gRPC. This label is present only on gRPC metrics.

### Usage

#### istio-proxy integrates output with application Metrics

:::{figure-md} Figure: Integrated output of istio-proxy and application Metrics
:class: full-width

<img src="/ch1-istio-arch/istio-ports-components.assets/istio-ports-components.drawio.svg" alt="Figure - Integrated output of istio-proxy and application Metrics">

*Figure: Integrated output of istio-proxy and application Metrics*  
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fistio-ports-components.drawio.svg)*


> Ref: https://istio.io/v1.14/docs/ops/integrations/prometheus/#option-1-metrics-merging


Istio is able to control scraping entirely through `prometheus.io` annotations. While `prometheus.io` annotations are not a core part of Prometheus, they have become the de facto standard for configuring scraping.

This option is enabled by default, but can be disabled by passing `-set meshConfig.enablePrometheusMerge=false` during [install](https://istio.io/v1.14/docs/setup/install/istioctl/). When enabled, appropriate `prometheus.io` annotations will be added to all dataplane pods to set up the scraping. If these annotations already exist, they will be overridden. With this option, the Envoy sidecar will merge Istio metrics with application metrics. The merged metrics will be grabbed from `/stats/prometheus:15020`.

This option exposes all metrics in plaintext.


#### Customization: Adding dimensions to Metrics

> Reference: https://istio.io/latest/docs/tasks/observability/metrics/customize-metrics/#custom-statistics-configuration

e.g. add port, and HTTP HOST header dimensions.

1.

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    telemetry:
      v2:
        prometheus:
          configOverride:
            inboundSidecar:
              metrics:
                - name: requests_total
                  dimensions:
                    destination_port: string(destination.port)
                    request_host: request.host
            outboundSidecar:
              metrics:
                - name: requests_total
                  dimensions:
                    destination_port: string(destination.port)
                    request_host: request.host
            gateway:
              metrics:
                - name: requests_total
                  dimensions:
                    destination_port: string(destination.port)
                    request_host: request.host

```

2. Use the following command to apply the following annotation to all injected pods containing the list of dimensions to be extracted into the Prometheus [Time Series](https://en.wikipedia.org/wiki/Time_series):

This step is only required if your dimension is not in the [DefaultStatTags list](https://github.com/istio/istio/blob/release-1.14/pkg/bootstrap/config.go)

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template: # pod template
    metadata:
      annotations:
        sidecar.istio.io/extraStatTags: destination_port,request_host
```

To enable additional `Tags` in the mesh scope, you can add `extraStatTags` to the mesh configuration:

```yaml
meshConfig:
  defaultConfig:
    extraStatTags:
     - destination_port
     - request_host
```

> Ref: https://istio.io/latest/docs/reference/config/proxy_extensions/stats/#MetricConfig

#### Customization: adding dimension of request/response metrics

It is possible to add some basic information from the request or response to the metrics dimension. For example, URL Path, which is useful when you need to segregate metrics for different REST APIs for the same service.

> Reference: https://istio.io/latest/docs/tasks/observability/metrics/classify-metrics/


### How it works

#### istio stat filter usage

Istio has added the stats-filter plugin to its own customized version of Envoy to calculate the metrics Istio wants:

```yaml
$ k -n istio-system get envoyfilters.networking.istio.io stats-filter-1.14 -o yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  annotations:
  labels:
    install.operator.istio.io/owning-resource-namespace: istio-system
    istio.io/rev: default
    operator.istio.io/component: Pilot
    operator.istio.io/version: 1.14.3
  name: stats-filter-1.14
  namespace: istio-system
spec:
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_OUTBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
      proxy:
        proxyVersion: ^1\.14.*
    patch:
      operation: INSERT_BEFORE
      value:
        name: istio.stats
        typed_config:
          '@type': type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
          value:
            config:
              configuration:
                '@type': type.googleapis.com/google.protobuf.StringValue
                value: |
                  {
                    "debug": "false",
                    "stat_prefix": "istio"
                  }
              root_id: stats_outbound
              vm_config:
                code:
                  local:
                    inline_string: envoy.wasm.stats
                runtime: envoy.wasm.runtime.null
                vm_id: stats_outbound
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
      proxy:
        proxyVersion: ^1\.14.*
    patch:
      operation: INSERT_BEFORE
      value:
        name: istio.stats
        typed_config:
          '@type': type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
          value:
            config:
              configuration:
                '@type': type.googleapis.com/google.protobuf.StringValue
                value: |
                  {
                    "debug": "false",
                    "stat_prefix": "istio",
                    "disable_host_header_fallback": true,
                    "metrics": [
                      {
                        "dimensions": {
                          "destination_cluster": "node.metadata['CLUSTER_ID']",
                          "source_cluster": "downstream_peer.cluster_id"
                        }
                      }
                    ]
                  }
              root_id: stats_inbound
              vm_config:
                code:
                  local:
                    inline_string: envoy.wasm.stats
                runtime: envoy.wasm.runtime.null
                vm_id: stats_inbound
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
      proxy:
        proxyVersion: ^1\.14.*
    patch:
      operation: INSERT_BEFORE
      value:
        name: istio.stats
        typed_config:
          '@type': type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
          value:
            config:
              configuration:
                '@type': type.googleapis.com/google.protobuf.StringValue
                value: |
                  {
                    "debug": "false",
                    "stat_prefix": "istio",
                    "disable_host_header_fallback": true
                  }
              root_id: stats_outbound
              vm_config:
                code:
                  local:
                    inline_string: envoy.wasm.stats
                runtime: envoy.wasm.runtime.null
                vm_id: stats_outbound
  priority: -1
```


#### istio stat Plugin Implementation

https://github.com/istio/proxy/blob/release-1.14/extensions/stats/plugin.cc

Internal Metric:

```c++
const std::vector<MetricFactory>& PluginRootContext::defaultMetrics() {
  static const std::vector<MetricFactory> default_metrics = {
      // HTTP, HTTP/2, and GRPC metrics
      MetricFactory{"requests_total", MetricType::Counter,
                    [](::Wasm::Common::RequestInfo&) -> uint64_t { return 1; },
                    static_cast<uint32_t>(Protocol::HTTP) |
                        static_cast<uint32_t>(Protocol::GRPC),
                    count_standard_labels, /* recurrent */ false},
      MetricFactory{"request_duration_milliseconds", MetricType::Histogram,
                    [](::Wasm::Common::RequestInfo& request_info) -> uint64_t {
                      return request_info.duration /* in nanoseconds */ /
                             1000000;
                    },
                    static_cast<uint32_t>(Protocol::HTTP) |
                        static_cast<uint32_t>(Protocol::GRPC),
                    count_standard_labels, /* recurrent */ false},
      MetricFactory{"request_bytes", MetricType::Histogram,
                    [](::Wasm::Common::RequestInfo& request_info) -> uint64_t {
                      return request_info.request_size;
                    },
                    static_cast<uint32_t>(Protocol::HTTP) |
                        static_cast<uint32_t>(Protocol::GRPC),
                    count_standard_labels, /* recurrent */ false},
      MetricFactory{"response_bytes", MetricType::Histogram,
                    [](::Wasm::Common::RequestInfo& request_info) -> uint64_t {
                      return request_info.response_size;
                    },
                    static_cast<uint32_t>(Protocol::HTTP) |
                        static_cast<uint32_t>(Protocol::GRPC),
                    count_standard_labels, /* recurrent */ false},
...
```


https://github.com/istio/proxy/blob/release-1.14/extensions/stats/plugin.cc#L591

```c++
void PluginRootContext::report(::Wasm::Common::RequestInfo& request_info,
                               bool end_stream) {

...
  map(istio_dimensions_, outbound_, peer_node_info.get(), request_info);

  for (size_t i = 0; i < expressions_.size(); i++) {
    if (!evaluateExpression(expressions_[i].token,
                            &istio_dimensions_.at(count_standard_labels + i))) {
      LOG_TRACE(absl::StrCat("Failed to evaluate expression: <",
                             expressions_[i].expression, ">"));
      istio_dimensions_[count_standard_labels + i] = "unknown";
    }
  }

  auto stats_it = metrics_.find(istio_dimensions_);
  if (stats_it != metrics_.end()) {
    for (auto& stat : stats_it->second) {
      if (end_stream || stat.recurrent_) {
        stat.record(request_info);
      }
      LOG_DEBUG(
          absl::StrCat("metricKey cache hit ", ", stat=", stat.metric_id_));
    }
    cache_hits_accumulator_++;
    if (cache_hits_accumulator_ == 100) {
      incrementMetric(cache_hits_, cache_hits_accumulator_);
      cache_hits_accumulator_ = 0;
    }
    return;
  }
...
}                                  
```


> This is a good reference article on the principles of Istio's metrics: https://blog.christianposta.com/understanding-istio-telemetry-v2/


## Envoy Internal Metrics

Istio uses istio-agent to integrate Envoy metrics by default.
Istio opens few built-in Envoy metrics by default:

> See: https://istio.io/latest/docs/ops/configuration/telemetry/envoy-stats/

```
cluster_manager
listener_manager
server
cluster.xds-grpc
```

### Customizing Envoy's built-in Metrics

> Reference: https://istio.io/latest/docs/ops/configuration/telemetry/envoy-stats/

To configure Istio Proxy to log other Envoy-native metrics, you can add [`ProxyConfig.ProxyStatsMatcher`](https://istio.io/latest/docs/reference/config/istio.mesh.v1alpha1/#ProxyStatsMatcher) to the grid configuration. For example, to globally enable statistics for circuit breakers, retries, and upstream connections, you can specify stats matcher as follows:

The proxy needs to be restarted to get the stats matcher configuration.

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
          - ".*circuit_breakers.*"
        inclusionPrefixes:
          - "upstream_rq_retry"
          - "upstream_cx"
```

You can also use the `proxy.istio.io/config` annotation to specify configurations for individual pieces of code. For example, to configure the same statistics as above, you can add the annotation to the gateway proxy or workload as shown below:

```yaml
metadata:
  annotations:
    proxy.istio.io/config: |-
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*circuit_breakers.*"
        inclusionPrefixes:
        - "upstream_rq_retry"
        - "upstream_cx"
```


### Principle

Below, see how the Envoy is configured in the Istio default configuration.

```bash
istioctl proxy-config bootstrap fortio-server | yq eval -P  > envoy-config-bootstrap-default.yaml
```
Output:

```yaml
bootstrap:
...
  statsConfig.
    statsTags: # Grab Tag(prometheus label) from metrics name
      - tagName: cluster_name
        regex: ^cluster\. ((. +? (\...+? +? \.svc\.cluster\.local)?) \...)
      - tagName: tcp_prefix
        regex: ^tcp\. ((. *?) \...) \w+? \w+?
      - tagName: response_code
        regex: (response_code=\. =(. +?) ;\. ;)|_rq(_(\.d{3}))$
      - tagName: response_code_class
        regex: _rq(_(\dxx))$
      - tagName: http_conn_manager_listener_prefix
        regex: ^listener(? =\.) . *? \.http\. ((((? :[_. [:digit:]]*|[_\[\]aAbBcCdDeEfF[:digit:]]*))\.)
...
    useAllDefaultTags: false
    statsMatcher.
      inclusionList.
        patterns: # Select the metrics to record
          - prefix: reporter=
          - prefix: cluster_manager
          - prefix: listener_manager
          - prefix: server
          - prefix: cluster.xds-grpc ## Log only xDS clusters. i.e. do not log clusters that the user serves themselves !!!!
          - prefix: wasm
          - suffix: rbac.allowed
          - suffix: rbac.denied
          - suffix: shadow_allowed
          - suffix: shadow_denied
          - prefix: component
```

At this point, if you modify the definition of the pod to:

```yaml
    annotations.
      proxy.istio.io/config: |-
        proxyStatsMatcher: |- proxy.istio.io/config: |-
          | proxyStatsMatcher: | inclusionRegexps.
          - "cluster\... *fortio.*" #proxy upstream(outbound)
          - "cluster\... *inbound.*" #proxy upstream(inbound, which generally means applications running in the same pod)
          - "http\... *"
          - "listener\... *"
```

Generate a new Envoy configuration:

```json
 "stats_matcher": {
   "inclusion_list": {
     "patterns": [
       {
         "prefix": "reporter="
       },
       {
         "prefix": "cluster_manager"
       },
       {
         "prefix": "listener_manager"
       },
       {
         "prefix": "server"
       },
       {
         "prefix": "cluster.xds-grpc"
       },
 

       {
         "safe_regex": {
           "google_re2": {},
           "regex": "cluster\\..*fortio.*"
         }
       },
       {
         "safe_regex": {
           "google_re2": {},
           "regex": "cluster\\..*inbound.*"
         }
       },
       {
         "safe_regex": {
           "google_re2": {},
           "regex": "http\\..*"
         }
       },
       {
         "safe_regex": {
           "google_re2": {},
           "regex": "listener\\..*"
         }
       },
```

## Summary: Istio-Proxy Metrics Map

To do a good job of monitoring, you first need to have a deep understanding of the metrics principle. And to understand the principle of metrics, of course, you need to know where and what components are in the process of generating metrics. After reading the above description of Envoy and Istio's metrics. You can probably get the following conclusions:

:::{figure-md} Figure: Map of istio-proxy metrics
:class: full-width

<img src="/ch2-envoy/envoy@istio-metrics/index.assets/envoy@istio-metrics.drawio.svg" alt="Figure - Map of istio-proxy metrics">

*Figure: Map of istio-proxy metrics*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy@istio-metrics.drawio.svg)*

```{note}
A description of the experimental environment for this section can be found in: {ref}`appendix-lab-env/appendix-lab-env-base:Simple layered lab environment`
```