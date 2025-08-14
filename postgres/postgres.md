# Postgres Operator

We have installed the Postgres Operator from [CloudNativePG](https://cloudnative-pg.io/) to serve our persistent database needs.

## Installation of the operator via default yaml

First attempt to install the operator used:

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.26/releases/cnpg-1.26.1.yaml
```

Got a timeout error:

```
namespace/cnpg-system serverside-applied
customresourcedefinition.apiextensions.k8s.io/backups.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/clusterimagecatalogs.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/clusters.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/databases.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/imagecatalogs.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/publications.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/scheduledbackups.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/subscriptions.postgresql.cnpg.io serverside-applied
serviceaccount/cnpg-manager serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-database-editor-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-database-viewer-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-manager serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-publication-editor-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-publication-viewer-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-subscription-editor-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-subscription-viewer-role serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/cnpg-manager-rolebinding serverside-applied
configmap/cnpg-default-monitoring serverside-applied
service/cnpg-webhook-service serverside-applied
deployment.apps/cnpg-controller-manager serverside-applied
mutatingwebhookconfiguration.admissionregistration.k8s.io/cnpg-mutating-webhook-configuration serverside-applied
validatingwebhookconfiguration.admissionregistration.k8s.io/cnpg-validating-webhook-configuration serverside-applied
Error from server (Timeout): Timeout: request did not complete within requested timeout - context deadline exceeded
```


Here's what was installed and it's state:

```
❯ k8gn cnpg-system
NAME                                DATA   AGE
configmap/cnpg-default-monitoring   1      35m
configmap/kube-root-ca.crt          1      36m
NAME                             ENDPOINTS   AGE
endpoints/cnpg-webhook-service               35m
LAST SEEN   TYPE      REASON              OBJECT                                          MESSAGE
35m         Normal    Scheduled           pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully assigned cnpg-system/cnpg-controller-manager-74d454fcb7-9mwvj to k8s-dev-node-3
34m         Normal    Pulling             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Pulling image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1"
35m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 13.197323183s (13.197364585s including waiting)
34m         Normal    Created             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Created container manager
34m         Normal    Started             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Started container manager
34m         Warning   Unhealthy           pod/cnpg-controller-manager-74d454fcb7-9mwvj    Startup probe failed: Get "https://192.168.73.215:9443/readyz": dial tcp 192.168.73.215:9443: connect: connection refused
35m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 651.532155ms (651.567229ms including waiting)
40s         Warning   BackOff             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Back-off restarting failed container manager in pod cnpg-controller-manager-74d454fcb7-9mwvj_cnpg-system(022815d4-782a-4520-9abd-e5c81a125594)
34m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 706.530068ms (706.578491ms including waiting)
34m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 681.045257ms (681.092791ms including waiting)
35m         Normal    SuccessfulCreate    replicaset/cnpg-controller-manager-74d454fcb7   Created pod: cnpg-controller-manager-74d454fcb7-9mwvj
35m         Normal    ScalingReplicaSet   deployment/cnpg-controller-manager              Scaled up replica set cnpg-controller-manager-74d454fcb7 to 1
NAME                                           READY   STATUS             RESTARTS         AGE
pod/cnpg-controller-manager-74d454fcb7-9mwvj   0/1     CrashLoopBackOff   11 (3m17s ago)   35m
NAME                       TYPE                DATA   AGE
secret/cnpg-ca-secret      Opaque              2      35m
secret/cnpg-webhook-cert   kubernetes.io/tls   2      35m
NAME                          SECRETS   AGE
serviceaccount/cnpg-manager   0         35m
serviceaccount/default        0         37m
NAME                           TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/cnpg-webhook-service   ClusterIP   10.98.88.14   <none>        443/TCP   35m
NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cnpg-controller-manager   0/1     1            0           35m
NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/cnpg-controller-manager-74d454fcb7   1         1         0       35m
NAME                                                        ADDRESSTYPE   PORTS   ENDPOINTS        AGE
endpointslice.discovery.k8s.io/cnpg-webhook-service-pjdjs   IPv4          9443    192.168.73.215   36m
LAST SEEN   TYPE      REASON              OBJECT                                          MESSAGE
36m         Normal    Scheduled           pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully assigned cnpg-system/cnpg-controller-manager-74d454fcb7-9mwvj to k8s-dev-node-3
34m         Normal    Pulling             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Pulling image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1"
36m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 13.197323183s (13.197364585s including waiting)
35m         Normal    Created             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Created container manager
35m         Normal    Started             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Started container manager
35m         Warning   Unhealthy           pod/cnpg-controller-manager-74d454fcb7-9mwvj    Startup probe failed: Get "https://192.168.73.215:9443/readyz": dial tcp 192.168.73.215:9443: connect: connection refused
35m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 651.532155ms (651.567229ms including waiting)
73s         Warning   BackOff             pod/cnpg-controller-manager-74d454fcb7-9mwvj    Back-off restarting failed container manager in pod cnpg-controller-manager-74d454fcb7-9mwvj_cnpg-system(022815d4-782a-4520-9abd-e5c81a125594)
35m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 706.530068ms (706.578491ms including waiting)
34m         Normal    Pulled              pod/cnpg-controller-manager-74d454fcb7-9mwvj    Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.26.1" in 681.045257ms (681.092791ms including waiting)
36m         Normal    SuccessfulCreate    replicaset/cnpg-controller-manager-74d454fcb7   Created pod: cnpg-controller-manager-74d454fcb7-9mwvj
36m         Normal    ScalingReplicaSet   deployment/cnpg-controller-manager              Scaled up replica set cnpg-controller-manager-74d454fcb7 to 1
```

And note the main failure seems to be in `pod/cnpg-controller-manager-74d454fcb7-9mwvj`, which describe shows with the following error:

```
  Warning  Unhealthy  39m (x3 over 40m)    kubelet            Startup probe failed: Get "https://192.168.73.215:9443/readyz": dial tcp 192.168.73.215:9443: connect: connection refused
```

The logs for that pod indicate that it can't create a `Pooler` resource:

```
{"level":"error","ts":"2025-08-13T00:44:51.368571018Z","logger":"setup","msg":"unable to create controller","controller":"Cluster","error":"no matches for kind \"Pooler\" in v
ersion \"postgresql.cnpg.io/v1\"","stacktrace":"github.com/cloudnative-pg/machinery/pkg/log.(*logger).Error\n\tpkg/mod/github.com/cloudnative-pg/machinery@v0.3.0/pkg/log/log.g
o:125\ngithub.com/cloudnative-pg/cloudnative-pg/internal/cmd/manager/controller.RunController\n\tinternal/cmd/manager/controller/controller.go:231\ngithub.com/cloudnative-pg/c
loudnative-pg/internal/cmd/manager/controller.NewCmd.func1\n\tinternal/cmd/manager/controller/cmd.go:46\ngithub.com/spf13/cobra.(*Command).execute\n\tpkg/mod/github.com/spf13/
cobra@v1.9.1/command.go:1015\ngithub.com/spf13/cobra.(*Command).ExecuteC\n\tpkg/mod/github.com/spf13/cobra@v1.9.1/command.go:1148\ngithub.com/spf13/cobra.(*Command).Execute\n\
tpkg/mod/github.com/spf13/cobra@v1.9.1/command.go:1071\nmain.main\n\tcmd/manager/main.go:71\nruntime.main\n\t/opt/hostedtoolcache/go/1.24.5/x64/src/runtime/proc.go:283"}
```

**Deleted everything from the `cnpg-system` namespace to start again.**

Alternatives include using the cnpg plugin for kubectl or the helm chart (which seems to be in development).

## Install using `kubectl cnpg`

Try generating custom manifests, and then apply them:

```
kubectl cnpg install generate --help
kubectl cnpg install generate > cnpg-operator.yaml
kubectl apply -f cnpg-operator.yaml
```

This resulted in a number of errors because of conflicts between the client-side and server-side management of objects, so I retried with `--server-side --force-conflicts` to at least run through the whole `apply` successfully.

```
❯ kubectl apply -f cnpg-operator.yaml --server-side --force-conflicts
namespace/cnpg-system serverside-applied
customresourcedefinition.apiextensions.k8s.io/backups.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/clusterimagecatalogs.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/clusters.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/databases.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/failoverquorums.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/imagecatalogs.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/poolers.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/publications.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/scheduledbackups.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/subscriptions.postgresql.cnpg.io serverside-applied
serviceaccount/cnpg-manager serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-database-editor-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-database-viewer-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-manager serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-publication-editor-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-publication-viewer-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-subscription-editor-role serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-subscription-viewer-role serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/cnpg-manager-rolebinding serverside-applied
configmap/cnpg-default-monitoring serverside-applied
service/cnpg-webhook-service serverside-applied
deployment.apps/cnpg-controller-manager serverside-applied
mutatingwebhookconfiguration.admissionregistration.k8s.io/cnpg-mutating-webhook-configuration serverside-applied
validatingwebhookconfiguration.admissionregistration.k8s.io/cnpg-validating-webhook-configuration serverside-applied
```

Now, the `cnpg-controller-manager-7fffcb6d86-6hphr` pod seems to have started and is running successfully. Because CNPG 1.27.0 was released the day I was doing all of this, I also now see that the successful install via `kubectl cnpg` was for version 1.27.0, whereas the failure was for version 1.26.1, so that could have been the difference.

## Use of the operator

Use of the operator means definining and creating a postgres cluster for an application, which CNPG picks up and creates for us. Attempting to create with a yaml like this, using either `csi-cephfs-sc-ephemeral` for testing or `csi-cephfs-sc` for a production storage class:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: keystore-pg
spec:
  instances: 3
  storage:
    storageClass: csi-cephfs-sc
    size: 5Gi
```

After applying that chart, it took a few minutes to come up, but then was operational quickly as seen in the `kubectl cnpg status keystore-pg` output:

```
❯ kubectl apply -f postgres-cluster.yaml -n keycloak
cluster.postgresql.cnpg.io/keystore-pg created

❯ k8 cnpg status keystore-pg -n keycloak
Cluster Summary
Name                 default/keystore-pg
System ID:           7538142671149060124
PostgreSQL Image:    ghcr.io/cloudnative-pg/postgresql:17.5
Primary instance:    keystore-pg-1
Primary start time:  2025-08-13 18:43:51 +0000 UTC (uptime 2m51s)
Status:              Cluster in healthy state
Instances:           3
Ready instances:     3
Size:                126M
Current Write LSN:   0/6000060 (Timeline: 1 - WAL File: 000000010000000000000006)

Continuous Backup status
Not configured

Streaming Replication status
Replication Slots Enabled
Name           Sent LSN   Write LSN  Flush LSN  Replay LSN  Write Lag  Flush Lag  Replay Lag  State      Sync State  Sync Priority  Replication Slot
----           --------   ---------  ---------  ----------  ---------  ---------  ----------  -----      ----------  -------------  ----------------
keystore-pg-2  0/6000060  0/6000060  0/6000060  0/6000060   00:00:00   00:00:00   00:00:00    streaming  async       0              active
keystore-pg-3  0/6000060  0/6000060  0/6000060  0/6000060   00:00:00   00:00:00   00:00:00    streaming  async       0              active

Instances status
Name           Current LSN  Replication role  Status  QoS         Manager Version  Node
----           -----------  ----------------  ------  ---         ---------------  ----
keystore-pg-1  0/6000060    Primary           OK      BestEffort  1.27.0           k8s-dev-node-3
keystore-pg-2  0/6000060    Standby (async)   OK      BestEffort  1.27.0           k8s-dev-node-1
keystore-pg-3  0/6000060    Standby (async)   OK      BestEffort  1.27.0           k8s-dev-node-2
```

## Deleting a cluster

Once the cluster is up and running, it can be quickly deleted with:

```
❯ k8 delete Cluster keystore-pg -n keycloak
cluster.postgresql.cnpg.io "keystore-pg" deleted
```

Shortly thereafter, CNPG takes down all of the running pods and services.

## Accessing the cluster

Assuming we didn't delete the cluster above, it can be accessed using `psql` by exec'ing into the cluster pods, or via postgres database connections on port 5432 to the services that were created. Here's an example of accessing the pod via psql:

```sh
kubectl -n keycloak exec -it keycloak-pg-1 -- psql
Defaulted container "postgres" out of: postgres, bootstrap-controller (init)
psql (17.5 (Debian 17.5-1.pgdg110+1))
Type "help" for help.

postgres=# \l
                                                List of databases
   Name    |  Owner   | Encoding | Locale Provider | Collate | Ctype | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+---------+-------+--------+-----------+-----------------------
 app       | app      | UTF8     | libc            | C       | C     |        |           |
 postgres  | postgres | UTF8     | libc            | C       | C     |        |           |
 template0 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
(4 rows)

postgres=# \c app
You are now connected to database "app" as user "postgres".
app=# \d
Did not find any relations.
```

Note that the login is to the `postgres` admin user and database, and that CNPG created a default `app` database. More configuration is needed to control the name and type of the databses created on startup.

## Create database with initdb bootstrap

We can also set various database options for naming the application database and role, as well as database creation options. 
Below we add configuration to enable `initdb` to bootstrap a specific `keycloak` database and role. This required creating a `basic-auth` secret rather than an `Opaque` secret. See https://kubernetes.io/docs/concepts/configuration/secret/#basic-authentication-secret and https://cloudnative-pg.io/documentation/1.27/bootstrap/#bootstrap-an-empty-cluster-initdb

First the secret needs to be created. the `username` and `password` keys are required, but others can be added as well. Like all secrets, `data` keys are set to base64-encoded strings.

```
apiVersion: v1
kind: Secret
type: kubernetes.io/basic-auth
metadata:
  name: keycloak-pg
data:
  username: a2V5Y2xvYWs=
  password: c29tZV9zZWN1cmVfcHdfNF9zdXJl
```

Once that secret is in place, create the cluster with:

```
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: keycloak-pg
spec:
  instances: 3
  bootstrap:
    initdb:
      database: keycloak
      owner: keycloak
      secret:
        name: keycloak-pg
      encoding: UTF8
      localeProvider: icu
      icuLocale: en_US
      localeCType: en_US.UTF-8
      localeCollate: en_US.UTF-8
  storage:
    storageClass: csi-cephfs-sc
    size: 5Gi
```

Now the database is named `keycloak` and other DB options have been set:

```
❯ k8 cnpg psql keycloak-pg -n keycloak
psql (17.5 (Debian 17.5-1.pgdg110+1))
Type "help" for help.

postgres=# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 keycloak  | keycloak | UTF8     | icu             | en_US.UTF-8 | en_US.UTF-8 | en-US  |           |
 postgres  | postgres | UTF8     | icu             | en_US.UTF-8 | en_US.UTF-8 | en-US  |           |
 template0 | postgres | UTF8     | icu             | en_US.UTF-8 | en_US.UTF-8 | en-US  |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | icu             | en_US.UTF-8 | en_US.UTF-8 | en-US  |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
```

## Connect to the database

Once the database is up and running, you can connect to one of the services from within the cluster, using standard cluster DNS names.

The services you may want to connect to include `rw`, `ro`, and `r` instances. For example, for keycloak, these are:

- `keycloak-pg-rw`: primary instance of the cluster (read/write)
- `keycloak-pg-ro`: secondary replica instance (read-only)
- `keycloak-pg-r`:  other read replicas of the cluster (read-only)

From outside of the cluster, you can port forward port 5432 to one of these services and access it locally:

```sh
# First Port-forward in another terminal using:
#   k8 -n keycloak port-forward service/keycloak-pg-rw 5432:5432
❯ psql -h localhost -U keycloak
Password for user keycloak:
psql (14.17 (Homebrew), server 17.5 (Debian 17.5-1.pgdg110+1))
WARNING: psql major version 14, server major version 17.
         Some psql features might not work.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

keycloak=> \d
Did not find any relations.
```

## Database backups

CloudNativePG now supports both [hot and cold backups](https://cloudnative-pg.io/documentation/1.27/backup/). For hot backups, it supports both a CNGP-I plugin to use external backup systems like Barman to backup to an object store, or CSI Volume snapshots.  For this initial use case, it is simplest to focus on [volume snapshots](https://cloudnative-pg.io/documentation/1.27/appendixes/backup_volumesnapshot/) for the backup and WAL files. By default, the backup uses online hot snapshots, which should work great for us. Once a backup has been completed, we will need to work to be sure the volume snapshot is preserved for an appropriate retention time.

Because backups can be intensive, we can request that backups be made against a replica service rather than the primary, which reduces load on the rw service.

Configuration involves providing an instance of the `ScheduledBackup` resource. A typical configuration might look like this:

```
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: keycloak-pg-backup
spec:
  schedule: "0 0 0 * * *"  # At midnight every day
  backupOwnerReference: self
  cluster:
    name: keycloak-pg
  method: volumeSnapshot
```

