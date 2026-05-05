# FluidAudio CLI

This is a tiny command-line wrapper around the excellent
[FluidAudio](https://github.com/FluidInference/FluidAudio) library.

## Install

Requirements:

- macOS 14 or newer
- Apple Silicon
- Network access the first time a command downloads Core ML models

Use the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/general-motion/fluidaudio-cli/main/install.sh | bash
```

Or download and install the release archive directly:

```bash
curl -fL -o fluidaudio.tar.gz \
  https://github.com/general-motion/fluidaudio-cli/releases/latest/download/fluidaudio-aarch64-apple-darwin.tar.gz
tar -xzf fluidaudio.tar.gz
sudo install fluidaudio /usr/local/bin/fluidaudio
```

## Usage

```bash
fluidaudio transcribe audio.wav
fluidaudio diarize meeting.wav
fluidaudio vad audio.wav
fluidaudio tts "Hello from FluidAudio." --output out.wav
fluidaudio doctor
```

For `transcribe`, `diarize`, `vad`, and `doctor`, `--output` mirrors stdout: text by default,
JSON when `--json` is set. JSON is compact by default; add `--pretty` for formatted output.

For `tts`, `--output` is always the WAV file. Use `--json` for a synthesis summary on stdout,
or `--summary-output` to write that summary to a file.

### Transcribe

```bash
fluidaudio transcribe audio.wav
fluidaudio transcribe audio.wav --json --output transcript.json
fluidaudio transcribe audio.wav --language en --model parakeet-v3
```

### Diarize

```bash
fluidaudio diarize meeting.wav
fluidaudio diarize meeting.wav --json --output result.json
fluidaudio diarize meeting.wav --mode full-file --json --output result.json
```

### Voice Activity Detection

```bash
fluidaudio vad audio.wav
fluidaudio vad audio.wav --json --output vad.json
```

### Text To Speech

```bash
fluidaudio tts "Hello from FluidAudio." --output out.wav
fluidaudio tts "Hello from FluidAudio." --voice af_heart --speed 1.05 --json
fluidaudio tts "Hello from FluidAudio." --voice af_heart --summary-output tts.json
```

### Doctor

```bash
fluidaudio doctor
fluidaudio doctor --json --output doctor.json
```
