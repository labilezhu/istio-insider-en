# http_protocol_options Accidentally disabled HTTP/2



## Symptom

In a word: we want to use HTTP/2 in an Istio environment running HTTP/1.1 .



We want to use HTTP/2 in below flow of APIs between services:

```
serviceA app -> serviceA istio-proxy -----> serviceB app -> serviceB istio-proxy
```



Environment:

```
service A: 
  Pod A: 
    ip addr: 192.168.88.94

service B: 10.110.152.25
  Pod B: serviceB-ver-6b54d8c7bc-6vclp
    ip addr: 192.168.33.5
```



So we try below curl on Pod A:

```bash
curl -iv http://serviceB:8080/resource1?p1=v1 \
 -H "Content-Type:application/json" --http2-prior-knowledge
 
*   Trying 10.110.152.25:8080...
* Connected to serviceB (10.110.152.25) port 8080 (#0)
* h2h3 [:method: GET]
* h2h3 [:path: /resource1?p1=v1]
* h2h3 [:scheme: http]
* h2h3 [:authority: serviceB:8080]
* h2h3 [user-agent: curl/8.0.1]
* h2h3 [accept: */*]
* h2h3 [content-type: application/json]
* Using Stream ID: 1 (easy handle 0x557514133e80)
> GET /resource1?p1=v1 HTTP/2
> Host: serviceB:8080
> user-agent: curl/8.0.1
> accept: */*
> content-type:application/json
> 
< HTTP/2 200 
HTTP/2 200 
< content-type: application/json
content-type: application/json
< date: Tue, 07 May 2024 08:44:33 GMT
date: Tue, 07 May 2024 08:44:33 GMT
< x-envoy-upstream-service-time: 19
x-envoy-upstream-service-time: 19
< server: envoy
server: envoy
```

It seems the app running on Pod A use HTTP/2. 



Let us check if Pod B use HTTP/2 :

```bash
kubectl logs --tail=1 -f serviceB-ver-6b54d8c7bc-6vclp -c istio-proxy
```



```log
[2024-05-07T07:18:41.470Z] "GET /resource1?p1=v1 HTTP/1.1" 200 - via_upstream - "-" 0 48 16 14 "-" "curl/8.0.1" "6add1007-7242-4983-9862-63cc5d10b8e5" "serviceB:8080" "[priv8]192.168.88.94[/priv8]:8080" outbound|8080|ver|serviceB.ns.svc.cluster.local [priv8]192.168.33.5[/priv8]:48344 [priv8]10.110.152.25[/priv8]:8080 [priv8]192.168.33.5[/priv8]:36650 - -
```

We can see the istio-proxy of serviceB use HTTP/1.1 protocol.



## Investigate

We know the traffic path:

```
serviceA app -> serviceA istio-proxy ---(mTLS)--> serviceB app -> serviceB istio-proxy
```

