Build a Docker Container and Run VK Tests.

Usage:

    bash vk_tests/build-and-run-vk-tests.sh

will build the container and run it.
This script is designed to be run 
from the main directory.

The audio hal code has been modified to 
tolerate the minimal test environment.

The Makefile is used to handle execution 
environment and the container does not 
require elevated priviliges.

If you want to build and run locally (maybe on 
your laptop) edit run_vk_tests.sh file and 
uncomment out the identity related lines and
provide a identity2.json file.

Currently does not clean up after itself (not sure 
about reporting requirements yet) so if this is
desired simply add the --rm flag to the run command.

For example, if you are running on an AMD64 and you
want to use a identity2.json file you have handy you
would edit the Makefile and set the DOCKER_PLATFORM
to 'amd64' then you would uncomment out these lines 
in the run_vk_tests.sh file after adding your 
identity2.json file to the vk_tests/ subdirectory 

    mkdir -p /home/mycroft/.config/mycroft/identity
    cp /home/mycroft/identity2.json /home/mycroft/.config/mycroft/identity/.

and you would be good to go. 

