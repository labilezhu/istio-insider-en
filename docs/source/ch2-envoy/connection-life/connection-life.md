## HTTP Connection Lifecycle Management

## Upstream/Downstream connection uncoupling

> The HTTP/1.1 specification has this design:
> HTTP Proxy is a L7 proxy and should be separate from the L3/L4 connection lifecycle.
Therefore, headers like `Connection: Close` and `Connection: Keepalive` from Downstream will not be forwarded to Upstream by the Envoy. The lifecycle of the Downstream connection is of course controlled by the `Connection: xyz` directive. However, the connection lifecycle of the Upstream connection is not affected by the connection lifecycle of the Downstream connection. That is, there are two separate connection lifecycles.


> [Github Issue: HTTP filter before and after evaluation of Connection: Close header sent by upstream#15788](https://github.com/envoyproxy/envoy/issues/15788#issuecomment-811429722) 说明了这个问题：
> This doesn't make sense in the context of Envoy, where downstream and upstream are decoupled and can use different protocols. I'm still not completely understanding the actual problem you are trying to solve?

## Connection timeout related configuration parameters

:::{figure-md}
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline.drawio.svg" alt="Figure - Envoy connecting timeout timing lines
">

*Figure : Envoy connecting timeout timing lines*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline.drawio.svg)*

### idle_timeout

