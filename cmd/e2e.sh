#!/usr/bin/env bash

CAPMVM_DIR=/root/cluster-api-provider-microvm

git clone --depth 1 REPO -b BRANCH "$CAPMVM_DIR" || true

export FLINTLOCK_HOSTS=ADDRESSES

pushd "$CAPMVM_DIR" || exit 1
PATH=$PATH:/usr/local/go/bin make e2e
popd || exit 1

rm -rf "$CAPMVM_DIR"
