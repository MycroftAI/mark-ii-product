
cp vk_tests/Dockerfile .
cp vk_tests/Makefile .
docker buildx build . --tag dinkum --load
docker run -it --entrypoint /bin/bash dinkum