(Duration) The idle timeout for connections. The idle timeout is defined as the period in which there are no active requests. When the idle timeout is reached the connection will be closed. If the connection is an HTTP/2 downstream connection a drain sequence will occur prior to closing the connection, see [drain_timeout](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/network/http_connection_manager/v3/http_connection_manager.proto#envoy-v3-api-field-extensions-filters-network-http-connection-manager-v3-httpconnectionmanager-drain-timeout). Note that request based timeouts mean that HTTP/2 PINGs will not keep the connection alive. If not specified, this defaults to **1 hour.** To disable idle timeouts explicitly set this to 0.

> Warning
>
> Disabling this timeout has a highly likelihood of yielding connection leaks due to lost TCP FIN packets, etc.

If the [overload action](https://www.envoyproxy.io/docs/envoy/latest/configuration/operations/overload_manager/overload_manager#config-overload-manager-overload-actions) “envoy.overload\_actions.reduce\_timeouts” is configured, this timeout is scaled for downstream connections according to the value for [HTTP\_DOWNSTREAM\_CONNECTION\_IDLE](https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/overload/v3/overload.proto#envoy-v3-api-enum-value-config-overload-v3-scaletimersoverloadactionconfig-timertype-http-downstream-connection-idle).



### max_connection_duration

(Duration) The maximum duration of a connection. The duration is defined as a period since a connection was established. If not set, there is no max duration. When `max_connection_duration` is reached and if there are no active streams, the connection will be closed. If the connection is a downstream connection and there are any active streams, the `drain sequence` will kick-in, and the connection will be force-closed after the drain period. See [drain\_timeout](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/network/http_connection_manager/v3/http_connection_manager.proto#envoy-v3-api-field-extensions-filters-network-http-connection-manager-v3-httpconnectionmanager-drain-timeout).

> [Github Issue: http: Allow upper bounding lifetime of downstream connections #8302](https://github.com/envoyproxy/envoy/issues/8302)
>
> [Github PR: add `max_connection_duration`: http conn man: allow to upper-bound downstream connection lifetime. #8591](https://github.com/envoyproxy/envoy/pull/8591)
>
> [Github PR: upstream: support max connection duration for upstream HTTP connections #17932](https://github.com/envoyproxy/envoy/pull/17932)



> [Github Issue: Forward Connection:Close header to downstream#14910](https://github.com/envoyproxy/envoy/issues/14910#issuecomment-773434342)
> For HTTP/1, Envoy will send a `Connection: close` header after `max_connection_duration` if another request comes in. If not, after some period of time, it will just close the connection.
>
> https://github.com/envoyproxy/envoy/issues/14910#issuecomment-773434342
>
> Note that `max_requests_per_connection` isn't (yet) implemented/supported for downstream connections.
>
> For HTTP/1, Envoy will send a `Connection: close` header after `max_connection_duration` (and before `drain_timeout`) if another request comes in. If not, after some period of time, it will just close the connection.
>
> I don't know what your downstream LB is going to do, but note that according to the spec, the `Connection` header is hop-by-hop for HTTP proxies.



### max_requests_per_connection

(UInt32Value) Optional maximum requests for both upstream and downstream connections. If not specified, there is no limit. Setting this parameter to 1 will effectively disable keep alive. For HTTP/2 and HTTP/3, due to concurrent stream processing, the limit is approximate.

> [Github Issue: Forward Connection:Close header to downstream#14910](https://github.com/envoyproxy/envoy/issues/14910#issuecomment-840892488)
>
> We are having this same issue when using istio ([istio/istio#32516](https://github.com/istio/istio/issues/32516)). We are migrating to use istio with envoy sidecars frontend be an AWS ELB. We see that connections from ELB -> envoy stay open even when our application is sending `Connection: Close`. `max_connection_duration` works but does not seem to be the best option. Our applications are smart enough to know when they are overloaded from a client and send `Connection: Close` to shard load.
>
> I tried writing an envoy filter to get around this but the filter gets applied before the stripping. Did anyone discover a way to forward the connection close header?



### drain_timeout - for downstream only

> [Envoy Doc](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/network/http_connection_manager/v3/http_connection_manager.proto#:~:text=request_headers_timeout%3A%2010s-,drain_timeout,-(Duration)%20The)

(Duration) The time that Envoy will wait between sending an HTTP/2 “shutdown notification” (GOAWAY frame with max stream ID) and a final GOAWAY frame. This is used so that Envoy provides a grace period for new streams that race with the final GOAWAY frame. During this grace period, Envoy will continue to accept new streams. 

After the grace period, a final GOAWAY frame is sent and Envoy will start refusing new streams. Draining occurs both when:

* a connection hits the `idle timeout` 
  * i.e., a connection that hits the `idle_timeout` or `max_connection_duration` starts the `draining` state and the `drain_timeout` timer. For HTTP/1.1, in the `draining` state. If a downstream request comes in, Envoy adds a `Connection: close` header to the response.
  * So the `draining` state and the `drain_timeout` timer will only be entered if the connection has an `idle_timeout` or `max_connection_duration`.


* or during general server draining. 

The default grace period is 5000 milliseconds (5 seconds) if this option is not specified.



> [https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/draining](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/draining)
>
> By default, the `HTTP connection manager filter` will add “`Connection: close`” to HTTP1 requests(Author's Notes: By HTTP Response), send HTTP2 GOAWAY, and terminate connections on request completion (after the delayed close period).



I used to think that drain was only triggered when the Envoy was going to shutdown. Now it seems that whenever there is a planned shutdown of a connection (after the connection reaches `idle_timeout` or `max_connection_duration`), the drain should be triggered.


###  delayed_close_timeout - for downstream only

> (Duration) The delayed close timeout is for downstream connections managed by the HTTP connection manager. It is defined as a grace period after connection close processing has been locally initiated during which Envoy will wait for the peer to close (i.e., a TCP FIN/RST is received by Envoy from the downstream connection) prior to Envoy closing the socket associated with that connection。

That is, in some scenarios, Envoy will write back an HTTP Response before it has finished reading the HTTP Request and wants to close the connection. This is called `Server Prematurely/Early Closes Connection`. There are several possible scenarios:

- The downstream is still sending the HTTP Request (socket write).
- Or there is a `socket recv buffer` in the Envoy kernel that has not been accessed by the Envoy user-space. Typically, the HTTP Content-Length sized body is still in the kernel's `socket recv buffer` and has not been fully loaded into the Envoy user-space.

In both cases, if the Envoy calls `close(fd)` to close the connection, the downstream may receive an `RST` from the Envoy kernel. Eventually the downstream may not read the HTTP Response in the socket and just assume that the connection is abnormal and report an exception to the upper layers: `Peer connection rest`.

See: {doc}`connection-life-race` for details.

To mitigate this, Envoy provides a configuration that delays connection closure. Which wants to wait for the downstream to complete the socket write process. Let the `kernel socket recv buffer` be loaded into `user space`. Then call `close(fd)`.


> NOTE: This timeout is enforced even when the socket associated with the downstream connection is pending a flush of the write buffer. However, any progress made writing data to the socket will restart the timer associated with this timeout. This means that the total grace period for a socket in this state will be `<total_time_waiting_for_write_buffer_flushes>+<delayed_close_timeout>`.

That is, every time the write socket succeeds, the timer will be rested.


> Delaying Envoy’s connection close and giving the peer the opportunity to initiate the close sequence mitigates a race condition that exists when **downstream clients do not drain/process data in a connection’s receive buffer** after a remote close has been detected via a socket write().  

 That is, it can alleviate the situation where downsteam does not read the socket to get a Response after the write socket fails.

> This race leads to such clients failing to process the response code sent by Envoy, which could result in erroneous downstream processing.
> If the timeout triggers, Envoy will close the connection’s socket.
> The default timeout is 1000 ms if this option is not specified.

> Note:
>
> To be useful in avoiding the race condition described above, this timeout must be set to at least <max round trip time expected between clients and Envoy>+<100ms to account for a reasonable “worst” case processing time for a full iteration of Envoy’s event loop>.



> Warning:
>
> A value of 0 will completely disable delayed close processing. When disabled, the downstream connection’s socket will be closed immediately after the write flush is completed or will never close if the write flush does not complete.



Note that `delayed_close_timeout` will not take effect in many cases in order not to impact performance:


> [Github PR: http: reduce delay-close issues for HTTP/1.1 and below #19863](https://github.com/envoyproxy/envoy/pull/19863)
>
> Skipping delay close for:
>
> - HTTP/1.0 framed by connection close (as it simply reduces time to end-framing) 
>
> - as well as HTTP/1.1 if the request is fully read (so there's no FIN-RST race)。即系如果
>
> Addresses the Envoy-specific parts of #19821
> Runtime guard: `envoy.reloadable_features.skip_delay_close`
>
> Also appears in [Release Note for Envoy 1.22.0](https://www.envoyproxy.io/docs/envoy/latest/version_history/v1.22/v1.22.0):
>
> **http**: avoiding `delay-close` for:
>
> - HTTP/1.0 responses framed by `connection: close` 
> - as well as HTTP/1.1 if the request is fully read. 
>
> This means for responses to such requests, the FIN will be sent immediately after the response. This behavior can be temporarily reverted by setting `envoy.reloadable_features.skip_delay_close` to false. If clients are seen to be receiving sporadic partial responses and flipping this flag fixes it, please notify the project immediately.



## Racing conditions after Envoy connection closure

```{toctree}
connection-life-race.md
```