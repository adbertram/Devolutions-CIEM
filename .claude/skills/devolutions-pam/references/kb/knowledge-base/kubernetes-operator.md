# Kubernetes Operator

**Source URL:** https://docs.devolutions.net/pam/kb/knowledge-base/kubernetes-operator/

---

The Kubernetes Operator synchronize Devolutions Server credential entry entries as Kubernetes Secrets.
This operator uses the defined custom resource
DvlsSecret
which manages its own Kubernetes Secret and will keep itself up to date at a defined interval (every minute by default). The Docker image can be found
here
.
To learn more about the Kubernetes Operator, consult our
GitHub
.
This operator is a work in progress, expect breaking changes between releases.
Operator configuration
The following Environment variables can be used to configure the operator :
DEVO_OPERATOR_DVLS_BASEURI
(required) - Devolutions Server instance base URI
DEVO_OPERATOR_DVLS_APPID
(required) - Devolutions Server Application ID
DEVO_OPERATOR_DVLS_APPSECRET
(required) - Devolutions Server Application Secret
DEVO_OPERATOR_REQUEUE_DURATION
(optional) - Entry/Secret resync interval (default 60s). Valid time units are "ns", "us" (or "Âµs"), "ms", "s", "m", "h".
SSL_CERT_FILE
(optional) - Path to a custom CA certificate file for Devolutions Server servers with self-signed certificates. This is automatically set by the Helm chart when
instanceSecret.caCert
is provided.
A sample of the custom resource can be found
here
. The entry ID can be fetched by going in the entry properties,
Advanced -> Session ID
.
Devolutions Server configuration
We recommend creating an
Application ID
specifically to be used with the Operator that has
minimal access to a vault
that only contains the secrets to be synchronized.
Only
Credential Entry
entries are supported at the moment. The available entry data will depend on the
Credential Entry
type.
Kubernetes configuration
Since this operator uses Kubernetes Secrets, it is recommended that you follow
best practices
surrounding secrets, especially
encryption at rest
.
Getting started
Youâll need a Kubernetes cluster to run against. You can use
KIND
to get a local cluster for testing, or run against a remote cluster.
Note:
Your controller will automatically use the current context in your kubeconfig file (i.e. whatever cluster
kubectl cluster-info
shows).
Helm chart
A Helm Chart is available to simplify installation. Add the Devolutions Helm chart repository, create a
values.yaml
from
the default values
as a baseline, and update values as necessary.
Required configuration
The following values
must
be configured in your
values.yaml
:
controllerManager.manager.env.devoOperatorDvlsBaseuri
- Your Devolutions Server URL (e.g.,
https://dvls.example.com
).
controllerManager.manager.env.devoOperatorDvlsAppid
- Application ID from your Devolutions Server.
instanceSecret.secret
- Application Secret from your Devolutions Server .
Optional configuration
instanceSecret.caCert
- Custom CA certificate for self-signed Devolutions Server (see below)
controllerManager.manager.env.devoOperatorRequeueDuration
- How often to sync secrets (default:
60s
)
Basic Example configuration
Create a
values.yaml
file with your Devolutions Server configuration:
controllerManager:
manager:
env:
devoOperatorDvlsAppid:
"00000000-0000-0000-0000-000000000000"
devoOperatorDvlsBaseuri:
"https://dvls.example.com"
devoOperatorRequeueDuration:
"60s"
instanceSecret:
secret:
"your-app-secret-here"
Installation
helm
repo
add
devolutions-helm-charts
https://devolutions.github.io/helm-charts
helm
repo
update
helm
install
dvls-kubernetes-operator
devolutions-helm-charts/dvls-kubernetes-operator
--values
values.yaml
Using a Custom CA certificate
If your Devolutions Server uses a self-signed certificate (common in test/development environments), you need to provide the CA certificate so the operator can establish a trusted TLS connection.
When to use this:
Testing with self-signed certificates.
Internal CA certificates not in the system trust store.
Development/staging environments with custom PKI.
Configuration:
Add the CA certificate content to your
values.yaml
:
controllerManager:
manager:
env:
devoOperatorDvlsAppid:
"00000000-0000-0000-0000-000000000000"
devoOperatorDvlsBaseuri:
"https://dvls.example.com"
devoOperatorRequeueDuration:
"60s"
instanceSecret:
secret:
"your-app-secret"
# Add your CA certificate here (PEM format)
caCert:
|
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKZ...
    (your CA certificate content)
    ...
    -----END CERTIFICATE-----
Running on the cluster
Install Instances of Custom resources:
kubectl apply -f config/samples/
Build and push your image to the location specified by IMG:
make docker-build docker-push IMG=<some-registry>/dvls-kubernetes-operator:tag
Deploy the controller to the cluster with the image specified by IMG:
make deploy IMG=<some-registry>/dvls-kubernetes-operator:tag
Uninstall CRDs
To delete the CRDs from the cluster:
make undeploy
Contributing
How it works
This project aims to follow the Kubernetes
Operator pattern
.
It uses
Controllers
which provides a reconcile function responsible for synchronizing resources untile the desired state is reached on the cluster
Test it out
Install the CRDs into the cluster:
make install
Run your controller (this will run in the foreground, so switch to a new terminal if you want to leave it running):
make run
NOTE:
You can also run this in one step by running:
make install run
Modifying the API definitions
If you are editing the API definitions, generate the manifests such as CRs or CRDs using:
make manifests
NOTE:
Run
make --help
for more information on all potential
make
targets
More information can be found via the
Kubebuilder Documentation
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:58*