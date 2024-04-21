# Listener connection establishment details

The process and relationship between event-driven and connection establishment:
![envoy-event-model-accept](/ch2-envoy/arch/event-driven/event-driven.assets/envoy-event-model-accept.drawio.svg)

1. The Envoy worker thread hangs in the `epoll_wait()` method. The thread is moved out of the kernel's runnable queue. the thread sleeps.
2. client establishes a connection. server kernel completes 3 handshakes, triggering a listen socket event.
   - The operating system moves the Envoy worker thread into the kernel's runnable queue. the Envoy worker thread wakes up and becomes runnable. the operating system discovers the available cpu resources and schedules the runnable Envoy worker thread onto the cpu (note that runnable and scheduling onto the cpu are not done at the same time). (Note that runnable and scheduling on cpu are not done at the same time)
3. Envoy analyzes the event list and schedules to different callback functions of FileEventImpl class according to the fd of the event list (see `FileEventImpl::assignEvents` for implementation).
4. The callback function of FileEventImpl class calls the actual business callback function, performs syscall `accept` and completes the socket connection. Get the FD of the new socket: `$new_socket_fd`.
5. The business callback function adds `$new_socket_fd` to the epoll listener by calling `epoll_ctl`.
6. Return to step 1.

### TCP Connection Establishment Procedure
Take a look at the code to get a general idea of how the connection is established and how it is implemented:

:::{figure-md}
:class: full-width
<img src="/ch2-envoy/arch/listener/listener-connection.assets/envoy-classes-accept-flow.drawio.svg" alt="Figure - Listener TCP Connection Establishment Process">

*Figure: Listener TCP Connection Establishment Process*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-classes-accept-flow.drawio.svg)*



The steps are:
1. epoll receives the connection request and completes 3 handshakes. It is better to callback to TcpListenerImpl::onSocketEvent().
2. eventually syscall `accept()` to get the FD of the new socket.
3. call ActiveTcpListener::onAccept()
4. create a new connection-specific `ListenerFilterChain`. 
5. create an `ActiveTcpSocket` dedicated to the new connection and initiate the `ListenerFilterChain` process
6. Execute the `ListenerFilterChain` process:
   1. e.g., TlsInspector::Filter registers to listen for events on the new socket, so that it can read the socket and extract the TLS SNI/ALPN when subsequent events occur on the new socket. 2.
   2. When all `ListenerFilter`s in the `ListenerFilterChain` have completed all their data exchange and extraction tasks in the new event and event cycle, control of this fd is handed over to one session.
7. call the core function `ActiveTcpListener::newConnection()`
8. call findFilterChain() to find the best matching `network filter chain configuration` based on the data extracted by the `ListenerFilter` and the match conditions of each `network filter chain configuration`.
9. Create the `ServerConnection` (a subclass of ConnectionImpl) object.
   1. Register the socket event callback to `Network::ConnectionImpl::onFileEvent(uint32_t events)`. This means that future socket events will be handled by this `ServerConnection`. 
10. Create a `transportSocket` with the `network filter chain configuration` object found earlier.
11. Create a runtime `NetworkFilterChain` with the previously found `network filter chain configuration` object.

## Proofing
If you're interested in looking at the implementation details, I recommend checking out the articles on my Blog:
 - [Reverse Engineering and Cloud Native Field Analysis Part3 -- eBPF Trace Istio/Envoy Event Driven Model, Connection Establishment, TLS Handshake and filter_chain Selection](https://blog.mygraphql.com/zh/posts/low-tec/trace/trace-istio/trace-istio-part3/)
