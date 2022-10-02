---
typora-root-url: ../..
---

# Envoy request and response scheduling

🎤 Before the official compilation. I would like to talk about some of the reasons for writing this chapter. Why study Envoy's request and response scheduling?

It originated from a customer requirement and needed to do some research on the fast recovery of Istio grid node failures. To this end, I read a lot of Istio/Envoy documentation, blogs of big names. I saw a lot of messy information:
 - Health check
 - blown
 - Various mysterious and intricate timeout configurations in Envoy
 - Request Retry
 - `TCP keepalive`, `TCP_USER_TIMEOUT` configuration

At the end of the mess, I had to write an article to sort out the information: [A preliminary study on the rapid recovery of Istio grid node failure](https://blog.mygraphql.com/zh/posts/low-tec/network/tcp-close/ tcp-half-open/) . But the information is sorted out, but the basic principles are not straightened out. So, I decided to delve into the Envoy documentation. Yes, in fact, Envoy's documentation has been written in detail. only:
 - Information is scattered in web pages, and cannot be organized by time sequence and process to form an organic whole.
 - It is impossible to rationally weigh these parameters without understanding the overall cooperation relationship, just looking at each parameter separately.
 - Indicators and indicators, indicators and parameters, the relationship is complex
 - The above relationships can be connected in series through the request and response scheduling process

for the above reasons. I derived the following flow from documentation, parameters, metrics. <mark>Note: It has not been verified in the code for the time being, please refer to it with caution. </mark>

## Request and response scheduling

Essentially, Envoy is a proxy. Speaking of proxies, the first reaction should be software/hardware with the following processes:
1. Receive `Request` from `downstream`
2. Do some logic, modify `Request` if necessary, and determine the `upstream` destination
3. Forward (modified) `Request` to `upstream`
4. If the protocol is a `Request` & `Reponse` style protocol (such as HTTP)
   1. The proxy usually receives the `Response` of `upstream`
   2. Do some logic, modify `Response` if necessary
   3. Forward `Response` to `downstream`

Indeed, this is also the outline flow of Envoy proxying the HTTP protocol. But Envoy has to implement a lot of features:
1. Efficient `downstream` / `upstream` transmission ➡️ requires `connection multiplexing` and `connection pool`
2. Flexible configuration of forwarding target service strategy ➡️ `Router` configuration strategy and implementation logic are required
3. Resilient micro-services
   1. Load Balancing
   2. Reduce peaks and valleys for burst traffic ➡️ Request queuing: pending request
   3. Deal with abnormal upstream, circuit breakers, and protect services from avalanches ➡️ Various timeout configurations, Health checking, Outlier detection, Circuit breaking
   4. Elastic retry ➡️ retry
4. Observability ➡️ Performance metrics everywhere
5. Dynamic programming configuration interface ➡️ xDS: EDS/LDS/...

To achieve these features, the process of request and response naturally cannot be simple.

```{hint}
At this point, readers may have questions, the title of this section is called "Request and Response Scheduling"? Difficulty Does Envoy need to schedule and process Requests like the Linux Kernel schedules threads?

Yep, you're on point.
````

Envoy applies the `event-driven` design pattern. `Event-driven` programs, compared with `non-event-driven` programs, can use fewer threads and more flexibly control when to do tasks, that is, more flexible scheduling logic. What's more, because there is not much data shared between threads, the data concurrency control of threads is greatly simplified at the same time.

In this section, the minimum event types are:

 - External network readable, writable, connection close events
 - Various timers
   - Retry timing
   - Various timeout configuration timings

Since infinite requests are allocated to finite threads, and requests may need to be retried, threads must have a set of logic to "order" which requests should be processed first. Any request that should fail immediately due to a `timeout` or resource usage `exceeding the configured limit`.

According to the habit of this book, the first picture is shown. Later, this figure is expanded and explained step by step.

```{hint}
Interactive Books:
 - It is recommended to open with Draw.io. The diagram contains numerous links to the documentation for each component, configuration item, and indicator.
 - Dual screens, one screen for pictures and one screen for documents, is the correct reading posture for this book. If you are watching on your phone, then ignore me 🤦
````

:::{figure-md} Figure: Envoy request and response scheduling
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline-schedule.drawio.svg" alt="Figure: Envoy request with Response Scheduling">

*Figure: Envoy request and response scheduling*
:::
*[Open with Draw.io](https://app.diagrams.net/#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline-schedule. drawio.svg)*

### Related Components

The above diagram is an attempt to illustrate the `Envoy request and response scheduling` process, and the concatenation of related components. Some of the components can be seen in it:

- Listener - responds to downstream connection requests
- HTTP Connection Manager (HCM) - the core component of HTTP, which promotes the reading, interpretation, and routing of http streams (Router)
- HCM-router - HTTP routing core component, responsible for:
  - Determine the target cluster of the HTTP next hop, that is, the upsteam cluster
  - Retry
- Load balancing - Load balancing within the upstream cluster
- pending request queue - `Queue of requests waiting for available connections to the connection pool`
- requests bind to connection - requests that have been assigned to the connection
- connection pool - dedicated connection pool between worker threads and upstream host
- health checker/Outlier detection - upsteam host health monitoring to detect abnormal hosts and isolate them.

and some `Circuit breaking` upper bound conditions:

- max_retries - maximum retry concurrency limit
- max_pending_requests - the maximum queue limit for `pending request queue`
- max_request - the maximum number of concurrent requests
- max_connections - the maximum connection limit for the upstream cluster

It should be noted that the above parameters are for the entire upstream cluster, that is, the upper limit of the aggregation of all worker threads and upstream hosts.

### Related monitoring indicators

We classify metrics using a methodology similar to the well-known [Utilization Saturation and Errors (USE)](https://www.brendangregg.com/usemethod.html).

Resource overload-shaped indicators:

- [downstream_cx_overflow](https://www.envoyproxy.io/docs/envoy/v1.15.2/configuration/listeners/stats#listener:~:text=downstream_cx_overflow)
- upstream_rq_retry_overflow
- upstream_rq_pending_overflow
- upstream_cx_overflow

Resource Saturation Indicator:

- upstream_rq_pending_active
- upstream_rq_pending_total
- upstream_rq_active

Wrongly shaped indicators:

- upstream_rq_retry
- ejections_acive
- ejections_*
- ssl.connection_error

Informational indicators:

- upstream_cx_total
- upstream_cx_active
- upstream_cx_http*_total

Since the relationship between indicators, components, and configuration items has been explained in the figure, the text will not be described here. The figure also provides links to the indicator documentation and related configuration.

### Envoy request scheduling process

Let’s talk about the flow of the request component first. The flow chart can be inferred from the relevant documents as (not fully verified, there are partial inferences):

:::{figure-md} Figure: Envoy request scheduling flowchart
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline-flowchart.drawio.svg" alt="Figure: Envoy request with Response timing line">

*Figure: Envoy request scheduling flow chart*
:::
*[Open with Draw.io](https://app.diagrams.net/#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline-flowchart. drawio.svg)*

## Request and response scheduling sequence

As mentioned at the beginning of this section, the immediate reason for writing this section is that we need to do some research on the rapid recovery of Istio grid node failures. The premise of `quick recovery` is:

- Failed to respond quickly to requests that have been sent to or bound to the `fault upstream host`
- Use `Outlier detection / health checker` to identify the `faulty upstream host` and remove it from the load balancer list

All questions depend on one question: how to define and discover that `upstream host` is faulty?

- network partition or peer crash or overload
  - Most of the time, distributed systems can only find this kind of problem by timing out. So, to detect `failure upstream host` or `failure request` , you need to configure
- There is a response from the peer, L7 layer failure (such as HTTP 500), or L3 layer failure (such as TCP REST/No router to destination/ICMP error)
  - This is a failure that can be found quickly

For `network partition or peer crash or high load`, which needs to be discovered by timeout, Envoy provides rich timeout configuration. So rich that sometimes people don't know which one to use is reasonable. Even if the configuration is not careful, some logically long and short values ​​that contradict the implementation design are configured. So, I try to use the `request and response scheduling sequence line`, and then see which point in this timeline the related timeout configuration is related to, then the whole logic is clear. Configuration is also easier to rationalize.

The following figure is the timing line of request and response, as well as related timeout configuration and generated metrics, and their connection.

:::{figure-md} Figure: Envoy request and response sequence
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline.drawio.svg" alt="Figure: Envoy Request and Response Timeline">

*Figure: Envoy request and response timing line*
:::
*[Open with Draw.io](https://app.diagrams.net/#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline.drawio. svg)*



Briefly explain the timeline:

1. If the downstream reuses the previous connection, you can skip 2 & 3
2. The downstream initiates a new connection (TCP handshake)
3. TLS handshake
4. Envoy receives downstream request header & body
5. Envoy executes the routing (Router) rules to determine the upstream cluster of the next hop
6. Envoy executes the Load Balancing algorithm to determine the upstream host of the next hop upstream cluster
7. If Envoy already has an idle connection to the upstream host, skip 8 & 9
8. Envoy initiates a new connection to the upstream host (TCP handshake)
9. Envoy initiates a TLS handshake to the upstream host
10. Envoy forwards the request header & body to the upstream host
11. Envoy receives the response header & body of the upstream host response
12. The upstream host connection starts to be idle
13. Envoy sends response header & body to downstream
14. The downstream host connection starts to be idle

Correspondingly, the relationship between the relevant timeout configuration and the timeline steps is also marked in the figure, and the timing sequence from the beginning is as follows

- max_connection_duration
- transport_socket_connect_timeout
  - Metric `listener.downstream_cx_transport_socket_connect_timeout`

- request_headers_timeout

- request_timeout

- Envoy's route.timeout is Istio's [`Istio request timeout(outbound)`](https://istio.io/latest/docs/tasks/traffic-management/request-timeouts/)

  Note that this timeout value takes into account the actual total retry time while the request is being processed.

  - Metric `cluster.upstream_rq_timeout`
  - Metric `vhost.vcluster.upstream_rq_timeout`

- max_connection_duration

- connection_timeout
  - Metric `upstream_cx_connect_timeout`

- transport_socket_connect_timeout

- httpprotocoloptions.idle_timeout

## Summarize

In order for Envoy to have a more expected performance under stress and abnormal conditions, it is necessary to give Envoy some configurations that are reasonable for the specific application environment and scenario. The premise of configuring these parameters is the insight into the relevant processing flow and logic. The `Request and Response Scheduling` and the `Request and Response Scheduling Sequence Line` have been reviewed above. I hope it will be helpful to understand these aspects.

Not just Envoy, in fact, all the middleware that does proxying, probably the most core things are in this piece. So, don't expect to get the full knowledge all at once. Here, I just hope that readers can have a clue in these processes, and then learn through the clues, so as not to lose their way.

## Some interesting extended reading

> - https://www.istioworkshop.io/09-traffic-management/06-circuit-breaker/
> - https://tech.olx.com/demystifying-istio-circuit-breaking-27a69cac2ce4