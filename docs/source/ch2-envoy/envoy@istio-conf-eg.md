# Envoy Configuration Example under Istio

Most books and documents describe a software architecture in terms of concepts, high-level design, fundamentals, and abstraction processes in a hierarchical, top-down fashion. This approach is very collegiate and a very solid choice. However, this section does not adopt this approach. This section starts with an example of a site analysis in a specific scenario. Specifically and as a whole, it first gives the reader a perceptual understanding of the design. Then go on to analyze why it is "configured" the way it is, the abstract concepts and basic principles behind it. In this way, it can keep the interest of those who learn, and is more in line with the natural human, abstract learning habit of distilling the abstract from the concrete. After all, I'm a person who has read the teacher training program, although even a "teaching certificate" did not get.

To understand the Istio data surface fundamentals, you first need to look at the configuration of the sidecar proxy - Envoy. This section uses an example to see what "code" istiod has written to control this "programmable proxy" - Envoy.

## Experimental Environment

A description of the experimental environment for this section can be found in: {ref}`appendix-lab-env/appendix-lab-env-base:Simple layered lab environment`.  


Architecture diagram:
:::{figure-md} Figure:Envoy configuration in Istio - Deployment

<img src="/ch1-istio-arch/istio-data-panel-arch.assets/istio-data-panel-arch.drawio.svg" alt="Inbound and Outbound concepts">

*Figure:Envoy Configuration in Istio - Deployment*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fistio-data-panel-arch.drawio.svg)*



First, look at the Envoy configuration:

```bash
kubectl exec fortio-server -c istio-proxy -- \
curl 'localhost:15000/config_dump?include_eds' | \
yq eval -P > envoy@istio-conf-eg-inbound.envoy_conf.yaml
```

```{note}
Download here {download}`envoy@istio-conf-eg-inbound.envoy_conf.yaml </ch2-envoy/envoy@istio-conf-eg.assets/envoy@istio-conf-eg-inbound.envoy_conf.yaml>` .
```

Without go through the description of the configuration file for now, let's just look at the analysis process, then, in the end, will return to this configuration.

## Inbound Data Flow "Inference"

Analyzing the Envoy configuration obtained above, you can "infer" the following Inbound data flow diagram:

:::{figure-md} Figure: Example of Envoy Inbound Configuration in Istio
:class: full-width
<img src="envoy@istio-conf-eg.assets/envoy@istio-conf-eg-inbound.drawio.svg" alt="Figure - Example of Envoy Inbound Configuration in Istio">

*Drawing: Example of Envoy Inbound Configuration in Istio*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy@istio-conf-eg-inbound.drawio.svg)*


Programmers who like to take things seriously have a natural uneasiness about "inferring" things. So, let's try to debug it and verify the reliability of the above diagram.


### Examining data flow with logs


1. Before you begin, take a look at the environment details:

```bash
labile@labile-T30 ➜ labile $ k get pod netshoot -owide
NAME       READY   STATUS    RESTARTS   AGE   IP               NODE        NOMINATED NODE   READINESS GATES
netshoot   2/2     Running   11         8d    172.21.206.228   worknode5   <none>           <none>


labile@labile-T30 ➜ labile $ k get pod fortio-server -owide
NAME            READY   STATUS    RESTARTS   AGE   IP               NODE        NOMINATED NODE   READINESS GATES
fortio-server   2/2     Running   11         8d    172.21.206.230   worknode5   <none>           <none>


labile@labile-T30 ➜ labile $ k get svc fortio-server      
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                                        AGE
fortio-server   NodePort   10.96.215.136   <none>        8080:32463/TCP,8070:32265/TCP,8079:30167/TCP   8d


labile@labile-T30 ➜ labile $ k get endpoints fortio-server 
NAME            ENDPOINTS                                                     AGE
fortio-server   172.21.206.230:8079,172.21.206.230:8070,172.21.206.230:8080   8d

```



2. Open a dedicated `Monitor Log Terminal Window':

```bash
k logs -f fortio-server -c istio-proxy
```

3. Look at the connections from the client(netshoot) to the fortio-server. No connection is found, i.e. the connection pool to fortio-server is not initialized.

```
$ k exec -it netshoot -- ss -tr

State Recv-Q Send-Q Local Address:Port                           Peer Address:Port Process
ESTAB 0      0          localhost:52012                             localhost:15020       
ESTAB 0      0          localhost:51978                             localhost:15020       
ESTAB 0      0           netshoot:53522 istiod.istio-system.svc.cluster.local:15012       
ESTAB 0      0           netshoot:42974 istiod.istio-system.svc.cluster.local:15012       
ESTAB 0      0          localhost:15020                             localhost:52012       
ESTAB 0      0          localhost:15020                             localhost:51978       
```

Explain the above command. `-t` is to look only at tcp connections. `-r` is to try to reverse the interpretation of the ip address back to the domain name.

````{tip}
If you find a connection already in your environment, force it to disconnect. This is because you will have to analyze the logs of the new connection being made later. Here's a secret trick for the `ss` command to force a connection to be disconnected:
```bash
k exec -it netshoot -- ss -K 'dst 172-21-206-230.fortio-server.mark.svc.cluster.local'
```
where `dst 172-21-206-230.fortio-server.mark.svc.cluster.local` is a filter condition that specifies the connection to perform the disconnect. The command means to disconnect the connection whose `pair target address` is `172-21-206-230.fortio-server.mark.svc.cluster.local`. `172-21-206-230.fortio-server.mark.svc.cluster.local` is the domain name that k8s automatically gives to this fortio-server POD.
````


3. Modify the log level:
```bash

