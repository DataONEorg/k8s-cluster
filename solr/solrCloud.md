## Creating a SolrCloud

`kubectl apply -f example.yaml` below

```
apiVersion: solr.apache.org/v1beta1
kind: SolrCloud
metadata:
  name: example
spec:
  replicas: 4
  solrImage:
    tag: 9.8.1
```

To delete:

`kubectl delete solrcloud example`

## Installing the Operator

The operator is installed into the `solr-system` namespace, also created below:

```
# add repo
helm repo add apache-solr https://solr.apache.org/charts
helm repo update

# create and install chart
kubectl create namespace solr-system
kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.9.1/all-with-dependencies.yaml -n solr-system
helm install solr-operator apache-solr/solr-operator --version 0.9.1 -n solr-system
```