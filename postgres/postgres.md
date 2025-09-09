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
  resources:  # see note below
    requests:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 500m
        memory: 1Gi
    parameters:
      shared_buffers: 256MB
```
> [!NOTE]
> Always set resource requests and limits. The [CNPG docs recommend](https://cloudnative-pg.io/documentation/1.20/resource_management/) setting limits and requests for both memory and CPU to the same value, so your cluster's pods get assigned to the "Guaranteed" QoS class. Be sure to size appropriately for your database processing loads, without over-allocating resources.

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

## Minor and major Postgres version upgrades

One of the most challenging parts of managing the database is how to handle version upgrades with minimal or no downtime. CloudNativePG has significantly made this easier, and provides [multiple upgrde paths](https://cloudnative-pg.io/documentation/1.27/postgres_upgrades). Minor upgrades are handles seamlessly, while major upgrades are **also** handled seamlessless but have some additional considerations. For a great overview, see [CNPG Recipe 17 - PostgreSQL In-Place Major Upgrades](https://cloudnative-pg.io/documentation/1.27/postgres_upgrades/#example-performing-a-major-upgrade) by the maintainers of CloundNativePG.

### Minor upgrades

For [minor upgrades](https://cloudnative-pg.io/documentation/1.27/rolling_update/) within a major version, e.g., 17.4 to 17.5, all that is required is to update the cluster definition with a new image version, which will trigger a [rolling upgrade](https://cloudnative-pg.io/documentation/1.27/rolling_update/) of the replicas in the cluster. This is a fully online, no downtime upgrade. For example, given a database at version 17.1, applying the following manifest would do a rolling upgrade to 17.5:

```
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:17.5-minimal-bookworm
  instances: 3
  storage:
    size: 1Gi
```

Rather than managing the `imageName` manually, an alternative is to rely on an `ImageCatalog`. Updates to the minor version in an ImageCatalog will update all clusters that use that catalog to the most recent minor version. So this could be a mechanism for us to do patch releases without releasing new versions of sof helm charts.

### Major  upgrades

For major upgrade paths, we will focus on the two most recent (and arguably best) approaches:

- Online upgrades via Native logical replication
    - These are seamless, but are more complicated to set up
    - No downtime, as the upgrade happens via replication to a new cluster. Applications then switch to the new cluster when ready.
- Offline, in place upgrades using `pg_upgrade`
    - Some downtime while the database is upgraded
    - Applications do not need to be reconfigured, as they will already point to the new version on restart
    - See: https://cloudnative-pg.io/documentation/1.27/postgres_upgrades/#offline-in-place-major-upgrades


For the in-place upgrade, the benefits accrue around not having to reconfigure applications to point at a new cluster. It is fast, using hard-links for most file operations rather than copies, and works well in cases where the upgrade is not complicated, e.g., no obscure postgres extensions. It's major downside is that the upgrade may fail, but even in that case, it can be rolled back to the state before the upgrade started. 

The basic procedue for an `pg_upgrade` is fairly simple procedurally. For example, starting from a version 16 database [as described in the user manual](https://cloudnative-pg.io/documentation/1.27/postgres_upgrades/#example-performing-a-major-upgrade):

```
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:16-minimal-bookworm
  instances: 3
  storage:
    size: 1Gi
```

you can update to version 17 postgres by simply changing the `imageName` to a more recent postgres image and re-applying the template (either with `kubectl` or through helm templates):

```
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:17-minimal-bookworm
  instances: 3
  storage:
    size: 1Gi
