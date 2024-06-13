# TCP statistics

There are 3 treasures for SRE / Supporting / Performance test team in distress of troubleshooting:

- Network Problems
- Reboot
- Hardware failure

If you meet a smart partner, he/she will be pursued: “Please use the data to prove your claim”. If you say it's a network problem, how do you prove it?

The straight line is of course to get a network problem measurement tool (e.g. iPerf) to test the network quality and packet loss rate. It's certainly great if the report proves it, but my experience has been that it's only noticeable when Ops makes low-level mistakes like MTU misconfiguration. I call this tool, which does not directly measure the effective traffic of the service, an `offline measurement tool`. The biggest problem is that it is too different from the real world and it is difficult to ensure that the measurement results are consistent with the real world problem. In a k8s environment, the network topology is more complex and offline measurements are harder to rely on.

The opposite is, of course, the `online measurement tools` that directly measure the business traffic. Note that online does not mean only on the production line, but also in test environments, such as stress tests, Chaos tests, disruptive test environments. There are many TCP connection quality measurement/inspection tools of this type:


- Connection-level `ss`: see my previous post [Probably the most complete description of the TCP connection health metrics tool, ss](https://blog.mygraphql.com/zh/notes/low-tec/network/tcp-inspect/).
- Container-level `nstat` : see my previous post [“From performance problem localization, to performance modeling, to TCP - what's TCP doing in a microservices cloud native series Part 1”](https://blog.mygraphql.com/zh/posts/low-tec/network/tcp-flow-control-part1/#采集-tcp-指标)
- ebpf-based tcp stats inspect tool
  - [cloudflare/ebpf_exporter](https://github.com/cloudflare/ebpf_exporter)
  - [tcpdog](https://github.com/mehrdadrad/tcpdog)
  - [ebpf-network-viz](https://github.com/iogbole/ebpf-network-viz)
  - [BCC - tcpretrans](https://github.com/iovisor/bcc/blob/master/tools/tcpretrans.py)

In this article, however, I'm going to use the native Envoy, which I'm familiar with, as the connection-level tcp stats inspect tool. (Note that it's [Native Envoy](https://github.com/envoyproxy/envoy), not [Istio Proxy](https://github.com/istio/proxy), and I'll explain why later).

The architecture is as follows:
```
[client(Traffic Generator)] --> [Envoy Proxy] -----external network may drop packets-----> [Application Cluster Gateway]
```

In a test environment, Envoy has some advantages over the above tools in some cases:
- Comes with mature and diverse monitoring metrics at the L7 (HTTP) layer.
  - For a client (the traffic generation side of the test, e.g. JMeter). We often wonder about its actual concurrency, TPS, etc. With a professional Envoy metrics, you can get a good idea of what you're getting. With sidecar metrics for professional http, everything is more transparent and controllable.
- Comes with L4/L3 (TCP/IP) layer metrics, tcp-stats, which is the focus of this article.
- Comes with a variety of mature traffic control techniques



## Lost Envoy Sidecar Observability Initials

One of the most popular features of Istio back in the day was Observability. But from what I've seen over the years, observability is rarely used or studied in depth in real-world environments. Many metrics can't be understood by reading a single line of description.

### More lost tcp_stats

Here's a look at the native Envoy's [TCP statistics](https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats#config-cluster-manager-cluster-stats-tcp) as an example:


| Name                                 | Type      | Description                                                  |
| ------------------------------------ | --------- | ------------------------------------------------------------ |
| cx_tx_segments                       | Counter   | Total TCP segments transmitted                               |
| cx_rx_segments                       | Counter   | Total TCP segments received                                  |
| cx_tx_data_segments                  | Counter   | Total TCP segments with a non-zero data length transmitted   |
| cx_rx_data_segments                  | Counter   | Total TCP segments with a non-zero data length received      |
| cx_tx_retransmitted_segments         | Counter   | Total TCP segments retransmitted                             |
| cx_rx_bytes_received                 | Counter   | Total payload bytes received for which TCP acknowledgments have been sent. |
| cx_tx_bytes_sent                     | Counter   | Total payload bytes transmitted (including retransmitted bytes). |
| cx_tx_unsent_bytes                   | Gauge     | Bytes which Envoy has sent to the operating system which have not yet been sent |
| cx_tx_unacked_segments               | Gauge     | Segments which have been transmitted that have not yet been acknowledged |
| cx_tx_percent_retransmitted_segments | Histogram | Percent of segments on a connection which were retransmistted |
| cx_rtt_us                            | Histogram | Smoothed round trip time estimate in microseconds            |
| cx_rtt_variance_us                   | Histogram | Estimated variance in microseconds of the round trip time. Higher values indicated more variability. |



As you can see, Envoy has the ability to obtain some network quality related metrics at the TCP level for upstream/downstream.

It is enabled by a [TCP Stats Transport Socket wrapper](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/transport_sockets/tcp_stats/v3/tcp_stats.proto#envoy-v3-api-msg-extensions-transport-sockets-tcp-stats-v3-config) 。If you are interested in how it work, see：[source code](https://github.com/envoyproxy/envoy/blob/6b9db09c69965d5bfb37bdd29693f8b7f9e9e9ec/source/extensions/transport_sockets/tcp_stats/tcp_stats.cc#L81)。Note that a linux kernel >= 4.6 is required to use this feature. This is why Istio Proxy is built without tcp stats by default:

https://github.com/istio/proxy/blob/2320d000121a42ac5e423c0b29e4ae210174a474/bazel/extension_config/extensions_build_config.bzl#L505

```
ISTIO_DISABLED_EXTENSIONS = [
    # ISTIO disable tcp_stats by default because this plugin must be built and running on kernel >= 4.6
    "envoy.transport_sockets.tcp_stats",
]
```



Maybe the above a bit too in-depth, drive away some of the readers. Here's a simple example of how to use it.




## Simple use of TCP Stats Transport Socket wrapper

The following is an example of this topology:

```
[curl(to www.example.com:80) --(redirect to 8080)--> Envoy Proxy:8080(L7 proxy to www.example.com:443)] -----external network may drop packets-----> [www.example.com:443]
```

### Envoy's configuration file

Let's take a look at the Envoy configuration file `envoy-demo-simple-http-proxy-tcp-stats.yaml`:

```yaml
"admin": {
     "address": {
      "socket_address": {
       "address": "127.0.0.1",
       "port_value": 15000
      }
     }
}

static_resources:

  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          access_log:
          - name: envoy.access_loggers.stdout
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: www.example.com
      transport_socket:
        name: envoy.transport_sockets.tcp_stats
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tcp_stats.v3.Config
          update_period: 5s            
          transport_socket:
            name: envoy.transport_sockets.raw_buffer
            typed_config: 
              "@type": type.googleapis.com/envoy.extensions.transport_sockets.raw_buffer.v3.RawBuffer


  clusters:
  - name: www.example.com
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    connect_timeout: 1000s
    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
        explicit_http_config:
          http2_protocol_options:
            max_concurrent_streams: 100
    transport_socket:
      name: envoy.transport_sockets.tcp_stats
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tcp_stats.v3.Config
        update_period: 5s            
        transport_socket:
          name: envoy.transport_sockets.tls
          typed_config: 
            "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
            common_tls_context:
            sni: www.example.com
    load_assignment:
      cluster_name: www.example.com
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: www.example.com
                port_value: 443
```

### Local Linux and network environment

```bash
export ENVOY_PORT=8080

# create a new user u202406 to label the TCP traffic
sudo useradd -u 202406 u202406
sudo --user=u202406 id

# Redirect all connections which target at 80 to 8080. Limit redirect TCP connection only from user u202406
sudo iptables -t nat -A OUTPUT  -m owner --uid-owner 202406 -p tcp --dport 80 -j REDIRECT --to-ports "$ENVOY_PORT"

curl -v www.example.com
# success

sudo --user=u202406 time curl www.example.com
# connection refuse
```

### Starting Envoy and simple tests

Open three terminals and execute them separately:

```bash
./envoy-1.30.2-linux-x86_64  -c ./envoy-demo-simple-http-proxy-tcp-stats.yaml -l debug
```

```bash
watch -d -n 0.5 "curl http://localhost:15000/stats | grep tcp"
```

```bash
sudo --user=u202406 time curl -v www.example.com
```

where the watch terminal outputs data like this:

```
cluster.www.example.com.tcp_stats.cx_rx_bytes_received: 5616
cluster.www.example.com.tcp_stats.cx_rx_data_segments: 10
cluster.www.example.com.tcp_stats.cx_rx_segments: 13
cluster.www.example.com.tcp_stats.cx_tx_bytes_sent: 548
cluster.www.example.com.tcp_stats.cx_tx_data_segments: 4
cluster.www.example.com.tcp_stats.cx_tx_retransmitted_segments: 0
cluster.www.example.com.tcp_stats.cx_tx_segments: 12
cluster.www.example.com.tcp_stats.cx_tx_unacked_segments: 0
cluster.www.example.com.tcp_stats.cx_tx_unsent_bytes: 0
cluster.www.example.com.tcp_stats.cx_rtt_us: P0(nan,200000) P25(nan,202500) P50(nan,205000) P75(nan,207500) P90(nan,209000) P95(nan,209500) P99(nan,209900) P99.5(nan,209950) P99.9(nan,209990) P100(nan,210000)
cluster.www.example.com.tcp_stats.cx_rtt_variance_us: P0(nan,59000) P25(nan,59250) P50(nan,59500) P75(nan,59750) P90(nan,59900) P95(nan,59950) P99(nan,59990) P99.5(nan,59995) P99.9(nan,59999) P100(nan,60000)
cluster.www.example.com.tcp_stats.cx_tx_percent_retransmitted_segments: P0(nan,0) P25(nan,0) P50(nan,0) P75(nan,0) P90(nan,0) P95(nan,0) P99(nan,0) P99.5(nan,0) P99.9(nan,0) P100(nan,0)
listener.0.0.0.0_8080.tcp_stats.cx_rtt_us: P0(nan,19) P25(nan,19.25) P50(nan,19.5) P75(nan,19.75) P90(nan,19.9) P95(nan,19.95) P99(nan,19.99) P99.5(nan,19.995) P99.9(nan,19.999) P100(nan,20)
listener.0.0.0.0_8080.tcp_stats.cx_rtt_variance_us: P0(nan,8) P25(nan,8.025) P50(nan,8.05) P75(nan,8.075) P90(nan,8.09) P95(nan,8.095) P99(nan,8.099) P99.5(nan,8.0995) P99.9(nan,8.0999) P100(nan,8.1)
listener.0.0.0.0_8080.tcp_stats.cx_tx_percent_retransmitted_segments: P0(nan,0) P25(nan,0) P50(nan,0) P75(nan,0) P90(nan,0) P95(nan,0) P99(nan,0) P99.5(nan,0) P99.9(nan,0) P100(nan,0)
```


### Simulating packet loss on the extranet

```bash
export EXAMPLE_COM_IP=93.184.215.14

# drop 50% packet
sudo iptables -D INPUT --src "$EXAMPLE_COM_IP" -m statistic --mode random --probability 0.5 -j DROP
```

```bash
watch -d -n 0.5 "curl http://localhost:15000/stats | grep tcp"
```

```bash
sudo --user=u202406 time curl -v www.example.com
```

At this point, you can see that `time curl` is taking more time than before the packet was dropped. If you write a script to loop curl, you can see in the watch output that the Gauge metrics `cx_tx_unacked_segments` and `cx_tx_unsent_bytes` have non-zero values.

### Data and visualization charts

If you import the data into Prometheus using `http://localhost:15000/stats?format=prometheus`, you can make time-series for network quality and packet loss, RTT dashboards and line charts. These graphs can be overlaid with other API TPS and Latency graphs to confirm the underlying network quality and the impact of TPS and latency.


## downstream TCP monitoring

Above, we talked about TCP monitoring for upstream clusters. Let's talk about downstream. In fact, in the Envoy configuration file `envoy-demo-simple-http-proxy-tcp-stats.yaml`, the tcp stats of the listeners have already been added, so it is possible to monitor downstream TCP. This feature is useful for monitoring network quality on the Istio Gateway side. Unfortunately, the default build of Istio Proxy does not include tcp stats, so you have to build it yourself.


## TCP Proxy

If your client side application does not use plain text http, then you will have to use Envoy to proxy on the TCP tier. You can try to use the Envoy TCP Proxy Filter instead of the `http_connection_manager` in the `envoy-demo-simple-http-proxy-tcp-stats.yaml` configuration file above.



## I think therefore I am - Je pense, donc je suis

Learning about an open source project, some people stop at using it by example, some people stop at documenting its design concepts, and some people incorporate that design concept into their own learning, life, and work. Some people apply it without realizing it. When we learn Istio, one of the wonderful features is that the original application is non-intrusive, 0 coding, through transparent traffic interception, to generate visual traffic metrics. The same idea can be applied to many scenarios. This ability may be one of the basic qualities of future architects or programmers that will not be easily replaced by AI.

> If someone asks you in the future why you are still have a job and not replaced by AI, the answer is, because Descartes said: I think, therefore I am!





