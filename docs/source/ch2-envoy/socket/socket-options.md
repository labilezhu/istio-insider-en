# Socket Options


Recently, I needed to do some HA / Chaos Testing on a k8s cluster + VIP load balance + Istio environment. As shown in the figure below, in this environment, we need to see the impact of worker node B on external users (Client) in case of abnormal shutdown or network partition:

1. request success rate impact
2. performance (TPS/Response Time) impacts

The impact on performance (TPS/Response Time) [](. /socket-options.assets/tcp-half-open-env-k8s-istio.drawio.svg)

The above figure needs some clarification:

- The TCP/IP layer load balancing for external VIPs (virtual IPs) is done through ECMP (Equal-Cost Multi-Path) [Modulo-N](https://datatracker.ietf.org/doc/html/rfc2992#:~:text=will%20look%20at-,modulo%2DN,-and%0A%20%20%20highest%20random) algorithm to distribute the load, which essentially uses the 5-tuple of TCP connections (protocol, srcIP, srcPort, dstIP, dstPort) to distribute the external traffic. Note that this load balancing algorithm is ``stateless`` and the result of the load balancing algorithm changes when the number of targets changes. That is, it is an `unstable algorithm`.
- TCP traffic with dstIP as VIP, comes to the woker node, and then the ipvs/conntrack rule does the stateful, DNAT, dstIP is mapped and translated to the address of any of the Istio Gateway PODs. Note that this load balancing algorithm is ``stateful'' in the sense that the load balancing result for the original connection does not change when the number of targets changes. That is, it is considered a ``stable algorithm''.
- The Istio Gateway POD also load balances HTTP/TCP traffic. The difference between the two protocols is that:
  - For HTTP, multiple requests from a single connection on the same downstream may be load balanced to different upstreams.
  - For TCP, multiple packets for a single connection on the same downstream are load balanced to the same upstream destination.



## Starting Testing

Chaos Testing is done by brute-force shutting down worker node B . As shown above, it can be inferred that both the `red` and `green` line connections are directly affected. The impact seen from the client is:

1. the request success rate is reduced by only 0.01%
2. TPS dropped by 1/2 and lasted for half an hour before recovering.
3. Avg Response Time (Average Response Time) is basically unchanged.

It is important to note that the various resources of a single Worker Node are not the performance bottleneck in this test. So what is the problem?

The client is a JMeter program, and by taking a closer look at the test reports it generates, I found that the `Avg Response Time` does not change much after the worker node is shut down. However, the Response Time for P99 and MAX becomes abnormally large. It can be seen that `Avg Response Time` hides a lot of things, and the test thread is probably blocked somewhere, which causes the TPS to drop.

After a lot of troubleshooting, I changed the timeout of JMeter on the `external client` to 6s, and the problem was solved. After the worker node shutdown, the TPS recovered quickly.



## Root Cause

The problem with the external client is solved. It's time to call it a day. However, as a person who loves to toss and turn, I would like to find out the reason for this. More importantly, I want to know if this situation is really a fast recovery, or if it's a hidden problem.

Before we start, let's talk about a concept:


### TCP half-open

> 📖 [TCP half-open](https://en.wikipedia.org/wiki/TCP_half-open)
>
> According to RFC 793, a TCP connection is said to be ``half-open'' when the host on one end of the TCP connection crashes, or when a socket is deleted without notification to the other end. If the half-open end is idle (i.e., no data/keepalive is sent), the connection may remain half-open for an infinite period of time.

After worker node B closes, from the perspective of an `external client`, as shown above, its TCP connection to worker node B may be in two states:



- The client kernel layer needs to send a packet to the other end because it is sending (or retransmitting) data, or has reached the keepalive time. Worker node A receives this packet, and since it is an illegitimate TCP, the likely scenario is:
  - The worker node A responds with a TCP RESET, and the client closes the connection after receiving it. client Blocked threads on the socket also return because the connection was closed, and continue to run and close the socket.
  - The packet dropped because the DNAT mapping table could not find the connection in question. client Block's thread on the socket continued to block. i.e., a ``TCP half-open'' occurred.

- The client connection does not have keepalive enabled, or the idle time does not reach the keepalive time, and the kernel layer does not have any data to send (or retransmit), the client thread Block in the socket read and wait, that is, `TCP half-open` occurs.

As you can see, for the client, in all probability, it will take some time to realize that a connection has failed. In the worst case, if you don't keepalive, you may never find out about a `TCP half-open`.


### keepalive

> From [TCP/IP Illustrated Volume 1].
>
> The keepalive probe is an empty (or 1-byte) `segment` with a sequence number that is 1 less than the largest `ACK` number seen so far from the `peer`. Because this sequence number has already been received by the `peer`, the `peer` receives this empty `segment` again with no side effect, but it does trigger a ` peer` to return an `ACK` to determine if `peer` is alive. Neither the `probe probe segment` nor its `ACK` contains any new data.
>
> `Probe probe segment` is not retransmitted by TCP if it is lost. [RFC1122] states that because of this fact, the failure of a single `keepalive` probe to receive an `ACK` should not be considered sufficient evidence that the peer is dead. Multiple spaced probes are required.

If the socket has `SO_KEEPALIVE` turned on, then `keepalive` is enabled.

Linux has the following global default configuration for TCP connections with `keepalive` enabled:

> https://www.kernel.org/doc/html/latest/admin-guide/sysctl/net.html

- tcp_keepalive_time - INTEGER

  How often TCP sends out keepalive messages when keepalive is enabled. Default: 2 hours.

- tcp_keepalive_probes - INTEGER

   How many keepalive probes TCP sends out, until it decides that the connection is broken. Default value: 9.

- tcp_keepalive_intvl - INTEGER

  How frequently the probes are send out. Multiplied by tcp_keepalive_probes it is time to kill not responding connection, after probes started. Default value: 75 sec i.e. connection will be aborted after ~11 minutes of retries.

Linux also provides configuration items that are specified independently for each socket:

> https://man7.org/linux/man-pages/man7/tcp.7.html

```
       TCP_KEEPCNT (since Linux 2.4)
              The maximum number of keepalive probes TCP should send
              before dropping the connection.  This option should not be
              used in code intended to be portable.

       TCP_KEEPIDLE (since Linux 2.4)
              The time (in seconds) the connection needs to remain idle
              before TCP starts sending keepalive probes, if the socket
              option SO_KEEPALIVE has been set on this socket.  This
              option should not be used in code intended to be portable.

       TCP_KEEPINTVL (since Linux 2.4)
              The time (in seconds) between individual keepalive probes.
              This option sh
```

You can calculate, by default, the fastest a connection can be shut down by keepalive:

```
TCP_KEEPIDLE + TCP_KEEPINTVL * (TCP_KEEPCNT-1) = 2*60*60 + 75*(9-1) = 7800 = 2 小时
```



### Retransmission timeout

> https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt

```
- tcp_retries2 - INTEGER

This value influences the timeout of an alive TCP connection, when RTO retransmissions remain unacknowledged. Given a value of N, a hypothetical TCP connection following exponential backoff with an initial RTO of TCP_RTO_MIN would retransmit N times before killing the connection at the (N+1)th RTO.The default value of 15 yields a hypothetical timeout of 924.6 seconds and is a lower bound for the effective timeout. TCP will effectively time out at the first RTO which exceeds the hypothetical timeout.RFC 1122 recommends at least 100 seconds for the timeout, which corresponds to a value of at least 8.
```

The above configuration item configures how many retransmissions the kernel has to yield before closing the connection in the retransmission state. The default is 15, which translates to 924s, about 15 minutes.

### Zero window timeout

When the ``opposite end'' announces that its window size is zero, this indicates that the TCP receive buffer on the opposite end is full and no more data can be received. It may be due to resource constraints on the other end and data processing is too slow, which eventually causes the TCP receive buffer to fill up.

Theoretically, after processing the data piled up in the receive window, the peer will use ACK to notify the window to open. However, for various reasons, sometimes this ACK is lost.

Therefore, the sender with unsent data needs to probe the window size periodically. The sender will select the first byte of data from the undelivered cache to send as a probe packet. The connection will be closed when the other party does not respond after a certain number of probes, or keeps responding with a window of 0. The default number of probes in Linux is 15. The configuration item is: `tcp_retries2`. Its probe retry mechanism is similar to TCP retransmission.

> Reference: https://blog.cloudflare.com/when-tcp-sockets-refuse-to-die/#:~:text=value%20is%20ignored.-,Zero%20window,-ESTAB%20is...%20forever

### Apply timeout settings at the socket level

#### TCP_USER_TIMEOUT

> [man tcp](https://man7.org/linux/man-pages/man7/tcp.7.html)

```
       TCP_USER_TIMEOUT (since Linux 2.6.37)
              This option takes an unsigned int as an argument.  When
              the value is greater than 0, it specifies the maximum
              amount of time in milliseconds that transmitted data may
              remain unacknowledged, or bufferred data may remain
              untransmitted (due to zero window size) before TCP will
              forcibly close the corresponding connection and return
              ETIMEDOUT to the application.  If the option value is
              specified as 0, TCP will use the system default.

              Increasing user timeouts allows a TCP connection to
              survive extended periods without end-to-end connectivity.
              Decreasing user timeouts allows applications to "fail
              fast", if so desired.  Otherwise, failure may take up to
              20 minutes with the current system defaults in a normal
              WAN environment.

              This option can be set during any state of a TCP
              connection, but is effective only during the synchronized
              states of a connection (ESTABLISHED, FIN-WAIT-1, FIN-
              WAIT-2, CLOSE-WAIT, CLOSING, and LAST-ACK).  Moreover,
              when used with the TCP keepalive (SO_KEEPALIVE) option,
              TCP_USER_TIMEOUT will override keepalive to determine when
              to close a connection due to keepalive failure.

              The option has no effect on when TCP retransmits a packet,
              nor when a keepalive probe is sent.

              This option, like many others, will be inherited by the
              socket returned by accept(2), if it was set on the
              listening socket.

              Further details on the user timeout feature can be found
              in RFC 793 and RFC 5482 ("TCP User Timeout Option").
```

I.e., specify that the kernel will not close the connection and return an error to the application until the sender does not get an acknowledgement (`ACK` is not received), or until the peer's receive window is 0 for a long period of time.

Note that `TCP_USER_TIMEOUT` affects the `TCP_KEEPCNT` configuration of keepalive:

> https://blog.cloudflare.com/when-tcp-sockets-refuse-to-die/
>
> With `TCP_USER_TIMEOUT` set, the `TCP_KEEPCNT` is totally ignored. If you want `TCP_KEEPCNT` to make sense, the only sensible `USER_TIMEOUT` value is slightly smaller than:
>
> ```
> TCP_USER_TIMEOUT < TCP_KEEPIDLE + TCP_KEEPINTVL * TCP_KEEPCNT
> ```

#### SO_RCVTIMEO / SO_SNDTIMEO

> https://man7.org/linux/man-pages/man7/socket.7.html

```
       SO_RCVTIMEO and SO_SNDTIMEO
              Specify the receiving or sending timeouts until reporting
              an error.  The argument is a struct timeval.  If an input
              or output function blocks for this period of time, and
              data has been sent or received, the return value of that
              function will be the amount of data transferred; if no
              data has been transferred and the timeout has been
              reached, then -1 is returned with errno set to EAGAIN or
              EWOULDBLOCK, or EINPROGRESS (for connect(2)) just as if
              the socket was specified to be nonblocking.  If the
              timeout is set to zero (the default), then the operation
              will never timeout.  Timeouts only have effect for system
              calls that perform socket I/O (e.g., read(2), recvmsg(2),
              send(2), sendmsg(2)); timeouts have no effect for
              select(2), poll(2), epoll_wait(2), and so on.
```

Note that in this case, our client is JMeter, a java implementation that uses the `socket.setSoTimeout` method to set the timeout. According to:

> https://stackoverflow.com/questions/12820874/what-is-the-functionality-of-setsotimeout-and-how-it-works

With the source code I've seen, the Linux implementation should have used the timeout parameter for select/poll as explained in the next section, rather than the socket Options above.

> https://github.com/openjdk/jdk/blob/4c54fa2274ab842dbecf72e201d5d5005eb38069/src/java.base/solaris/native/libnet/solaris_close.c#L96

Java JMeter actively closes the socket after catching the SocketTimeoutException and reconnects, so the dead socket problem is solved at the application level.

#### poll timeout

> https://man7.org/linux/man-pages/man2/poll.2.html

```c
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
```

### Roots summary

> Reference: https://blog.cloudflare.com/when-tcp-sockets-refuse-to-die/#:~:text=typical%20applications%20sending%20data%20to%20the%20Internet

To ensure that connections can detect timeouts relatively quickly in all states:

1. Enable `TCP keepalive` and configure it for a reasonable amount of time. This is necessary to keep some data flowing in the case of an idle connection.
2. set `TCP_USER_TIMEOUT` to `TCP_KEEPIDLE` + `TCP_KEEPINTVL` * `TCP_KEEPCNT`.
3. Use read/write timeout detection at the application layer and apply active connection closure after the timeout. (This is the case in this article)

Why do we need `TCP_USER_TIMEOUT` when we have `TCP keepalive`? The reason is that if a network partition occurs, a connection in the retransmission state will not trigger a keepalive detection. I have documented the principle in the following diagram:


![](./socket-options.assets/tcp-send-recv-state.drawio.svg)



## What's the point of being more serious?

> 🤔 ❓ Speaking of which, some students will ask, in the end, this time, you just adjusted an application layer read timeout on the line. Research and really so many other why?

At this point, let's go back to the "beginning" of the following figure to see if all the pitfalls have been solved:

! [](. /socket-options.assets/tcp-half-open-env-k8s-istio.drawio.svg)

Obviously, only the red line from `External Client` to `k8s worker node B` is resolved. The other red and green lines, not investigated. Are these `tcp half-opent` connections shut down quickly with `tcp keepalive`, `tcp retransmit timeout`, `Envoy layer timeout` mechanisms, or are they not shut down in a timely manner due to long term undetected problems, or even connection leaks?

## Keepalive check for idle connections

### When acting as an upstream

As you can see below, Istio gateway does not enable keepalive by default.

```bash
$ kubectl exec -it $ISTIO_GATEWAY_POD -- ss -oipn 'sport 15001 or sport 15001 or sport 8080 or sport 8443'                                                         
Netid               State                Recv-Q                Send-Q                               Local Address:Port                               Peer Address:Port                
tcp                 ESTAB                0                     0                                    192.222.46.71:8080                                10.111.10.101:51092                users:(("envoy",pid=45,fd=665))
         sack cubic wscale:11,11 rto:200 rtt:0.064/0.032 mss:8960 pmtu:9000 rcvmss:536 advmss:8960 cwnd:10 segs_in:2 send 11200000000bps lastsnd:31580 lastrcv:31580 lastack:31580 pacing_rate 22400000000bps delivered:1 rcv_space:62720 rcv_ssthresh:56576 minrtt:0.064
```

In this case, you can use EnvoyFilter with keepalive:

> Reference:
>
> https://support.f5.com/csp/article/K00026550
>
> https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/core/v3/socket_option.proto
>
> https://github.com/istio/istio/issues/28879
>
> https://istio-operation-bible.aeraki.net/docs/common-problem/tcp-keepalive/

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingress-gateway-socket-options
  namespace: istio-system
spec:
  configPatches:
  - applyTo: LISTENER
    match:
      context: GATEWAY
      listener:
        name: 0.0.0.0_8080
        portNumber: 8080
    patch:
      operation: MERGE
      value:
        socket_options:
        - description: enable keep-alive
          int_value: 1
          level: 1
          name: 9
          state: STATE_PREBIND
        - description: idle time before first keep-alive probe is sent
          int_value: 7
          level: 6
          name: 4
          state: STATE_PREBIND
        - description: keep-alive interval
          int_value: 5
          level: 6
          name: 5
          state: STATE_PREBIND
        - description: keep-alive probes count
          int_value: 2
          level: 6
          name: 6
          state: STATE_PREBIND
```

The istio-proxy sidecar can be set up in a similar way.


### When acting as a downstream (client)

> Reference: https://istio.io/latest/docs/reference/config/networking/destination-rule/#ConnectionPoolSettings-TCPSettings-TcpKeepalive

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: bookinfo-redis
spec:
  host: myredissrv.prod.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        connectTimeout: 30ms
        tcpKeepalive:
          time: 60s
          interval: 20s
          probes: 4
```



## TCP_USER_TIMEOUT

The story should be over at this point, but, it's not. Recall the two previous charts:

![](./socket-options.assets/tcp-half-open-env-k8s-istio.drawio.svg)

![](./socket-options.assets/tcp-send-recv-state.drawio.svg)

At this point, the retransmit timer is timed to retransmit at the TCP layer. There are two possibilities here:

1. Calico quickly realized the problem after worker node B lost power and updated the routing table for worker node A, removing the route to worker node B. 2.
2. The routes were not updated in time

The default retransmit timer takes 15 minutes to close the connection and notify the application. How to speed it up?

You can use `TCP_USER_TIMEOUT` mentioned above to speed up `half-open TCP` to find out the problem in the retransmit state :

> https://github.com/istio/istio/issues/33466
>
> https://github.com/istio/istio/issues/38476

```yaml
kind: EnvoyFilter
metadata:
  name: sampleoptions
  namespace: istio-system
spec:
  configPatches:
  - applyTo: CLUSTER
    match:
      context: SIDECAR_OUTBOUND
      cluster:
        name: "outbound|12345||foo.ns.svc.cluster.local"
    patch:
      operation: MERGE
      value:
        upstream_bind_config:
          source_address:
            address: "0.0.0.0"
            port_value: 0
            protocol: TCP
          socket_options:
          - name: 18 #TCP_USER_TIMEOUT
            int_value: 10000
            level: 6
```

The above accelerates the discovery of die upstream (server-side crash), for die downstream, it may be possible to use a similar approach, configured in listener.