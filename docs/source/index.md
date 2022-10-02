![Book Cover](./book-cover-mockup.jpg)

# Preface


```{attention}
This is a work-in-progress book, and it's only at the draft stage. The title of the book is "Istio & Envoy Insider", and the English name is "Istio & Envoy Insider".
````

## Book overview

### What this book is not

This book is not a manual. Not from the user's point of view, teaching how to learn Istio in simple terms. It won't preach how powerful Istio is, let alone teach how to use Istio. There are already too many excellent books, articles, and documents on the Internet.

> 🤷 : [Yet, another](https://en.wikipedia.org/wiki/Yet_another) Istio User Guide?
> 🙅 : No!



### What is this book

In this book, I try to think systematically as much as possible from the perspective of design and implementation:
- Why is Istio the way it is?
- The truth behind those magic configs: Linux + Envoy
  - How traffic is intercepted to Envoy using Linux's netfilter technology
  - How istiod programmed Envoy to implement `service mesh` traffic policy
- What Istio might look like in the future


What the book says is just my thinking and recording after researching and using Istio for a period of time. I just checked some Istio/Envoy related functions and performance issues, browsed and debugged some Istio/Envoy codes.

In the process of researching Istio. There is a lot of valuable information on the Internet. However, either it is mainly based on the user, and the implementation mechanism is not mentioned; or the mechanism is said, and it is well said, but the content is less systematic and coherent.

### Reader object
This book mainly talks about the design and implementation mechanism of Istio/Envoy. It is assumed that the reader already has some experience with Istio. and are interested in further research on its realization mechanism

### Book access address
- [https://istio-insider.mygraphql.com](https://istio-insider.mygraphql.com)
- [https://istio-insider.readthedocs.io](https://istio-insider.readthedocs.io)
- [https://istio-insider.rtfd.io](https://istio-insider.rtfd.io)


### About the author
My name is Mark Zhu, a middle-aged programmer with little hair. I am not an Istio expert, nor an Istio Committer. Not even the employees of big Internet companies.

Why do you still learn to write books with limited level? Because of this sentence:
> You don't need to be great to start, but you need to start to be great.

Blog: [https://blog.mygraphql.com/](https://blog.mygraphql.com/)
In order to facilitate readers to follow the updates of the Blog and this book, a synchronized `WeChat Official Account` has been opened:

:::{figure-md} WeChat Official Account: Mark's Meditations on Cloud and BPF

<img src="_static/my-wechat-blog-qr.png" alt="my-wechat-blog-qr.png">

*WeChat Official Account: Mark's Cloud and BPF Meditations*
:::




### Involved in the preparation
If you are also interested in writing this book, please contact me. The starting point of this book is not to brush a resume, nor does it have this ability. Moreover, such non-`short and fast` and `TL;DR` books are destined to be a niche product.


### Dedication 💞
First, to my dear parents, for showing me how to live a happy
and productive life. To my dear wife and our amazing kid – thanks for all your love and patience.


### Copyleft Statement
Whether it is text or pictures, if reproduced or modified, please indicate the original source.

### Feedback
Since it claims to be an interactive book, reader feedback is of course very important. If you find an error in the book, or have a better suggestion, feel free to file an Issue here:
[https://github.com/labilezhu/istio-insider/issues](https://github.com/labilezhu/istio-insider/issues)


## Table of contents


```{toctree}
:caption: directory
:maxdepth: 5
:includehidden:

ch0/index
ch1-istio-arch/index
ch2-envoy/index
ch3-control-panel/index
ch4-istio-ctrl-envoy/index
````

## Appendix

```{toctree}
:caption: Appendix
:maxdepth: 5
:includehidden:

appendix-lab-env/index.md
````