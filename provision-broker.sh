#!/bin/bash

echo "Generate broker and client keystores and trustores."
echo ""
keytool -genkey -keystore tls/broker.ks -storepass password -keypass password -dname "CN=ActiveMQ Artemis Server, OU=Artemis, O=ActiveMQ, L=AMQ, S=AMQ, C=AMQ" -keyalg RSA
keytool -export -keystore tls/broker.ks -file tls/broker-cert.cer -storepass password
keytool -import -keystore tls/client.ts -file tls/broker-cert.cer -storepass password -keypass password -noprompt
keytool -genkey -keystore tls/client.ks -storepass password -keypass password -dname "CN=ActiveMQ Artemis Client, OU=Artemis, O=ActiveMQ, L=AMQ, S=AMQ, C=AMQ" -keyalg RSA
keytool -export -keystore tls/client.ks -file tls/client-cert.cer -storepass password
keytool -import -keystore tls/broker.ts -file tls/client-cert.cer -storepass password -keypass password -noprompt
echo "Keystores and Truststores generated..."
echo ""

echo "Create a demo project, service account, and secret."
echo ""
oc new-project amq-demo

oc create sa amq-service-account

oc create secret generic amq-app-secret --from-file=broker.ks=tls/broker.ks --from-file=broker.ts=tls/broker.ts
echo "Project, service account and secret created."
echo ""

echo "Link the secret to the service account."
echo ""
oc secrets link sa/amq-service-account secret/amq-app-secret
echo "Secret linked to service account."
echo ""

echo "Create the broker from the ephemeral ssl template."
echo ""

oc new-app --template=amq-broker-77-ssl \
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
echo "AMQ Broker is deploying."
echo ""

echo "Create a 'passthrough' route to port 61617 (all protocols ssl)."
echo ""
oc apply -f manifests/broker/broker-passthrough-route.yaml

AMQ_HOST=$(oc get route broker -o=jsonpath='{.spec.host}{"\n"}')

echo "Broker route created. Use the following URL in your client configuration:"
echo ""
echo "amqps://$AMQ_HOST:443"

