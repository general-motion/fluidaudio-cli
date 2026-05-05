# Contributing

## Build From Source

```bash
swift build -c release --product fluidaudio
.build/release/fluidaudio --help
```

## Development

We use Swift formatter and SwiftLint. To run:

```bash
make format
make lint
make check
```

## Integration Tests

`make integration-test` runs fast CLI process tests.
`make model-integration-test` runs real model examples and may download models.
Set `FLUIDAUDIO_CLI_BINARY=/path/to/fluidaudio` to test a specific binary.