We know Istio use [`ALPN(Application-Layer Protocol Negotiation)` on TLS](https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation) to negotiate which version of HTTP used. See [Better Default Networking – Protocol sniffing](https://docs.google.com/document/d/1l0oVAneaLLp9KjVOQSb3bwnJJpjyxU_xthpMKFM_l7o/edit#heading=h.edsodfixs1x7)



So we run tcpdump on Pod A to inspect ALPN between 2 istio-proxy(s) :

```
ss -K 'dst 192.168.88.94'

tcpdump -i eth0@if3623 'host 192.168.88.94' -c 1000 -s 65535 -w /tmp/tcpdump.pcap

tshark -r /tmp/tcpdump.pcap -d tcp.port==8080,ssl -2R "ssl" -V | less
```



```log
...
Transport Layer Security
    TLSv1.3 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 2723
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Extension: application_layer_protocol_negotiation (len=32)
                Type: application_layer_protocol_negotiation (16)
                Length: 32
                ALPN Extension Length: 30
                ALPN Protocol
                    ALPN string length: 14
                    ALPN Next Protocol: istio-http/1.1
                    ALPN string length: 5
                    ALPN Next Protocol: istio
                    ALPN string length: 8
                    ALPN Next Protocol: http/1.1      
...                    
```

No expected `istio-h2` or `h2` found.



So we dump the Envoy configuration of the istio-proxy of Pod A :

```yaml
configs:
  dynamic_listeners:
        - name: 0.0.0.0_8080
        active_state:
          version_info: 2024-04-16T09:30:41Z/90
          listener:
            '@type': type.googleapis.com/envoy.config.listener.v3.Listener
            name: 0.0.0.0_8080
            address:
              socket_address:
                address: 0.0.0.0
                port_value: 8080
            filter_chains:
              - filter_chain_match:
                  transport_protocol: raw_buffer
                  application_protocols:
                    - http/1.1
                    - h2c
                filters:
                  - name: envoy.filters.network.http_connection_manager
                    typed_config:
                      '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                      stat_prefix: outbound_0.0.0.0_8080
                      rds:
...
                      http_filters:
                        - name: envoy.filters.http.grpc_stats
...
                        - name: istio.alpn
                          typed_config:
                            '@type': type.googleapis.com/istio.envoy.config.filter.http.alpn.v2alpha1.FilterConfig
                            alpn_override:
                              - alpn_override:
                                  - istio-http/1.0
                                  - istio
                                  - http/1.0
                              - upstream_protocol: HTTP11
                                alpn_override:
                                  - istio-http/1.1
                                  - istio
                                  - http/1.1
                              - upstream_protocol: HTTP2
                                alpn_override:
                                  - istio-h2
                                  - istio
                                  - h2
...
                        - name: envoy.filters.http.router
                          typed_config:
                            '@type': type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
                      http_protocol_options:
                        header_key_format:
                          stateful_formatter:
                            name: preserve_case
                            typed_config:
                              '@type': type.googleapis.com/envoy.extensions.http.header_formatters.preserve_case.v3.PreserveCaseFormatterConfig
```





If you search `istio +alpn filter` on Google, you may not found any thing meaningful.



### Background of Upstream HTTP protocol selection



#### Background of native Envoy



There are 3 methods of Upstream HTTP protocol selection of Envoy:

- [explicit_http_config](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/upstreams/http/v3/http_protocol_options.proto#envoy-v3-api-field-extensions-upstreams-http-v3-httpprotocoloptions-explicit-http-config) : To explicitly configure either HTTP/1 or HTTP/2 (but not both!) use `explicit_http_config`
- [use_downstream_protocol_config](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/upstreams/http/v3/http_protocol_options.proto#envoy-v3-api-field-extensions-upstreams-http-v3-httpprotocoloptions-use-downstream-protocol-config) : This allows switching on protocol based on what protocol the downstream connection used.
- [auto_config](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/upstreams/http/v3/http_protocol_options.proto#envoy-v3-api-field-extensions-upstreams-http-v3-httpprotocoloptions-auto-config) : This allows switching on protocol based on ALPN. If this is used, the cluster can use either HTTP/1 or HTTP/2, and will use whichever protocol is negotiated by ALPN with the upstream. Clusters configured with `AutoHttpConfig` will use the highest available protocol; HTTP/2 if supported, otherwise HTTP/1. If the upstream does not support ALPN, `AutoHttpConfig` will fail over to HTTP/1.


![](upstream-http-protocol-selection-src.drawio.svg)


```c++
namespace Envoy { namespace Network {
    class TransportSocketOptions {
  /**
   * The application protocols to use when negotiating an upstream connection. When an application
   * protocol override is provided, it will *always* be used.
   * @return the optional overridden application protocols.
   */
  virtual const std::vector<std::string>& applicationProtocolListOverride() const PURE;
        
    }
}}
```





```c++
namespace Envoy { namespace Network {
...    
TransportSocketOptionsConstSharedPtr
TransportSocketOptionsUtility::fromFilterState(const StreamInfo::FilterState& filter_state) {
  absl::string_view server_name;
  std::vector<std::string> application_protocols;
  std::vector<std::string> alpn_fallback;
...
  bool needs_transport_socket_options = false;
    
  if (auto typed_data = filter_state.getDataReadOnly<Network::ApplicationProtocols>(
          Network::ApplicationProtocols::key());//get ApplicationProtocols(HTTP version) from a filter state map, key: Network::ApplicationProtocols::key(). 
      typed_data != nullptr) {
    application_protocols = typed_data->value();
    needs_transport_socket_options = true;
  }
...
  if (needs_transport_socket_options) {
    return std::make_shared<Network::TransportSocketOptionsImpl>(
        server_name, std::move(subject_alt_names), std::move(application_protocols),
        std::move(alpn_fallback), proxy_protocol_options, std::move(objects),
        std::move(proxy_info));
  } else {
    return nullptr;
  }
}
...
}}
```



```c++
namespace Envoy { namespace Upstream{
    class LoadBalancerContext {
        virtual Network::TransportSocketOptionsConstSharedPtr upstreamTransportSocketOptions() const PURE;
    }

class LoadBalancerContextBase : public LoadBalancerContext {    
  Network::TransportSocketOptionsConstSharedPtr upstreamTransportSocketOptions() const override {
    return nullptr;
  }
}
    
}}
```





```c++
namespace Envoy { namespace Router {
    

class Filter : Logger::Loggable<Logger::Id::router>,
               public Http::StreamDecoderFilter,
               public Upstream::LoadBalancerContextBase...
               {}                   
    
...    
Http::FilterHeadersStatus Filter::decodeHeaders(Http::RequestHeaderMap& headers, bool end_stream) {
	...
  transport_socket_options_ = Network::TransportSocketOptionsUtility::fromFilterState(
      *callbacks_->streamInfo().filterState());
    
    ...
}
    
  Network::TransportSocketOptionsConstSharedPtr Filter::upstreamTransportSocketOptions() const override {
    return transport_socket_options_;
  }    
...
}}
```



```c++
namespace Envoy {namespace Upstream {

Host::CreateConnectionData ClusterManagerImpl::ThreadLocalClusterManagerImpl::ClusterEntry::tcpConn(
    LoadBalancerContext* context) {
  HostConstSharedPtr logical_host = chooseHost(context);
  if (logical_host) {
    auto conn_info = logical_host->createConnection(
        parent_.thread_local_dispatcher_, nullptr,
        context == nullptr ? nullptr : context->upstreamTransportSocketOptions());    
    
}}
```



```c++
namespace Envoy {namespace Extensions { namespace TransportSockets {namespace Tls {
bssl::UniquePtr<SSL>
ClientContextImpl::newSsl(const Network::TransportSocketOptionsConstSharedPtr& options) {

  // We determine what ALPN using the following precedence:
  // 1. Option-provided ALPN override.
  // 2. ALPN statically configured in the upstream TLS context.
  // 3. Option-provided ALPN fallback.

  // At this point in the code the ALPN has already been set (if present) to the value specified in
  // the TLS context. We've stored this value in parsed_alpn_protocols_ so we can check that to see
  // if it's already been set.
  bool has_alpn_defined = !parsed_alpn_protocols_.empty();
  if (options) {
    // ALPN override takes precedence over TLS context specified, so blindly overwrite it.
    has_alpn_defined |= parseAndSetAlpn(options->applicationProtocolListOverride(), *ssl_con);
  }
    
  if (options && !has_alpn_defined && !options->applicationProtocolFallback().empty()) {
    // If ALPN hasn't already been set (either through TLS context or override), use the fallback.
    parseAndSetAlpn(options->applicationProtocolFallback(), *ssl_con);
  }    
    
}}}}
```



```c++
namespace Envoy {namespace Upstream {
std::vector<Http::Protocol>
ClusterInfoImpl::upstreamHttpProtocol(absl::optional<Http::Protocol> downstream_protocol) const {
  if (downstream_protocol.has_value() &&
      features_ & Upstream::ClusterInfo::Features::USE_DOWNSTREAM_PROTOCOL) {
    if (downstream_protocol.value() == Http::Protocol::Http3 &&
        !(features_ & Upstream::ClusterInfo::Features::HTTP3)) {
      return {Http::Protocol::Http2};
    }
    // use HTTP11 since HTTP10 upstream is not supported yet.
    if (downstream_protocol.value() == Http::Protocol::Http10) {
      return {Http::Protocol::Http11};
    }
    return {downstream_protocol.value()};
  }

  if (features_ & Upstream::ClusterInfo::Features::USE_ALPN) {
    if (!(features_ & Upstream::ClusterInfo::Features::HTTP3)) {
      return {Http::Protocol::Http2, Http::Protocol::Http11};
    }
    return {Http::Protocol::Http3, Http::Protocol::Http2, Http::Protocol::Http11};
  }

  if (features_ & Upstream::ClusterInfo::Features::HTTP3) {
    return {Http::Protocol::Http3};
  }

  return {(features_ & Upstream::ClusterInfo::Features::HTTP2) ? Http::Protocol::Http2
                                                               : Http::Protocol::Http11};
}
}}
```



#### Background of Istio'Envoy(istio-proxy)







