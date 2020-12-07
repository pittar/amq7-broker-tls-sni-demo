#!/bin/bash

echo "Create a client demo project and secret."
echo ""
oc new-project amq-client-demo

oc create secret generic amq-client-secret --from-file=client.ks=tls/client.ks --from-file=client.ts=tls/client.ts
echo "Project 'amq-client-demo' and secret created."
echo ""

echo "Create the client builds, imagstreams, deployments and service."
echo ""
echo "Creating Producer"
echo ""
oc apply -f manifests/producer

echo ""
echo "Creating Consumer"
echo ""
oc apply -f manifests/consumer

echo ""
echo "** Producer and Consumer building and deploying."
echo "** Once started, view the pod logs to see messages being created and consumed."
echo ""

