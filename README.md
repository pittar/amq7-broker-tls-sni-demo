# AMQ 7 Broker (Artemis) SSL with TLS SNI

## Problem

When you deploy AMQ7 Broker (Apache Artemis) in an OpenShift cluster, how do you access it externally when the OpenShift router only handles http/s traffic on ports 80 and 443?

## Solution

Use [TLS Server Name Indication (SNI)](https://en.wikipedia.org/wiki/Server_Name_Indication), which allows the router to pass TCP traffic on to the the backend pod.  This is one of the main use cases for the `passthrough` TLS settting for routes!

This does add some complexity, however, as your application running in your pod is now responsible for terminating the SSL connection.

## AMQ 7 ImageStreams and Templates

If you don't have the latest AMQ ImageStreams and Templates you can import them (as a `cluster-admin') by following the steps in the docs.

For example:

```
$ oc project openshift

$ oc replace --force  -f \
https://raw.githubusercontent.com/jboss-container-images/jboss-amq-7-broker-openshift-image/77-7.7.0.GA/amq-broker-7-image-streams.yaml

$ for template in amq-broker-77-basic.yaml \
amq-broker-77-ssl.yaml \
amq-broker-77-custom.yaml \
amq-broker-77-persistence.yaml \
amq-broker-77-persistence-ssl.yaml \
amq-broker-77-persistence-clustered.yaml \
amq-broker-77-persistence-clustered-ssl.yaml;
 do
 oc replace --force -f \
https://raw.githubusercontent.com/jboss-container-images/jboss-amq-7-broker-openshift-image/77-7.7.0.GA/templates/${template}
 done
```

## TLS SNI with AMQ 7 Broker

### Generate Keystores and Truststores

In order for 2-way SSL to work between the broker and an application, we need to create a `keystore` and `truststore` for each, and exchange certificates.

Here is an example of the process using the Java keytool:

```
keytool -genkey -keystore broker.ks -storepass password -keypass password -dname "CN=ActiveMQ Artemis Server, OU=Artemis, O=ActiveMQ, L=AMQ, S=AMQ, C=AMQ" -keyalg RSA

keytool -export -keystore broker.ks -file broker-cert.cer -storepass password

keytool -import -keystore client.ts -file broker-cert.cer -storepass password -keypass password -noprompt

keytool -genkey -keystore client.ks -storepass password -keypass password -dname "CN=ActiveMQ Artemis Client, OU=Artemis, O=ActiveMQ, L=AMQ, S=AMQ, C=AMQ" -keyalg RSA

keytool -export -keystore client.ks -file client-cert.cer -storepass password

keytool -import -keystore broker.ts -file client-cert.cer -storepass password -keypass password -noprompt
```

### Create a new OpenShift Project, Service Account, and Secret

Create a new project:

```
$ oc new-project amq-demo
```

Create a service account for AMQ Broker:

```
$ oc create sa amq-service-account
```

Create a secret with the broker keystore and truststore:

```
$ oc create secret generic amq-app-secret --from-file=broker.ks --from-file=broker.ts
```

Link the secret to the new service account:

```
$ oc secrets link sa/amq-service-account secret/amq-app-secret
```

### Deploy the SSL Broker Template (ephemeral or persistent)

Now, deploy one of the SSL variants of the AMQ Broker templates.  For this, we'll use ephemeral.  You can also use the OpenShift UI by providing he same parameters.

```
$ oc new-app --template=amq-broker-77-ssl \
   -p AMQ_PROTOCOL=openwire,amqp,stomp,mqtt,hornetq \
   -p AMQ_QUEUES=demoQueue \
   -p AMQ_ADDRESSES=demoTopic \
   -p AMQ_USER=amquser \
   -p AMQ_PASSWORD=password \
   -p AMQ_SECRET=amq-app-secret \
   -p AMQ_TRUSTSTORE=broker.ts \
   -p AMQ_TRUSTSTORE_PASSWORD=password \
   -p AMQ_KEYSTORE=broker.ks \
   -p AMQ_KEYSTORE_PASSWORD=password
```
