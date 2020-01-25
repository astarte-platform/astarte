# System Requirements

Astarte is a Native Kubernetes application, and as such Kubernetes is a hard requirement. It is possible to
run Astarte outside Kubernetes, although a number of features won't be available - these setups are outside
the scope of this document.

## Kubernetes Requirements

Astarte requires at least Kubernetes 1.12 - however, it currently targets Kubernetes 1.16+. It is advised
to consult Astarte Operator's compatibility matrix in the README to ensure a specific Kubernetes setup is
supported.

The Astarte Operator does not require any unstable feature gate in Kubernetes 1.16, and is actively tested
against KinD and major Managed Kubernetes installations on various Cloud Providers.

## Resource Requirements

Depending on the kind of setup, Astarte might require different resource configurations when it comes to
nodes. `astartectl` takes care of this with the `profiles` features, which inspects the Cluster and provides
a set of ready made configurations for the Cluster. Besides this, Astarte requires a minimum of 3 physical
nodes in case one is planning on a redundant setup.
