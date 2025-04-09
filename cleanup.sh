#!/bin/bash
oc delete project demo-kubeconfig
rm ca-bundle.crt
rm kubeconfig-demo-sa