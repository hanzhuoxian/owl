#!/usr/bin/env bash

version="${VERSION:-}"
if [ "${version}" == "" ];then
  version=$(gsemver bump)
fi

if [ -z "$(git tag -l "${version}")" ];then
  git tag -a -m "release version ${version}" "${version}"
fi
