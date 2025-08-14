# Postgres Operator

We have installed the Postgres Operator from [CloudNativePG](https://cloudnative-pg.io/) to serve our persistent database needs. The CloundNativePG operator provides a convenient set of custom resources for creating a postgres `Cluster` that is replicated and easily backed up. Each deployed `Cluster` is tied to a single version of Postgres through a `ClusterImageCatalog`. No-downtime [Rolling Upgrades](https://cloudnative-pg.io/documentation/1.27/rolling_update/) from one minor postgres version to another are enabled, and the operator also supports [major version upgrades](https://cloudnative-pg.io/documentation/1.27/logical_replication/) (e.g., 16 to 17) through logical replication across clusters each running different versions.

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

First the secret needs to be created. The `username` and `password` keys are required, but others can be added as well. Like all secrets, `data` keys are set to base64-encoded strings. The username you choose should match the `owner` field in the Cluster definition that comes next.

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

## CloudNativePG Operator Installation

The operator is only installed once on a Kubernetes cluster, and can be used by all applications to deploy Postgres as described above.

My first attempt to install the operator used the operator manifest directly from github, which gave an error on version 1.26.1.  Alternatives include using the `kubectl cnpg` plugin to generate a customize mannifest to be applied (and which can be customized), or using the helm chart (which seems to be in development). You can install the plugin on Mac using `brew install kubectl-cnpg`, which is a useful plugin for managing clusters. At a later date we may wnat to reconsider the helm chart, but it does not seem to be the standard route today.

First, use `kubectl cnpg` for generating custom manifests:

```sh
kubectl cnpg install generate --help
kubectl cnpg install generate > cnpg-operator.yaml
```

And then apply them, being sure to use the `--server-side` flag.

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

Note that my initial install did not use the `--server-side` flag, and resulted in a number of errors because of conflicts between the client-side and server-side management of objects, so I retried with `--server-side --force-conflicts` to run through the whole `apply` successfully.

Now, the `cnpg-controller-manager` pod seems has started and is running successfully. Because CNPG 1.27.0 was released the day I was doing all of this, I also now see that the successful install via `kubectl cnpg` was for version 1.27.0, whereas the failure was for version 1.26.1, so that could have been the difference.

## CloudNativePG Operator Upgrades

CloudNativePG releases new versions of the operator roughly monthly, and recommends [monthly upgrades](https://cloudnative-pg.io/documentation/1.27/installation_upgrade/#upgrades). The current operator suppors their `v1` API, and they state that these should be backwards compatible. They highly recommend upgrading to the current version monthly, and applying each upgrade in the order in which they are released (don't skip versions). When upgrading, the process involves two steps:

1) Upgrade the operator itself by re-applying the new manifest for the new version.
2) Upgrade the Cluster instance for all databases, which happens automatically

The chapter on [CNPG Upgrades](https://cloudnative-pg.io/documentation/1.27/installation_upgrade/#upgrades) has useful information on other options that might need to be set in order to stagger the postgres Cluster and instance migrations.
