# run vk-tests on boot

cd /opt/mycroft-dinkum

# fix TTs svc
# replace: IN: ~/.config/mycroft/mycroft.conf STR: mimic3_tts_plug WITH: dummy
sed 's/mimic3_tts_plug/dummy/g' ~/.config/mycroft/mycroft.conf > /home/mycroft/new_mycroft.conf
mv /home/mycroft/new_mycroft.conf ~/.config/mycroft/mycroft.conf

# fix audio_hal to overcome sdl issues
cp /home/mycroft/audio_hal.py /opt/mycroft-dinkum/services/audio/service/.

# identity file hokum
# uncomment to run locally
# this assumes you have an identity2.json file
#mkdir -p /home/mycroft/.config/mycroft/identity
#cp /home/mycroft/identity2.json /home/mycroft/.config/mycroft/identity/.

# start minimum services
python -m services.messagebus.service &
sleep 1
python -m services.intent.service &
sleep 1
python -m services.audio.service &

# install test environment
bash test/install.sh
sleep 1

# start all skills
for d in skills/*/ ; do
    echo "$d"
    bash scripts/run-skill.sh $d &
done

sleep 1

# test each skill
for d in skills/*/ ; do
    bash test/run-skill-tests.sh $d
done

echo "VK Tests Have Completed" > /home/mycroft/RESULTS.txt


