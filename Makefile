ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

php74.zip: $(ROOT_DIR)/bootstrap $(ROOT_DIR)/build.sh $(ROOT_DIR)/php.ini
	docker run --rm -v $(ROOT_DIR):/opt/layer lambci/lambda-base-2:build /opt/layer/build.sh 4

php73.zip: $(ROOT_DIR)/bootstrap $(ROOT_DIR)/build.sh $(ROOT_DIR)/php.ini
	docker run --rm -v $(ROOT_DIR):/opt/layer lambci/lambda-base:build /opt/layer/build.sh 3

test74: php74.zip
	docker run --rm -v $(ROOT_DIR):/opt/layer lambci/lambda-base-2:build /opt/layer/test.sh 4

test73: php73.zip
	docker run --rm -v $(ROOT_DIR):/opt/layer lambci/lambda-base:build /opt/layer/test.sh 3

clean:
	rm -f php74.zip php73.zip

.PHONY: test clean
