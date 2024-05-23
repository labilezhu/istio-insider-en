# Istio Overall Architecture

The overall architecture of Istio is not the focus of this book. I'm sure that those who are interested in reading this book have already learned about it.
The main purpose of this section is to review the overall architecture. I'm sure the reader is an Istio user, or even an experienced Istio user. But sometimes, when you get too deeply involved in something, it's easy to forget the whole picture.  

This is also a good place to explain the focus of the rest of the book. After all, I have limited energy and interest, so I'm only going to focus on some parts of Istio.


:::{figure-md} Istio's overall architecture.

<img src="index.assets/istio-arch.svg" alt="Istio overall architecture">

Figure : Istio architecture  
From: https://istio.io/latest/docs/ops/deployment/architecture/  
:::


- Proxy 
  This should not need much introduction. The most important component of the data plane. It is also the focus of this book. Because I'm more interested in the data plane than the control plane. Note that the Proxy here is the `istio-proxy` container, which, as you know, has at least two components:
  - `pilot-agent` which belongs to the control plane. 
  - The `Envoy Proxy`, which belongs to the data plane.This is the first focus of the book.
- istiod  
  Nickname: control plane brain, strategic-level command center, authoritative certification authority.


Okay, that's enough of the high level chart for now. After that, we'll start disassembling these components, and analyzing their interactions. Let's go!
