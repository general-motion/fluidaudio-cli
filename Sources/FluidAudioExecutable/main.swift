import FluidAudioCommand

@available(macOS 14.0, *)
@main
enum FluidAudioExecutable {
  static func main() async {
    await FluidAudioCommand.main()
  }
}
