#!/usr/bin/env bash

CAPMVM_DIR=/root/cluster-api-provider-microvm

git clone --depth 1 REPO -b BRANCH "$CAPMVM_DIR" || true

pushd "$CAPMVM_DIR" || exit 1
PATH=$PATH:/usr/local/go/bin make e2e E2E_ARGS="-e2e.flintlock-hosts ADDRESSES"
popd || exit 1

rm -rf "$CAPMVM_DIR"
