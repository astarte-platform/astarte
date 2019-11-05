#!/bin/bash
set -o errexit

# config
git config --global user.email "astarte-machine@ispirata.com"
git config --global user.name "Astarte Bot"

# deploy
git clone --quiet "https://${GITHUB_TOKEN}@github.com/astarte-platform/docs.git" docs-repo
cd docs-repo

DOCS_DIRNAME="$(echo $TRAVIS_BRANCH | sed 's/master/snapshot/g' | sed 's/release-//g')"

rm -rf $DOCS_DIRNAME
mkdir $DOCS_DIRNAME
cp -r ../$(dirname $0)/doc/* $DOCS_DIRNAME/

# Spare API docs from being deleted
git checkout $DOCS_DIRNAME/api

# Add and push
git add .
git commit -m "Deploy to Github Pages"
git push --force --quiet > /dev/null 2>&1
