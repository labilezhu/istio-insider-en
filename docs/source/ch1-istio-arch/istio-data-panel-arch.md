# Istio Data Plane Architecture

If you want to understand the core mechanics of a system, you should first look at the main data flows of the system, and Istio is no exception. Below we look at the deployment architecture of the Istio data plane.

```{note}
A description of the lab environment for this section can be found at: {ref}`appendix-lab-env/appendix-lab-env-base:Simple layered lab environment`
```

:::{figure-md} Figure: Istio Data Plane Architecture

<img src="istio-data-panel-arch.assets/istio-data-panel-arch.drawio.svg" alt="Inbound and Outbound concepts">

*Figure: Istio Data Plane Architecture*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fistio-data-panel-arch.drawio.svg)*

{ref}`Figure: Istio Data Plane Architecture` is the data-plane relationship diagram for the call chain: `client ➔ fortio-server:8080 ➔ fortio-server-l2:8080`. The numbers in the diagram are port numbers. 


## netfilter/iptables

{ref}`Figure: Istio Data Plane Architecture` The `kernel netfilter` in the diagram is some interception and forwarding rules for TCP connections, which can be inspected like this:

```bash
export WORKNODE=xzy # The worker node on which the POD of interest is running.
ssh $WORKNODE
export POD=fortio-server # name of POD of interest
ENVOY_PIDS=$(pgrep envoy)
while IFS= read -r ENVOY_PID; do
    if [ $(sudo nsenter -u -t $ENVOY_PID hostname)=="$POD" ]; then
        export TARGET_ENVOY_PID=$ENVOY_PID
    export TARGET_ENVOY_PID=$ENVOY_PID
done <<< "$ENVOY_PIDS"

sudo nsenter -n -t $TARGET_ENVOY_PID iptables-save
```

Output:

```
*nat
:PREROUTING ACCEPT [1112:66720]
:INPUT ACCEPT [1112:66720]
:OUTPUT ACCEPT [152:13538]
:postprocessing accpt [152:13538] :istio_inbounds
:istio_inbound - [0:0] :istio_in_routing - [0:0
:ISTIO_IN_REDIRECT - [0:0] :ISTIO_OUTPUT - [0:0
:ISTIO_OUTPUT - [0:0] :ISTIO_REDIRECT - [0:0] :ISTIO_REDIRECT - [0:0
:ISTIO_REDIRECT - [0:0] :ISTIO_REDIRECT - [0:0]
-A PREROUTING -p tcp -j ISTIO_INBOUND
-A OUTPUT -p tcp -j ISTIO_OUTPUT
-A ISTIO_INBOUND -p tcp -m tcp --dport 15008 -j RETURN
-A ISTIO_INBOUND -p tcp -m tcp --dport 22 -j RETURN
-A ISTIO_INBOUND -p tcp -m tcp --dport 15090 -j RETURN
-A ISTIO_INBOUND -p tcp -m tcp --dport 15021 -j RETURN
-A ISTIO_INBOUND -p tcp -m tcp --dport 15020 -j RETURN
-A ISTIO_INBOUND -p tcp -j ISTIO_IN_REDIRECT
-A ISTIO_IN_REDIRECT -p tcp -j REDIRECT --to-ports 15006
-A ISTIO_OUTPUT -s 127.0.0.6/32 -o lo -j RETURN
-A ISTIO_OUTPUT ! -d 127.0.0.1/32 -o lo -m owner --uid-owner 1337 -j ISTIO_IN_REDIRECT
-A ISTIO_OUTPUT -o lo -m owner ! --uid-owner 1337 -j RETURN
-A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN
-A ISTIO_OUTPUT ! -d 127.0.0.1/32 -o lo -m owner --gid-owner 1337 -j ISTIO_IN_REDIRECT
-A ISTIO_OUTPUT -o lo -m owner ! --gid-owner 1337 -j RETURN
-A ISTIO_OUTPUT -m owner --gid-owner 1337 -j RETURN
-A ISTIO_OUTPUT -d 127.0.0.1/32 -j RETURN
-A ISTIO_OUTPUT -j ISTIO_REDIRECT
-A ISTIO_REDIRECT -p tcp -j REDIRECT --to-ports 15001
COMMIT

```