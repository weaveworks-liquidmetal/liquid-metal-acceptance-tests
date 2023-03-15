#!/usr/bin/env bash

# remove this when we bump to ginkgo v2
export ACK_GINKGO_RC=true

CAPMVM_DIR=/root/cluster-api-provider-microvm

rm -rf "$CAPMVM_DIR"

git clone --depth 1 REPO -b BRANCH "$CAPMVM_DIR" || true

cd "$CAPMVM_DIR" || exit 1
PATH=$PATH:/usr/local/go/bin make e2e E2E_ARGS="-e2e.flintlock-hosts ADDRESSES"