k exec fortio-server -c istio-proxy -- curl -XPOST http://localhost:15000/logging
k exec fortio-server -c istio-proxy -- curl -XPOST curl -XPOST 'http://localhost:15000/logging?level=debug'
```



4. Initiate the request within the k8s cluster:
```bash
sleep 5 && k exec -it netshoot -- curl -v http://fortio-server:8080/
```

5. inspect connections
```bash
$ k exec -it netshoot -- ss -trn | grep fortio

State  Recv-Q  Send-Q     Local Address:Port                                             Peer Address:Port   Process  
...
ESTAB  0       0               netshoot:52352     172-21-206-230.fortio-server.mark.svc.cluster.local:8080            
...
```

6. view logs
At this point, you should be able to see the logs in the `Monitor Log Terminal Window` that you opened earlier:

```
envoy filter	original_dst: new connection accepted
envoy filter	tls inspector: new connection accepted
envoy filter	tls:onServerName(), requestedServerName: outbound_.8080_._.fortio-server.mark.svc.cluster.local
envoy conn_handler	[C12990] new connection from 172.21.206.228:52352

envoy http	[C12990] new stream
envoy http	[C12990][S11192089021443921902] request headers complete (end_stream=true):
':authority', 'fortio-server:8080'
':path', '/'
':method', 'GET'
'user-agent', 'curl/7.83.1'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '437a5a3e-f057-4079-a959-dad3d7dcf6a6'
'x-envoy-decorator-operation', 'fortio-server.mark.svc.cluster.local:8080/*'
'x-envoy-peer-metadata', 'ChwKDkFQUF9DT05UQUlORVJTEgoaCG5ldHNob290ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwogCgxJTlNUQU5DRV9JUFMSEBoOMTcyLjIxLjIwNi4yMjgKGQoNSVNUSU9fVkVSU0lPThIIGgYxLjE0LjMKlAEKBkxBQkVMUxKJASqGAQokChlzZWN1cml0eS5pc3Rpby5pby90bHNNb2RlEgcaBWlzdGlvCi0KH3NlcnZpY2UuaXN0aW8uaW8vY2Fub25pY2FsLW5hbWUSChoIbmV0c2hvb3QKLwojc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtcmV2aXNpb24SCBoGbGF0ZXN0ChoKB01FU0hfSUQSDxoNY2x1c3Rlci5sb2NhbAoSCgROQU1FEgoaCG5ldHNob290ChMKCU5BTUVTUEFDRRIGGgRtYXJrCj0KBU9XTkVSEjQaMmt1YmVybmV0ZXM6Ly9hcGlzL3YxL25hbWVzcGFjZXMvbWFyay9wb2RzL25ldHNob290ChcKEVBMQVRGT1JNX01FVEFEQVRBEgIqAAobCg1XT1JLTE9BRF9OQU1FEgoaCG5ldHNob290'
'x-envoy-peer-metadata-id', 'sidecar~172.21.206.228~netshoot.mark~mark.svc.cluster.local'

'x-envoy-attempt-count', '1'
'x-b3-traceid', '03824b6065cd13e0559df95ebf18def7'
'x-b3-spanid', '559df95ebf18def7'
'x-b3-sampled', '0'


envoy http	[C12990][S11192089021443921902] request end stream
envoy connection	[C12990] current connecting state: false
envoy router	[C12990][S11192089021443921902] cluster 'inbound|8080||' match for URL '/'
envoy upstream	transport socket match, socket default selected for host with address 172.21.206.230:8080
envoy upstream	Created host 172.21.206.230:8080.
envoy upstream	addHost() adding 172.21.206.230:8080
envoy upstream	membership update for TLS cluster inbound|8080|| added 1 removed 0
envoy upstream	re-creating local LB for TLS cluster inbound|8080||
envoy upstream	membership update for TLS cluster inbound|8080|| added 1 removed 0
envoy upstream	re-creating local LB for TLS cluster inbound|8080||
envoy router	[C12990][S11192089021443921902] router decoding headers:
':authority', 'fortio-server:8080'
':path', '/'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/7.83.1'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '437a5a3e-f057-4079-a959-dad3d7dcf6a6'

'x-envoy-attempt-count', '1'
'x-b3-traceid', '03824b6065cd13e0559df95ebf18def7'
'x-b3-spanid', '559df95ebf18def7'
'x-b3-sampled', '0'
'x-forwarded-client-cert', 'By=spiffe://cluster.local/ns/mark/sa/default;Hash=a3c273eef68529003f564ff48b906ea61630a25217edbc18b57495701d089904;Subject="";URI=spiffe://cluster.local/ns/mark/sa/default'

