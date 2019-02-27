ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

php73.zip: ${ROOT_DIR}/bootstrap ${ROOT_DIR}/build.sh ${ROOT_DIR}/php.ini
	docker run --rm -v $(ROOT_DIR):/opt/layer lambci/lambda:build-nodejs8.10 /opt/layer/build.sh 3

test: php73.zip
	docker run --rm -v $(ROOT_DIR):/opt/layer lambci/lambda:build-nodejs8.10 /opt/layer/test.sh

clean:
	rm -f php73.zip

.PHONY: test clean
