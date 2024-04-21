---
typora-root-url: ../../..
---

# Listener
A `Listener`, as the name suggests, is a component that passively listens and accepts connections. Does every Listener listen to a socket? Let's take a look at this question.

Before we start learning about Listener, let's review the example in {doc}`/ch2-envoy/envoy@istio-conf-eg` in the previous section.

```{note}
Download the Envoy configuration here yaml {download}`envoy@istio-conf-eg-inbound.envoy_conf.yaml </ch2-envoy/envoy@istio-conf-eg.assets/envoy@istio-conf-eg-inbound.envoy_conf.yaml>` .
```

:::{figure-md}
:class: full-width
<img src="/ch1-istio-arch/istio-ports-components.assets/istio-ports-components.drawio.svg" alt="Istio port and components">

*Figure - Istio ports and components*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fistio-ports-components.drawio.svg)*


:::{figure-md}
:class: full-width

<img src="/ch2-envoy/envoy@istio-conf-eg.assets/envoy@istio-conf-eg-inbound.drawio.svg" alt="Inbound vs Outbound concepts">

*Figure - Example of Envoy Inbound configuration in Istio*

:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy@istio-conf-eg-inbound.drawio.svg)*

:::{figure-md}
:class: full-width
<img src="/ch2-envoy/envoy@istio-conf-eg.assets/envoy@istio-conf-eg-outbound.drawio.svg" alt="Diagram - Example of Envoy Outbound configuration in Istio">

*Figure - Envoy Outbound Configuration Example in Istio*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy@istio-conf-eg-outbound.drawio.svg)*


## Listener example
In the example above, the reader can see a number of Istio configured Listener's in action:
Inbound.
- Port: 15006
   - Name: virtualInbound
   - Function: The main Inbound Listener
-  Port: 15090
-  Port: 15000
-  ...


Outbound.
- Listener for Bind socket
  - Port: 15001
    - Name: virtualOutbound
    - Duty: Main Outbound Listener. forwards iptable hijacked traffic to the following Listener
- Listener that does not Bind socket
  - Name: 0.0.0.0_8080
  - Responsibility: All upstream cluster traffic listening on port 8080 will go out via this Listener.
  - Configuration
    - bind_to_port: false

As you can see, the name Istio gives to the Listener is a bit hard to understand. The ones that actually listen to TCP ports are called `virtualInbound`/`virtualOutbound`, while the ones that don't listen to TCP ports don't have the `virtual` prefix.


## Listener internal components
:::{figure-md} Figure: Listener Internal Components
<img src="/ch2-envoy/arch/listener/listener.assets/listener.drawio.svg" alt="Figure - Listener Internal Components">
*Figure: Listener Internal Components*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Flistener.drawio.svg)*

Listener consists of `Listener filters`, `Network Filter Chains`.
The concepts of `Listener Filter` and `Network Filter` are easy to confuse. Let's briefly explain them:
- `Listener Filter` : Collects the first few pieces of information on the connection at the beginning of the connection, and prepares the data for selecting the `Network Filter Chain`.
  - It can collect basic TCP data, such as src IP/port, dst IP/port, or the original dst IP/port before iptables forwarding.
  - It can be TLS handshake data, SNI / APLN.
- `Network Filter`: 
  - After TCP/TLS handshake, it will process higher layer protocols, such as TCP Proxy / HTTP Proxy.



### Listener filters
For example, in the {ref}`Figure: Example of Envoy Inbound Configuration in Istio`, you can see a few Listener filters.
 - envoy.filters.listener.original_dst
 - envoy.filters.listener.tls_inspector
 - envoy.filters.listener.http_inspector

The functionality has been stated in the diagram.

### Network Filter Chains
For example, in the {ref}`figure: Envoy Inbound Configuration Example in Istio` above, you can see several Network Filter Chains with repeatable names. Each of these has its own `filter_chain_match`, which Envoy uses to match connections to different `Network Filter Chains`.  
Each `Network Filter Chain` consists of sequentialized `Network Filters`. The `Network Filters` are described in a later section.


## Listener related components and startup sequence
:::{figure-md} Figure: Listener core objects and startup sequence
<img src="/ch2-envoy/arch/listener/listener.assets/listener-core-classes-startup-process.drawio.svg" alt="Figure - Listener core objects and startup sequence">
*Figure: Listener core objects and startup sequence*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Flistener-core-classes-startup-process.drawio.svg)*