```

So, you can see the minor and major upgrade paths now use the same mechanism to trigger updates. The only difference is that major upgrades require some downtime while the database is upgraded.

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

## Migrating from an existing database

[Importing an existing database](https://cloudnative-pg.io/documentation/1.16/database_import/) into a new CNPG cluster is possible using the `initdb` bootstrap method, which will `import` the database specified in an `externalClusters` section. Two approaches are available - microservice and monolith. Microservice is for destination clusters that host a single application database, while monolith is for clusters designed to hold multiple databases and users. The import operation uses `pg_dump` via connection to the origin host, and `pg_restore` to create the database in the new cluster. Although concurrent writes during the `pg_dump` phase are not problematic to creating the snapshot, the `pg_restore` is based on that snapshot so any writes that happen after the `pg_dump` phase completes would not be in the migrated version of the database. The CNPG docs recommend stopping write operations on the source before the final import. The safest route would be to turn off write access to the origin postgres database, then do the entire migration. If downtime is a concern, CNPG does support [logical replication] using a `Publisher` and `Subscriber`. While doing the migration, it is simple to also upgrade postgres by setting the `imageName` field in the chart. In the example below I upgrade from postgres 10 (the old metadig version) to postgres 15 - just make sure that the new version is compatible with the features the old database requires.

Below is an example `cluster.yaml` used to migrate metadig from a kubernetes postgres deployment with a custom helm chart to CNPG.

```
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: metadig-pg
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:15.6
  bootstrap:
    initdb:
      import:
        type: microservice
        databases:
          - metadig
        source:
          externalCluster: cluster-metadig-10
        pgRestoreExtraOptions:
          - '--verbose'
      database: metadig
      owner: metadig
      secret:
        name: metadig-pg
  storage:
    storageClass: csi-cephfs-sc
    size: 50Gi
  externalClusters:
    - name: cluster-metadig-10
      connectionParameters:
        # Use the correct IP or host name for the source database
        host: 10.109.52.33
        user: metadig
        dbname: metadig
      # password:
      #    name: cluster-metadig-10-owner
      #    key: password
```

#### `initdb` and `import`

The `initdb` section is what the new database in the CNPG cluster will be called. This is described above in the keycloak example. The important fields here are the `database` name, `owner` user id, and the name of a `secret` to be used to create the password for the `owner` user. See above for instructions on how to create the secret.

The `import` section describes the type of import, which database we are importing (for `microservices` only one entry in the `databases` field is allowed, and the source, which corresponds to the `externalCluster` field defined in the section below. Optionally, additional arguments for `pg_restore` and `pg_dump` can be set. The `--verbose` flag for `pg_restore` is particularly helpful if problems in the source database (such as missing keys, data not meeting constraints, etc) might exist, since otherwise the `pg_restore` error messages don't give much information.

#### `externalClusters`

[This section](https://cloudnative-pg.io/documentation/1.16/bootstrap/#the-externalclusters-section) describes how to connect to the source database. The name must match the name given in the `source` section in `initdb.import`. The username, database name, and (if required) password should all match whatever is needed to log into the source database. The host, when backing up from another k8s pod, should be the IP address of the pod. This can be obtained by running `kubectl get pod {PG-POD-NAME} -o wide`

### The migration process

Once the `cluster.yaml` is finished, create the new cluster by running `kubectl apply -f cluster.yaml` (make sure to create any secrets needed first). A few jobs will run as new pods in your k8s namespace.

1. Bootstrap pod
  - this is the import phase, where `pg_dump` and `pg_restore` happen
  - inspect the logs to monitor progress (`kubectl logs {bootstrap-pod}`)
  - this might take a while depending on the size of the db
2. Init pod
  - sets up users and applies other initial configs to the new db
  - pretty quick
3. Cluster pods
  - once the bootstrap and init jobs/pods finish, the cluster pods should spin up, along with the `r/ro/rw` services

To check on your new cluster db, exec into a pod and log into the postgres according to the credentials you set in the `initdb` section. **Note:** If you do not have a linux user of the same name as your db owner in your pod, you need to add `-h 127.0.0.1` to your `psql` command (eg: `psql metadig -U metadig -h 127.0.0.1`). Without the host, `psql` tries a Unix domain socket connection using peer auth, and if there is no `metadig` user the auth will fail.

### Connecting your application to the new cluster

Modifying your application to connect to the new cluster will depend entirely on how the app connected to the old cluster, of course. If using a jdbc url, just modify the `service` portion to match the new CNPG service name that is appropriate, eg: `jdbc:postgresql://{service}.{namespace}.svc.cluster.local:5432/{db-name}`. It may also be necessary to append `?sslmode=disable` to the end of the url (`jdbc:postgresql://metadig-pg-rw.metadig.svc.cluster.local:5432/metadig?sslmode=disable`). This disables ssl on the client side, since by default CNPG postgres instances have ssl enabled.

### Cleaning up old postgres instance and mount

TODO

## Using a connection pooler

TODO

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
