---
typora-root-url: ../..
---

# Envoy request and response scheduling 
🎤 Before get start. I'd like to talk about some of the story reasons for writing this section. Why should I study Envoy's request and response scheduling?  
It started with a customer request to do some research on fast recovery from Istio worker node failures. To do this, I went through a lot of Istio/Envoy documentation, blogs, and a lot of info:
 - Health Detection
 - Circuit breaking
 - Envoy's mysterious and inextricably linked timeout configurations
 - Request Retry
 - `TCP keepalive`, `TCP_USER_TIMEOUT` configuration

At the end, I had to write a post to sort out the information: [A First Look at Rapid Recovery from Istio Worker Node Failures](https://blog.mygraphql.com/zh/posts/low-tec/network/tcp-close/tcp-half-open/). But while the information was sorted out, the underlying principles were not. So I decided to dig into Envoy's documentation. Yes, Envoy's documentation is actually quite detailed. However:
 - The information is scattered in a web page, can not be organized in a chronological and flow method, constituting an organic whole.
 - It's impossible to rationally weigh these parameters without understanding the overall collaboration and just looking at them one by one.
 - Metrics and Metrics, Metrics and setting parameters, complex relationship
 - Above relationships can be linked through the request and response scheduling process.

For the above reasons. I deduce the following flow from the documents, setting parameters and metrics. <mark>Note: not verified in the code for the time being, please refer to it with caution. </mark>


## Request and Response Scheduling
Essentially, Envoy is an proxy. When talking about proxies, the first thought should be software/hardware that has the following processes:
1. receive a `Request` from the `downstream`
2. do some logic, modify the `Request` if necessary, and determine the `upstream` destination
3. forward the (modified) `Request` to `upstream`
4. if the protocol is a `Request` & `Response` style protocol (e.g. HTTP)
   1. the proxy usually receives a `Response` from the `upstream`.
   2. does some logic and modifies the `Response` if necessary 
   3. forward the `Response` to the `downstream`.
Indeed, this is the outline of how Envoy proxies the HTTP protocol. But there are many more features that Envoy has to implement:
1. efficient `downstream` / `upstream` transfer ➡️ requires `connection multiplexing` and `connection pooling`.
2. flexible configuration of forwarding target service policies ➡️ requires `Router` configuration policies and implementation logic
3. resilient micro-services
   1. load balancing
   2. peak shaving and troughing of unexpected traffic ➡️ request queuing: pending request
   3. cope with abnormal upstream, Circuit breaking, protect service from avalanche ➡️ various timeout configurations, health checking, Outlier detection, Circuit breaking
   4. elastic retry ➡️ retry
4. observability ➡️ ubiquitous performance metrics
5. dynamic programming configuration interface ➡️ xDS: EDS/LDS/...

To implement these features, the request and response process must not simple.  


```{hint}
The reader may wonder if the title of this section is "Request and Response Scheduling"? Does the Envoy need to be scheduled like a Linux Kernel scheduling thread to process the request? 
Yes, you've hit the nail on the head.
```

Envoy applies the `event-driven` design pattern. An `event-driven` program, compared to a `non-event-driven` program, has fewer threads and more flexible control over what tasks to do when, i.e. more flexible scheduling logic. And even better: since there is not much data shared between threads, the data concurrency control of threads is at the same time greatly simplified.

In this section, the event types at least includes:
 - External network readable, writable, connection closure events
 - Various types of timers
   - Retry timings
   - Various timeout configuration timings

Because of the pattern of using an unlimited number of requests assigned to a limited number of threads, and the fact that requests may need to be retried, the threads must have a series of logic to `order` what requests should be processed first. What requests should immediately return a failure due to `timeout` or resource usage `over the configured limit`.

As is customary in this book, the diagram is shown first. Later, a step-by-step expansion and explanation of this diagram.


```{hint}
Interactive book:
 - It is recommended to open it with Draw.io. The diagrams contain a large number of links to the documentation descriptions of each component, configuration item, and indicator.
 - Dual monitors, one for the diagrams and one for the text, is the recommended way of reading for this book. If you're reading it on your phone, well, ignore me 🤦
```

:::{figure-md} Figure : Envoy Request and Response Scheduling
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline-schedule.drawio.svg" alt="Figure - Envoy Request and Response Scheduling">

*Figure : Envoy Request and Response Scheduling*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline-schedule.drawio.svg)*