envoy pool	queueing stream due to no available connections
envoy pool	trying to create new connection
envoy pool	creating a new connection
envoy connection	[C12991] current connecting state: true
envoy client	[C12991] connecting
envoy connection	[C12991] connecting to 172.21.206.230:8080
envoy connection	[C12991] connection in progress
envoy upstream	membership update for TLS cluster inbound|8080|| added 1 removed 0
envoy upstream	re-creating local LB for TLS cluster inbound|8080||
envoy connection	[C12991] connected
envoy client	[C12991] connected
envoy pool	[C12991] attaching to next stream
envoy pool	[C12991] creating stream
envoy router	[C12990][S11192089021443921902] pool ready
envoy client	[C12991] response complete
envoy router	[C12990][S11192089021443921902] upstream headers complete: end_stream=true
envoy http	[C12990][S11192089021443921902] encoding headers via codec (end_stream=true):
':status', '200'
'date', 'Sun, 28 Aug 2022 13:46:17 GMT'
'content-length', '0'
'x-envoy-upstream-service-time', '2'
'x-envoy-peer-metadata', 'ChwKDkFQUF9DT05UQUlORVJTEgoaCG1haW4tYXBwChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwogCgxJTlNUQU5DRV9JUFMSEBoOMTcyLjIxLjIwNi4yMzAKGQoNSVNUSU9fVkVSU0lPThIIGgYxLjE0LjMK3AEKBkxBQkVMUxLRASrOAQoWCgNhcHASDxoNZm9ydGlvLXNlcnZlcgopChZhcHAua3ViZXJuZXRlcy5pby9uYW1lEg8aDWZvcnRpby1zZXJ2ZXIKJAoZc2VjdXJpdHkuaXN0aW8uaW8vdGxzTW9kZRIHGgVpc3RpbwoyCh9zZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1uYW1lEg8aDWZvcnRpby1zZXJ2ZXIKLwojc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtcmV2aXNpb24SCBoGbGF0ZXN0ChoKB01FU0hfSUQSDxoNY2x1c3Rlci5sb2NhbAoXCgROQU1FEg8aDWZvcnRpby1zZXJ2ZXIKEwoJTkFNRVNQQUNFEgYaBG1hcmsKQgoFT1dORVISORo3a3ViZXJuZXRlczovL2FwaXMvdjEvbmFtZXNwYWNlcy9tYXJrL3BvZHMvZm9ydGlvLXNlcnZlcgoXChFQTEFURk9STV9NRVRBREFUQRICKgAKIAoNV09SS0xPQURfTkFNRRIPGg1mb3J0aW8tc2VydmVy'
'x-envoy-peer-metadata-id', 'sidecar~172.21.206.230~fortio-server.mark~mark.svc.cluster.local'
'server', 'istio-envoy'

envoy wasm	wasm log stats_inbound stats_inbound: [extensions/stats/plugin.cc:645]::report() metricKey cache hit , stat=12
envoy wasm	wasm log stats_inbound stats_inbound: [extensions/stats/plugin.cc:645]::report() metricKey cache hit , stat=6
envoy wasm	wasm log stats_inbound stats_inbound: [extensions/stats/plugin.cc:645]::report() metricKey cache hit , stat=10
envoy wasm	wasm log stats_inbound stats_inbound: [extensions/stats/plugin.cc:645]::report() metricKey cache hit , stat=14
envoy pool	[C12991] response complete
envoy pool	[C12991] destroying stream: 0 remaining
```

The following figure illustrates logging related components with source code links:

:::{figure-md} Figure: Envoy Inbound components and logging in Istio
:class: full-width
<img src="envoy@istio-conf-eg.assets/log-envoy@istio-conf-eg-inbound.drawio.svg" alt="Diagram - Envoy Inbound component and logging in Istio">

*Diagram: Envoy Inbound component in Istio with logs*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Flog-envoy@istio-conf-eg-inbound.drawio.svg)*


## Outbound data stream "extrapolation"

Analyzing the Envoy configuration obtained above, the following Outbound data flow diagram can be "extrapolated":

:::{figure-md} Figure: Example of Envoy Outbound configuration in Istio.
:class: full-width
<img src="envoy@istio-conf-eg.assets/envoy@istio-conf-eg-outbound.drawio.svg" alt="Diagram - Envoy Outbound configuration example in Istio">

*Diagram: Envoy Outbound Configuration Example from Istio*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy@istio-conf-eg-outbound.drawio.svg)*



## Checking the stream with bpftrace

See my Blog: [Reverse Engineering and Cloud Native Site Analysis Part3 -- eBPF Trace Istio/Envoy Event Driven Model, Connection Establishment, TLS Handshake and filter_chain Selection (Chinese)](https://blog.mygraphql.com/zh/posts/low-tec/trace/trace-istio/trace-istio-part3/)
