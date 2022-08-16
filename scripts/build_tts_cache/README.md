# TTS Cache Builder

Populates missing WAV files in the Mimic 3 preloaded cache.

To use, first install with:

``` sh
./install.sh
```

and then run with:

``` sh
./run.sh
```

This will look for `.dialog` files in the `mycroft-dinkum/skills` directory and synthesize any missing WAV files to `docker/files/opt/mycroft/preloaded_cache/Mimic3`.


## Requirements

* Python 3.8+
* GNU parallel