### Related Components
The above figure attempt to illustrate the `Envoy Request and Response Scheduling` process, and the components associated with it in tandem. Some of the components can be seen here:
- Listener - responds to downstream connection requests
- HTTP Connection Manager (HCM) - the core component of HTTP that facilitates the reading, interpreting, and routing of http streams (Router).
- HCM-router - the core HTTP routing component, responsible for.
  - Determine the HTTP next-hop destination cluster, i.e. upstream cluster.
  - Retries
- Load balancing - Load balancing within the upstream cluster.
- pending request queue - `a queue of requests waiting for available connections from the connection pool`.
- requests bind to connection - requests that have already been assigned to a connection
- connection pool - connection pool dedicated to worker threads and upstream hosts
- health checker/Outlier detection - upstream host health checker, finds abnormal hosts and quarantines them.

And some `Circuit breaking` cap conditions:
- `max_retries` - maximum retries concurrency limit
- `max_pending_requests` - the upper limit of the `pending request queue`.
- `max_requests` - maximum concurrent requests limit
- `max_connections` - maximum number of connections for upstream cluster

Note that the above parameters are for the entire upstream cluster, i.e. the maximum number of all worker threads and upstream hosts combined.


### Related monitoring metrics
We categorize metrics using a methodology similar to the well-known [Utilization Saturation and Errors (USE)](https://www.brendangregg.com/usemethod.html) methodology.

Resource overload type metrics:
- [downstream_cx_overflow](https://www.envoyproxy.io/docs/envoy/v1.15.2/configuration/listeners/stats#listener:~:text=downstream_cx_overflow)
- upstream_rq_retry_overflow
- upstream_rq_pending_overflow
- upstream_cx _overflow

Resource saturation metrics:
- upstream_rq_pending_active
- upstream_rq_pending_total
- upstream_rq_active

Error-based metrics:
- upstream_rq_retry
- ejections_acive
- ejections_*
- ssl.connection_error

Information-based metrics:
- upstream_cx_total
- upstream_cx_active
- upstream_cx_http*_total

Since the figure already illustrates the relationship between metrics, components, and configuration items, I won't describe it here. The figure also provides links to the metrics documentation and related configuration.


### Envoy request scheduling flow

Let's start with the request component flow part, the flowchart can be reasoned from the relevant documentation as (not fully verified, partial reasoning exists):


:::{figure-md} Figure: Envoy Request Scheduling Flowchart of HTTP/1
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline-flowchart.drawio.svg" alt="Figure - Envoy Request Scheduling Flowchart of HTTP/1">

*Figure: Envoy Request Scheduling Flowchart of HTTP/1*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline-flowchart.drawio.svg)*


:::{figure-md} Figure: Envoy Request Scheduling Flowchart of HTTP/2
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline-flowchart-h2.drawio.svg" alt="Figure - Envoy Request Scheduling Flowchart of HTTP/2">

*Figure: Envoy Request Scheduling Flowchart of HTTP/2*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline-flowchart-h2.drawio.svg)*


## Request and Response Scheduling Timeline

As mentioned at the beginning of this section, the immediate reason for writing this section was: the need to do some research on fast recovery from Istio worker node failures. The premise of `fast recovery` is:

- A fast response to a request that has been sent to or bound to a `failed upstream host` fails.
- Use `Outlier detection / health checker` to identify the `failed upstream host` and move it out of the load balanced list.
All of the problems depend on one question: how do you define and detect when an `upstream host` fails?
- Network partition or peer crashes or overloaded
  - In most cases, distributed systems can only detect such problems through timeouts. So, to quickly discover a `failed upstream host` or `failed request`, you need to configure the timeout appropriately.
