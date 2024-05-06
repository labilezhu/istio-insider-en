# http connection manager

First of all, http connection manager(HCM) is a Network Filter from the Listener's point of view.

For scalability, Envoy's http connection manager uses the classic filter chain design pattern. This is similar to Listener Filter Chain:


:::{figure-md} Figure: http connection manager Design model
:class: full-width 
<img src="/ch2-envoy/arch/http/http-connection-manager/http-connection-manager.assets/http-connection-manager.drawio.svg" alt="Figure - http connection manager Design model">

*Figure: http connection manager Design model*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fhttp-connection-manager.drawio.svg)*


The filter flow of http request:

![](./http-connection-manager.assets/lor-http-decode.svg)
*source: [life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#http-filter-chain-processing)*

The filter flow of http response:

![](./http-connection-manager.assets/lor-http-encode.svg)
*source: [life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#http-filter-chain-processing)*



## http filter abstract object definition

HttpFilter is called `StreamFilter` or more precisely `Http::StreamFilterBase` in the source code. An `http connection manager` has an `Http::FilterManager` and a `FilterManager` has `list<StreamFilterBase*> filters_`.

:::{figure-md} Figure: http filter abstract object
:class: full-width
<img src="/ch2-envoy/arch/http/http-connection-manager/http-connection-manager.assets/http-filter-abstract.drawio.svg" alt="Figure - http filter abstract object">

*Figure: http filter abstract object*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fhttp-filter-abstract.drawio.svg)*

## http filter C++ class relationships

:::{figure-md} Figure: http filter C++ class relationship
:class: full-width
<img src="/ch2-envoy/arch/http/http-connection-manager/http-connection-manager.assets/http-filter-code-oop.drawio.svg" alt="Figure - http filter C++ class relationship">

*Figure: http filter C++ class relationships*
::.
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fhttp-filter-code-oop.drawio.svg)*

```{toctree}
hcm-event-process.md
```
