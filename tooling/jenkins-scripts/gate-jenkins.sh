#!/bin/bash

# Actions to orchestrate running a validated-merge build internally via Jenkins

set -e
set -o pipefail
set -x

echo "Begin gate-jenkins.sh"

export NODE_ENV=test
export XUNIT=true

LOG_FILE="$(pwd)/test.log"
rm -f "${LOG_FILE}"

# Remove the lerna installed from npm so we can link the one from the fork
rm -rf ./node_modules/lerna

CWD=`pwd`

cd /tmp
ls lerna > /dev/null 2> /dev/null || git clone git@github.com:ianwremmel/lerna.git
cd lerna
git checkout de0f7f2
npm link
cd "${CWD}"
npm link lerna

# INSTALL
echo "Installing modular SDK dependencies"
npm run bootstrap

# BUILD
echo "Cleaning legacy directories"
npm run grunt -- --no-color --stack clean

echo "Cleaning modular directories"
npm run grunt:concurrent -- --no-color --stack clean

echo "Building modules"
npm run grunt:circle -- build

# TEST
echo "Connecting to Sauce Labs..."
npm run sauce:start
echo "Connected to Sauce Labs"

mkdir -p reports

echo "Running all tests and writing output to ${LOG_FILE}"
set +e
npm run sauce:run -- npm run grunt:circle -- static-analysis test 2>&1> "${LOG_FILE}"
EXIT_CODE=$?
set -e

echo "Disconnecting from Sauce Labs..."
npm run sauce:stop
echo "Disconnected from Sauce Labs"

echo "Complete gate-jenkins.sh"

exit $EXIT_CODE