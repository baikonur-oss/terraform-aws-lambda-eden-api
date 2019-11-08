#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

export USE_CACHE=no

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "build a Lambda zip package for deployment"
      echo " "
      echo "./build.sh [options]"
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "--use-cache               use cache for faster rebuilds"
      exit 0
      ;;
    --use-cache)
      export USE_CACHE=yes
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [ -z ${AWS_SESSION_TOKEN+x} ] && [[ ${USE_CACHE} != "yes" ]]; then
	echo "Cleaning cache before build"
	rm -rf build
	rm -rf lambda_package.zip
fi

echo "Copying files to temporary dir"
mkdir -p build
cp -f lambda/*.py build/
cp -f lambda/requirements-deploy.txt build/

echo "pip install"
cd build
docker run --rm -v $(pwd):/root/p python:3.7 pip3 install --upgrade -r /root/p/requirements-deploy.txt -t /root/p/ > /dev/null

echo "Compiling and making zip package"
if [[ ! -f venv/bin/activate ]]; then
    python3 -m venv ./venv
fi

source venv/bin/activate
python -m compileall . > /dev/null
zip -r9 ../lambda_package.zip ./ -x ".*" > /dev/null
cd ..

echo "Finished!"

