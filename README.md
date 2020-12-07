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

### TL;DR

If you want a one-liner to just do everything, login with the `oc` cli and run:

```
$ ./provision-broker.sh

# Once the broker is running:
# 
# * Replace the broker URL in:
#      * manifests/consumer/broker-params-secret.yaml
#      * manifests/producer/broker-params-secret.yaml
# With the passthrough route URL printed at the end of the broker deployment script, then run:

$ ./provision-clients.sh
```

This will run all the steps below to generate keystores/truststores, an amq-demo project, a service account, secret, and broker.

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
$ oc new-project amq-broker-demo
```

Create a service account for AMQ Broker:

```
$ oc create sa amq-service-account
```

Create a secret with the broker keystore and truststore:

```
$ oc create secret generic amq-app-secret --from-file=broker.ks=tls/broker.ks --from-file=broker.ts=tls/broker.ts
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

Finally, create a `passthrough` route that will expose port 61617 (all protocols ssl) through the router on port 443:

```
$ oc apply -f manifests/broker/broker-passthrough-route.yaml

$ oc get route broker -o=jsonpath='{.spec.host}{"\n"}'
```

## Test It Out!

There is a **producer** and a **consumer** client that you can use to test out the new broker config.

Take note of the passthrough route url (it was printed at as the last output of the provision script, or you an find it with `oc get route broker -o=jsonpath='{.spec.host}{"\n"}'`).

Open two new terminals (make sure `JAVA_HOME` is set to Java 8):
* In the first terminal, change to the `clients/cli-amqp-producer` directory and run:
    * `mvn spring-boot:run -Damq-broker.url=<route url>`
    * Example: `mvn spring-boot:run -Damq-broker.url=broker-amq-broker-demo.apps.cluster-0df2.0df2.example.opentlc.com`
    * Once the app starts, you can enter messages to add to the queue.
* In the second terminal, change to the `clients/cli-amqp-consumer` directory and run:
    * `mvn spring-boot:run -Damq-broker.url=<route url>`
    * Example: `mvn spring-boot:run -Damq-broker.url=broker-amq-broker-demo.apps.cluster-0df2.0df2.example.opentlc.com`
    * Once the app starts, you will see the messages that were pulled from the queue.


## Reference

Thanks [Josh Reagan](https://github.com/joshdreagan) for the help and the [sample clients](https://github.com/joshdreagan/amqp-clients)!