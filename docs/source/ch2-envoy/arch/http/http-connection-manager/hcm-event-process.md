# HTTP Reverse Proxy for HCM upstream/downstream Event-Driven Collaboration

## General flow of HTTP reverse proxy

The overall HTTP reverse proxy flow for socket event driven collaboration is as follows:
![Figure: Socket event-driven HTTP reverse proxy total flow](/ch2-envoy/arch/event-driven/event-driven.assets/envoy-event-model-proxy.drawio.svg )

The diagram shows that there are 4 types of events driving the whole process. Each of them will be analyzed in later sections.

To avoid getting lost in the details of the individual steps at once, the reader is advised to review the total flow of all the steps in the previous examples: 
{doc}`/ch2-envoy/envoy-istio-conf-eg`.

The following is a 5-step explanation of the HTTP proxy process, using HTTP/1.1 as an example:
1. Downstream Read Request module collaboration
2. Downstream Request Router Module Collaboration
3. Upstream Write Request module collaboration
4. Upstream Read Response Module Collaboration
5. Downstream Write Response Module Collaboration



### Downstream Read Request Module Collaboration
:::{figure-md} Figure : Downstream Read-Ready Module Collaboration
<img src="/ch2-envoy/arch/http/http-connection-manager/hcm-event-process.assets/envoy-hcm-read-down-req.drawio.svg" alt="Figure - Downstream Read-Ready Module Collaboration">

*Diagram: Downstream Read-Ready Module Collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-hcm-read-down-req.drawio.svg)*


A rough description of the process:
1. downstream socket readable callback
2. Http::ConnectionManagerImpl reads the socket and incrementally puts it into Http1::ConnectionImpl.
3. Http1::ConnectionImpl calls nghttp2 to incrementally interpret the HTTP request.
4. if nghttp2 thinks it has read the HTTP Request in its entirety, it calls `Http::ServerConnection::onMessageCompleteBase()'
5. `Http::ServerConnection::onMessageCompleteBase()` First **stops the downstream ReadReady listener**.
6. `Http::ServerConnection::onMessageCompleteBase()` calls `Http::FilterManager` to initiate the decodeHeaders iteration of the `http filter chain`. 
7. In general, the last http filter in the `http filter chain` is a `Router::Filter`, and `Router::Filter::decodeHeaders()` is called.
8. The logic of `Router::Filter::decodeHeaders()` is shown below.


#### Downstream Request Router Module Collaboration

:::{figure-md} Figure: Downstream Request Router Module Collaboration
<img src="/ch2-envoy/arch/http/http-connection-manager/hcm-event-process.assets/envoy-hcm-router-on-down-req-complete.drawio.svg" alt="Figure - Downstream Request Router Module Collaboration">

*Figure: Downstream Request Router Module Collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-hcm-router-on-down-req-complete.drawio.svg)*

A rough description of the process:
1. `Router::Filter` , `Router::Filter::decodeHeaders()` is called.
2. Match to Cluster based on the configured Router rules.
3. If the Cluster connection pool object does not exist, create a new one.
4. create a new `Envoy::Router::UpstreamRequest` object. 5. call `Envoy::Router::UpstreamRequest`.
5. call `Envoy::Router::UpstreamRequest::encodeHeaders(bool end_stream)` to encode HTTP header
6. after a series of load balancing algorithms, match the host (endpoint) of the upstream.
7. if the connection to the selected upstream host is insufficient:
   1. open a new socket fd (not connected)
   2. **Register the WriteReady / Connected event for the upstream socket FD**. Prepare to write the upstream request in the event callback.
   3. **Initiate an asynchronous connection request to the upstream host with socket fd**. 8.
8. associate downstream with upstream fd



### Upstream Write Request Module Collaboration

:::{figure-md} Figure: Upstream connect & write module collaboration
<img src="/ch2-envoy/arch/http/http-connection-manager/hcm-event-process.assets/envoy-hcm-upstream-flow-connected-write.drawio.svg" alt="Figure - Upstream connect & write module collaboration">

*Figure: Upstream connect & write module collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-hcm-upstream-flow-connected-write.drawio.svg)*


A rough description of the flow:
1. upstream socket write ready callback.
2. upstream socket write ready callback, find successful connection callback, associate upstream socket to `ConnectionPool::ActiveClient`.
3. upstream socket write ready callback
4. upstream socket write ready callback, write upstream HTTP request.



### Upstream Read Response Module Collaboration
:::{figure-md} Figure: Upstream Read-Response Module Collaboration
<img src="/ch2-envoy/arch/http/http-connection-manager/hcm-event-process.assets/envoy-hcm-upstream-flow-read-resp.drawio.svg" alt="Figure - Upstream Read-Response Module Collaboration">

*Figure: Upstream Read-Response Module Collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-hcm-upstream-flow-read-resp.drawio.svg)*

### Downstream Write Response Module Collaboration

:::{figure-md} Figure: Downstream Write Response Module Collaboration
<img src="/ch2-envoy/arch/http/http-connection-manager/hcm-event-process.assets/envoy-hcm-write-down-resp.drawio.svg" alt="Figure - Downstream Write Response module collaboration">

*Figure: Downstream Write Response Module Collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-hcm-write-down-resp.drawio.svg)*

## Demonstration
- [Reverse Engineering and Cloud Native Field Analysis Part4 -- eBPF Tracks HTTP Reverse Proxy Processes under Istio/Envoy's upstream/downstream Event-Driven Collaboration](https://blog.mygraphql.com/en/posts/low-tec/trace/trace-istio/trace-istio-part4/)