Sorry for pulling back to the ground and talking about the source code directly from the High Level description above. But I'll try not to scare people by posting the source code, but rather start with the class functionality, structure, and responsibilities.
Envoy has only two types of Listener implementations, TCP and UDP. I'm only going to look at TCP here. There is a lot of information in the picture, don't be afraid, I'll explain it slowly.
First, let's introduce the core classes:
- `TcpListenerImpl` - the main class at the core of Listener. It is responsible for listen socket and listen socket event handling.
  - Each Worker Thread creates its own instance of `TcpListenerImpl` for each Listener in the configuration.
    - For example, we have two Listener configurations, L1 and L2, and two work threads: W0 and W1. Then there will be 4 `TcpListenerImpl` instances. 
  - The `TcpListenerImpl` class has a `bool bind_to_port` attribute, so we can assume that `TcpListenerImpl` may not bind/listen to sockets.
- `TcpListenSocket` - Responsible for the actual socket operations of the Listner, including `bind` and `listen`.
- WorkerImpl - The main entry class for the worker thread.
- DispatcherImpl - The main event loop and queue class.
- ListenerManagerImpl
  - Create and bind `TcpListenSocket`.
  - Create `WorkerImpl` with configuration parameters.
  - Trigger creation of `TcpListenerImpl`.
Or maybe you're like me and you're just looking at Envoy's code and you're getting confused with classes that have similar names. For example: `TcpListenerImpl`, `TcpListenSocket`.
If you look at the illustration, you will know that the black and red lines represent different types of threads. The main flow in the diagram:
1. the `main thread` indirectly call ListenerManagerImpl
2. bind socket to ip and port
3. start a new worker thread
4. add asynchronous task: `add Listener task` (once per worker + Listener) to worker's task queue.
5. worker thread takes out the task queue and executes `add Listener task`.
6. the worker thread asynchronously listens to the socket, and registers the event handler.


If you're careful, you'll see something trick:
- Why bind sockets in the main thread?
  - It is possible to detect socket listener conflicts and other common problems early in the process. This is explained in detail in the Envoy source documentation at https://github.com/envoyproxy/envoy/blob/main/source/docs/listener.md .
- Can two worker threads listen to the same socket?
  - In older versions, where `reuse_port` socket opts were not used by default, the duplicate socket/file descriptor method was used to duplicate a file descriptor for each work thread.
  - The new version uses `reuse_port` socket opts by default, so that each thread can bind the same port independently. For the benefits, see my article: [Remembering an Istio Tuning Part 2 -- Starving Threads with SO_REUSEPORT](https://blog.mygraphql.com/zh/posts/cloud/istio/istio-tunning/istio-thread-balance/)


### Code-level startup sequence
:::{figure-md} Figure: Listener TCP Connection Establishment Flow
<img src="/ch2-envoy/arch/listener/listener.assets/envoy-classes-listen-flow.drawio.svg" alt="Figure - Listener TCP connection establishment flow">

*Figure: Listener TCP connection establishment flow*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-classes-listen-flow.drawio.svg)*

Listener related components and startup sequence - the core flowchart illustrates the following steps (with `reuse_port=false`):
1. process main indirectly calls `ListenerManagerImpl` to indirectly create a socket, assuming the file descriptor is `fd-root`
2. bind socket to ip and port
3. start a new worker thread
4. add asynchronous task: `add Listener task` (once per worker + Listener) to worker's task queue.
5. worker thread takes out the task queue and executes `add Listener task`.
6. worker thread duplicate file descriptor `fd-root` to `fd-envoy`
7. worker thread asynchronously listens to the socket and registers event handlers.

## The proof process
If you're interested in looking at the details of Listener's implementation, I recommend checking out my Blog post:
 - [Reverse Engineering and Cloud Native Site Analysis Part2 -- eBPF Trace Istio/Envoy Startup, Listening and Thread Load Balancing](https://blog.mygraphql.com/en/posts/low-tec/trace/trace-istio/trace-istio-part2/)
 - [Reverse Engineering and Cloud Native Field Analysis Part3 -- eBPF Trace Istio/Envoy Event-Driven Model, Connection Establishment, TLS Handshake and Filter_Chain Selection](https://blog.mygraphql.com/en/posts/low-tec/trace/trace-istio/trace-istio-part3/)

```{toctree}
listener-connection.md
```
