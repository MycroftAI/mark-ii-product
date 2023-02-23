#!/bin/bash
# Setup workspace
TODAY=$(date +"%Y-%m-%d")
echo "Getting setup for $TODAY"
PERSISTENT_DIR=$HOME/mark-ii-daily-vk
JOB_DIR=$HOME/mark-ii-daily-vk/$TODAY
ALLURE_DIR=$HOME/mark-ii-daily-vk/$TODAY/allure
LOGS_DIR=$HOME/mark-ii-daily-vk/$TODAY/mycroft-logs
IDENTITY_DIR=$HOME/mark-ii-daily-vk/identity

#DOCKER_IMAGE="registry.gitlab.com/pantace/mycroft/mycroft-mark-ii:arm64v8-ci-qa"
DOCKER_IMAGE="dinkum"

TEST_MYCROFT_CONF_PATCH='{\"enclosure\": {\"board_type\": \"dummy\"}, \"tts\": {\"module\": \"dummy\"}}'

mkdir -p $JOB_DIR && cd $JOB_DIR
mkdir -p -m777 $ALLURE_DIR
mkdir -p -m777 $LOGS_DIR

# Setup emulation as RPi and get Docker container
echo "Fetching required packages..."
#docker run --rm --privileged multiarch/qemu-user-static --reset -p yes # This step will execute the registering scripts
#docker pull ${DOCKER_IMAGE}


# Run the VK Tests
echo "Setting permissions on Mycroft logs..."
docker run -i \
	-v "$IDENTITY_DIR:/home/mycroft/.config/mycroft/identity" \
	-v "$ALLURE_DIR:/home/mycroft/allure" \
	-v "$LOGS_DIR:/var/log/mycroft" \
	--label build=${TODAY} \
    --entrypoint=/bin/bash \
	${DOCKER_IMAGE} \
	-x -c "chown mycroft:mycroft /var/log/mycroft"
echo "Running the Voight Kampff Tests..."
# Notes on the following docker run: 
# - Doesn't seem to be respecting the --user flag - 1050 is the mycroft user in the container.
# - no idea why the PYTHONPATH needs to be explicitly set. It is correctly set in the container.

docker run -i \
	-v "$IDENTITY_DIR:/home/mycroft/.config/mycroft/identity" \
	-v "$ALLURE_DIR:/home/mycroft/allure" \
	-v "$LOGS_DIR:/var/log/mycroft" \
	--label build=${TODAY} \
    --user 1050:1050 \
    --entrypoint=/bin/bash \
	${DOCKER_IMAGE} \
	-x -c " \
    	source /root/.bashrc; \
        export CI=true; \
        cd /opt/mycroft; \
        export PYTHONPATH=/opt/mycroft; \
        echo $TEST_MYCROFT_CONF_PATCH > /home/mycroft/.config/mycroft/mycroft.conf; \
        cat /home/mycroft/.config/mycroft/mycroft.conf; \
        ./bin/mycroft-pip install -r /opt/mycroft/requirements/tests.txt; \
        ./start-mycroft.sh all; \
        ./bin/mycroft-skill-testrunner vktest \
        -c test/integrationtests/voight_kampff/default.yml \
        -f allure_behave.formatter:AllureFormatter \
		-o /home/mycroft/allure/allure-result \
        --tags ~@xfail; \
    " \
    | tee vk-console.log

ALL_TESTS_PASSED=$( grep -e "passed, 0 failed," vk-console.log )

# Prepare and package results
echo "Packaging results..."
docker run \
	-v "$ALLURE_DIR:/home/mycroft/allure" \
	--entrypoint=/bin/bash \
	--label build=${TODAY} \
    --rm \
	${DOCKER_IMAGE} \
	-x -c "chmod 777 -R /home/mycroft/allure"
mkdir -p -m777 $ALLURE_DIR/allure-result/history
cp $PERSISTENT_DIR/history/* $ALLURE_DIR/allure-result/history/
allure generate $ALLURE_DIR/allure-result -o $ALLURE_DIR/allure-report --clean
mv vk-console.log $LOGS_DIR
cp -r $ALLURE_DIR/allure-report/history $PERSISTENT_DIR
pushd $ALLURE_DIR/allure-report
zip ../allure-report.zip -qr ./
popd
zip mycroft-logs.zip -jqr $LOGS_DIR

# Upload results to Reports server
REPORTS_ALLURE_DIR=/root/allure-reports/core/mark-ii-daily/${TODAY}
REPORTS_LOGS_DIR=/root/mycroft-logs/core/mark-ii-daily/${TODAY}
echo "Creating temp directories on reports host..."
echo "- ${REPORTS_ALLURE_DIR}"
echo "- ${REPORTS_LOGS_DIR}"
ssh root@157.245.127.234 "mkdir -p ${REPORTS_ALLURE_DIR}";
ssh root@157.245.127.234 "mkdir -p ${REPORTS_LOGS_DIR}";
echo "Sending results..."
scp $ALLURE_DIR/allure-report.zip root@157.245.127.234:$REPORTS_ALLURE_DIR;
scp mycroft-logs.zip root@157.245.127.234:$REPORTS_LOGS_DIR;
ssh root@157.245.127.234 "unzip -qo ${REPORTS_ALLURE_DIR}/allure-report.zip -d ${REPORTS_ALLURE_DIR}";
ssh root@157.245.127.234 "unzip -qo ${REPORTS_LOGS_DIR}/mycroft-logs.zip -d ${REPORTS_LOGS_DIR}";
#ssh root@157.245.127.234 "rm ${REPORTS_ALLURE_DIR}/allure-report.zip";
#ssh root@157.245.127.234 "rm ${REPORTS_LOGS_DIR}/mycroft-logs.zip";
ssh root@157.245.127.234 "rm -rf /var/www/voight-kampff/core/mark-ii-daily/${TODAY}/"
ssh root@157.245.127.234 "mkdir -p /var/www/voight-kampff/core/mark-ii-daily/${TODAY}/logs"
ssh root@157.245.127.234 "mv -f ${REPORTS_ALLURE_DIR}/* /var/www/voight-kampff/core/mark-ii-daily/${TODAY}/"
ssh root@157.245.127.234 "mv -f ${REPORTS_LOGS_DIR}/*.log /var/www/voight-kampff/core/mark-ii-daily/${TODAY}/logs/"
# TODO rm ${REPORTS_ALLURE_DIR} && rm ${REPORTS_LOGS_DIR}
echo "Report published to: https://reports.mycroft.ai/core/mark-ii-daily/$TODAY/"

# Cleanup
# TODO - Should this only be done on success?
#rm -rf $JOB_DIR

if [ ! -n "$ALL_TESTS_PASSED" ]; then
    exit 1
fi

# TODO Fix the post-job email 
