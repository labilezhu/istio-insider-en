---
typora-root-url: ../../..
---

# Event-driven vs. threaded model

![event loop](/ch2-envoy/arch/event-driven/event-driven.assets/envoy-event-model-loop.drawio.svg)

Unsurprisingly, Envoy uses `libevent`, a C event library, which uses the Linux Kernel's epoll event driver API.

Let's explain the flow in the diagram:
1. The Envoy worker thread hangs in the `epoll_wait()` method, registering with the kernel to wait for an event to occur on the socket of interest to epoll. The thread is moved out of the kernel's runnable queue, and the thread sleeps. 
2. The kernel receives a TCP network packet, which triggers an event. 
3. the operating system moves the Envoy worker thread into the kernel's runnable queue. the Envoy worker thread wakes up and becomes runnable. the operating system finds an available cpu resource and schedules the runnable Envoy worker thread onto the cpu. (Note that thread runnable and scheduling on a cpu are not completed at once)
4. Envoy analyzes the event list and schedules to different callback functions of `FileEventImpl` class according to the fd of the event list (see `FileEventImpl::assignEvents` for implementation).
5. the callback function of the `FileEventImpl` class calls the actual upper layer callback function
6. Execute the actual proxy behavior of the Envoy
7. When callback tasks done, go back to step 1.



## General flow of HTTP Reverse Proxy

The overall flow of the socket event-driven HTTP reverse proxy is as follows:
![Figure: Socket event-driven HTTP reverse proxy general flow](/ch2-envoy/arch/event-driven/event-driven.assets/envoy-event-model-proxy.drawio.svg)

The diagram shows that there are 5 types of events driving the whole process. Each of them will be analyzed in later sections.

## Downstream TCP connection establishment

Now let's look at the process and the relationship between the event drivers and the connection establishment:
![envoy-event-model-accept](/ch2-envoy/arch/event-driven/event-driven.assets/envoy-event-model-accept.drawio.svg)


1. The Envoy worker thread hangs in the `epoll_wait()` method. The thread is moved out of the kernel's runnable queue. the thread sleeps.
2. client establishes a connection. server kernel completes 3 step handshakes, triggering a listen socket event.
   - The operating system moves the Envoy worker thread into the kernel's runnable queue. the Envoy worker thread wakes up and becomes runnable. the operating system discovers the available cpu resources and schedules the runnable Envoy worker thread onto the cpu (note that runnable and scheduling onto the cpu are not done at the same time).
3. Envoy analyzes the event list and schedules to different callback functions of `FileEventImpl` class according to the fd of the event list (see `FileEventImpl::assignEvents` for implementation).
4. The callback function of `FileEventImpl` class calls the actual upper layer callback function, performs syscall `accept` and completes the socket connection. Get the FD of the new socket: `$new_socket_fd`. 5.
5. The business callback function adds `$new_socket_fd` to the epoll listener by calling `epoll_ctl`. 6.
6. Return to step 1.



## Event Handling Abstraction Framework

The above describes the underlying process of event handling at the kernel syscall level. The following section describes how events are abstracted and encapsulated at the Envoy code level.

Envoy uses `libevent`, an event library written in C, with C++ OOP encapsulation.

![](/ch2-envoy/arch/event-driven/event-driven.assets/abstract-event-model.drawio.svg)


How do you quickly read the core process logic in a project that is heavy (or even excessive) on OOP encapsulation and OOP Design Patterns, instead of drifting directionlessly in a sea of source code? The answer is: find the main flow. For Envoy's event handling, the main flow is, of course, `libevent`'s `event_base`, `event`. If you're not familiar with `libevent`, check out the `libevent Core Ideas` section of this book.

- `event` is encapsulated in an `ImplBase` object. 
- `event_base` is included under `LibeventScheduler` <- `DispatcherImpl` <- `WorkerImpl` <- `ThreadImplPosix`.

The different types of `event` are then encapsulated into different `ImplBase` subclasses:
- TimerImpl
- SchedulableCallbackImpl
- FileEventImpl

Other information is already detailed in the diagram above, so I won't go into more detail.

## libevent Core Ideas

```{toctree}
libevent.md
```


## Extended reading

If you are interested in studying the implementation details, I recommend checking out the articles on my Blog:

 - [Reverse Engineering and Cloud Native Field Analysis Part3 -- eBPF Trace Istio/Envoy Event Driven Model, Connection Establishment, TLS Handshake and filter_chain Selection](https://blog.mygraphql.com/zh/posts/low-tec/trace/trace-istio/trace-istio-part3/)
 - [BPF tracing istio/Envoy - Part4: Upstream/Downstream Event-Driven Collaboration of Envoy@Istio](https://blog.mygraphql.com/en/posts/low-tec/trace/trace-istio/trace-istio-part4/)

And last but not least: Envoy author Matt Klein: [Envoy threading model](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)