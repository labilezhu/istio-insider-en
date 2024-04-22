# Lab Environment

Here is a list of the implementation environments used in this book and the related important configurations.

- Istio: 1.14 , Envoy version: 1.22 patch 3
- Kubernetes: 1.20  
- OS: Ubuntu 22.04.1 LTS
- shell: Oh My ZSH


shell environment configuration:
```bash
alias k=kubectl
```

## Basic environment installation


### Default namespace

```yaml
cat <<"EOF" | kubectl apply -f -

apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: mark
  
EOF
```


Or, Create a new context with namespace defined:
```bash
kubectl config set-context mark --user=kubernetes-admin --namespace=mark --cluster=kubernetes
kubectl config use-context mark
```

### Install istio

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.14.3/bin

./istioctl x precheck

./istioctl x uninstall --purge
./istioctl install

export ISTIO_HOME=$HOME/istio/istio-1.14.3
export PATH=$ISTIO_HOME/bin:$PATH
```

## Install tools


### netshoot
```yaml

cat <<"EOF" | kubectl -n mark apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: netshoot
  labels:
    app: netshoot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: netshoot
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"    
      labels:
        app: netshoot
    spec:
      containers:
      - name: netshoot
        image: docker.io/nicolaka/netshoot:latest
        command: ["/bin/sleep"]
        args: ["100d"]    
        ports:
        - containerPort: 9999
          name: tcp
          protocol: TCP
        - containerPort: 80
          name: http-80
          protocol: TCP
        securityContext:
            privileged: true
EOF

```


### httpbin

> Ref. https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/

```yaml

cat <<"EOF" | kubectl -n mark apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
    service: httpbin
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: httpbin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      serviceAccountName: httpbin
      imagePullSecrets:
      - name: docker-registry-key
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        ports:
        - containerPort: 8080
EOF


```

## Setup shell

### istio gateway & node port


```bash
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
```


## List of lab environment

```{toctree}
appendix-lab-env-base.md
```