- peer responding with a Layer 7 failure (e.g., HTTP 500), or a Layer 3 failure (e.g., TCP REST/No router to destination/ICMP error).
  - These are failures that can be quickly detected

For cases where `network partitions or peers are crashed or overloaded` timeout based discovery is required, Envoy provides a rich set of timeout configurations. It's so rich that sometimes it's hard to know which one is the right one to use. It is easy to miss configuring, e.g configuring some values that are logically long or short and contradict the implementation design. So, I tried to rationalize the `request and response scheduling timeline`, and then look at the related timeout configurations associated with which point of this timeline, then the whole logic is clear. The configuration is also easier to rationalize.

The following diagram shows the request and response timeline, and the associated timeout configurations with the resulting metrics, and how they are related.


:::{figure-md} Figure: Envoy Request and Response Timeline
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline.drawio.svg" alt="Figure - Envoy Request and Response Timeline">

*Figure: Envoy Request and Response Timeline*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline.drawio.svg)*



Briefly explain the timeline:

1. if downstream reuses a previous connection, step 2 & 3 can be skipped.
2. downstream initiates a new connection (TCP handshake)
3. TLS handshake
4. the Envoy receives the downstream request header & body
5. the Envoy executes the Router rules to determine the upstream cluster for the next hop.
6. the Envoy executes the Load Balancing algorithm to determine the upstream host of the next upstream cluster.
7. If the Envoy already has a free connection to the upstream host, skip 8 & 9.
8. Envoy initiates a new connection to the upstream host (TCP handshake).
9. the Envoy initiates a TLS handshake with the upstream host
10. The Envoy forwards the request header & body to the upstream host.
11. The Envoy receives the response header & body from the upstream host.
12. upstream host starts idle connection
13. Envoy forwards response header & body to downstream host.
14. downstream host connection starts idle

Accordingly, the timeout configurations are labeled in relation to the timeline steps, in the following order from the start of the timeline

- max_connection_duration
- transport_socket_connect_timeout
  - metrics `listener.downstream_cx_transport_socket_connect_timeout`

- request_headers_timeout

- Envoy's route.timeout is Istio's [Istio request timeout(outbound)](https://istio.io/latest/docs/tasks/traffic-management/request-timeouts/)
  Note that this timeout value takes into account the total time of the actual retry while the request is being processed.
  - indicator `cluster.upstream_rq_timeout`
  - indicator `vhost.vcluster.upstream_rq_timeout`

- max_connection_duration

- connection_timeout
  - `upstream_cx_connect_timeout` metrics

- transport_socket_connect_timeout

- httpprotocoloptions.idle_timeout




## Summary

If you want Envoy to perform as expected under stressful and abnormal conditions, you need to configure Envoy in a way that makes sense for your specific application and scenario. The prerequisite for configuring this set of parameters is to have an insight into the processing flow and logic. I've gone through the `request and response scheduling` and `request and response scheduling timeline` above. I hope this helps in understanding these aspects.

It's not just Envoy, it's all the middleware that does proxying, and probably the most core stuff is in this piece. So, don't expect to get all the knowledge at once. Here, also just want to let the reader in these processes, there is a clue, and then through the clues to learn, so as not to lose their way.



```{toctree}
:maxdepth: 3
http-timeout.md
```



## Some interesting extended reading


> - [https://www.istioworkshop.io/09-traffic-management/06-circuit-breaker/](https://www.istioworkshop.io/09-traffic-management/06-circuit-breaker/)
> - [https://tech.olx.com/demystifying-istio-circuit-breaking-27a69cac2ce4](https://tech.olx.com/demystifying-istio-circuit-breaking-27a69cac2ce4)
> - [https://www.envoyproxy.io/docs/envoy/latest/faq/configuration/timeouts](https://www.envoyproxy.io/docs/envoy/latest/faq/configuration/timeouts)