#!/usr/bin/env python3
# Copyright 2022 Mycroft AI Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
import argparse
import hashlib
import io
import re
import sys
import wave
from pathlib import Path
from typing import Tuple, Union

import pysbd
from mimic3_tts import (
    AudioResult,
    Mimic3Settings,
    Mimic3TextToSpeechSystem,
    SSMLSpeaker,
)

TEMPLATE_CHARS = {"|", "{", "}"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cache_directory", help="Path to TTS cache directory")
    args = parser.parse_args()

    args.cache_directory = Path(args.cache_directory)
    args.cache_directory.mkdir(parents=True, exist_ok=True)

    segmenter = pysbd.Segmenter(language="en", clean=False)
    tts = Mimic3TextToSpeechSystem(Mimic3Settings(voice="en_UK/apope_low"))

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        if any(c in TEMPLATE_CHARS for c in line):
            # Don't try to expand dialog templates
            continue

        segments = segmenter.segment(line)
        for segment in segments:
            wav_name = hash_sentence(segment)
            wav_path = args.cache_directory / f"{wav_name}.wav"

            if not wav_path.exists():
                sentence, ssml = apply_text_hacks(segment)
                synthesize(tts, segment, wav_path, ssml=ssml)
                print(wav_path)


# -----------------------------------------------------------------------------


def hash_sentence(sentence: str):
    encoded_sentence = sentence.encode("utf-8", "ignore")
    sentence_hash = hashlib.md5(encoded_sentence).hexdigest()

    return sentence_hash


def apply_text_hacks(sentence: str) -> Tuple[str, bool]:
    """Mycroft-specific workarounds for text."""

    # HACK: Mycroft gives "eight a.m.next sentence" sometimes
    sentence = sentence.replace(" a.m.", " a.m. ")
    sentence = sentence.replace(" p.m.", " p.m. ")

    # A I -> A.I.
    sentence = re.sub(
        r"\b([A-Z](?: |$)){2,}",
        lambda m: m.group(0).strip().replace(" ", ".") + ". ",
        sentence,
    )

    # Assume SSML if sentence begins with an angle bracket
    ssml = sentence.strip().startswith("<")

    # HACK: Speak single letters from Mycroft (e.g., "A;")
    if (len(sentence) == 2) and sentence.endswith(";"):
        letter = sentence[0]
        ssml = True
        sentence = f'<say-as interpret-as="spell-out">{letter}</say-as>'
    else:
        # HACK: 'A' -> spell out
        sentence, subs_made = re.subn(
            r"'([A-Z])'",
            r'<say-as interpret-as="spell-out">\1</say-as>',
            sentence,
        )
        if subs_made > 0:
            ssml = True

    return (sentence, ssml)


def synthesize(
    tts: Mimic3TextToSpeechSystem,
    text: str,
    wav_path: Union[str, Path],
    ssml: bool = False,
) -> bytes:
    """Synthesize audio from text and return WAV bytes"""
    with open(wav_path, "wb") as wav_io:
        wav_file: wave.Wave_write = wave.open(wav_io, "wb")
        wav_params_set = False

        with wav_file:
            try:
                if ssml:
                    # SSML
                    results = SSMLSpeaker(tts).speak(text)
                else:
                    # Plain text
                    tts.begin_utterance()
                    tts.speak_text(text)
                    results = tts.end_utterance()

                for result in results:
                    # Add audio to existing WAV file
                    if isinstance(result, AudioResult):
                        if not wav_params_set:
                            wav_file.setframerate(result.sample_rate_hz)
                            wav_file.setsampwidth(result.sample_width_bytes)
                            wav_file.setnchannels(result.num_channels)
                            wav_params_set = True

                        wav_file.writeframes(result.audio_bytes)
            except Exception as e:
                if not wav_params_set:
                    # Set default parameters so exception can propagate
                    wav_file.setframerate(22050)
                    wav_file.setsampwidth(2)
                    wav_file.setnchannels(1)

                raise e


# -----------------------------------------------------------------------------

if __name__ == "__main__":
    main()
