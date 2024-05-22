# Upstream

Envoy 的 Upstream 功能，由  `Cluster Manager` / `Load Balancer` / `Connection Pool`  三大模块去实现。这几个模块与 `Network Filter` 之间协作，完成了面向 Upstream 的流量调整与转发功能。

```{toctree}
:hidden:
connection-pooling/connection-pooling.md
```