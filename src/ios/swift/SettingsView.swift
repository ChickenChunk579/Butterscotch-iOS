import SwiftUI

struct SettingsView: View {

    // MARK: - Loading

    @AppStorage("ios.lazyRooms")
    private var lazyRooms = true

    @AppStorage("ios.lazyTextures")
    private var lazyTextures = true

    @AppStorage("ios.lazyAudio")
    private var lazyAudio = true

    @AppStorage("ios.loadType")
    private var loadType = 0

    // MARK: - Display

    @AppStorage("ios.touchControls")
    private var touchControls = true

    @AppStorage("ios.showFPS")
    private var showFPS = true

    @AppStorage("ios.widescreen")
    private var widescreen = false

    @AppStorage("ios.widescreenAspect")
    private var widescreenAspect = 1.7777778

    @AppStorage("ios.windowWidth")
    private var windowWidth = 0

    @AppStorage("ios.windowHeight")
    private var windowHeight = 0

    @AppStorage("ios.renderer")
    private var renderer = 0

    @AppStorage("ios.headless")
    private var headless = false

    // MARK: - Performance

    @AppStorage("ios.speed")
    private var speed = 1.0

    @AppStorage("ios.fastForwardSpeed")
    private var fastForwardSpeed = 0.0

    @AppStorage("ios.profilerFramesBetween")
    private var profilerFramesBetween = 0

    @AppStorage("ios.opcodeProfiler")
    private var opcodeProfiler = false

    @AppStorage("ios.metal")
    private var metal = true;

    // MARK: - Debugging

    @AppStorage("ios.debug")
    private var debug = false

    @AppStorage("ios.disassemble")
    private var disassemble = false

    @AppStorage("ios.alwaysLogUnknownFunctions")
    private var alwaysLogUnknownFunctions = false

    @AppStorage("ios.alwaysLogStubbedFunctions")
    private var alwaysLogStubbedFunctions = false

    @AppStorage("ios.disableLogColours")
    private var disableLogColours = false

    @AppStorage("ios.traceFrames")
    private var traceFrames = false

    @AppStorage("ios.traceEventInherited")
    private var traceEventInherited = false

    // MARK: - Printing

    @AppStorage("ios.printRooms")
    private var printRooms = false

    @AppStorage("ios.printObjects")
    private var printObjects = false

    @AppStorage("ios.printShaders")
    private var printShaders = false

    @AppStorage("ios.printDeclaredFunctions")
    private var printDeclaredFunctions = false

    @AppStorage("ios.printUnknownFunctions")
    private var printUnknownFunctions = false

    // MARK: - Frame Control

    @AppStorage("ios.exitAtFrame")
    private var exitAtFrame = -1

    @AppStorage("ios.traceBytecodeAfterFrame")
    private var traceBytecodeAfterFrame = 0

    // MARK: - Random Seed

    @AppStorage("ios.hasSeed")
    private var hasSeed = false

    @AppStorage("ios.seed")
    private var seed = 0

    // MARK: - Input Recording

    @AppStorage("ios.recordInputsPath")
    private var recordInputsPath = ""

    @AppStorage("ios.playbackInputsPath")
    private var playbackInputsPath = ""

    // MARK: - Misc

    @AppStorage("ios.eagerRooms")
    private var eagerRooms = ""

    @AppStorage("ios.dumpJsonFilePattern")
    private var dumpJsonFilePattern = ""

    var body: some View {

        NavigationStack {

            Form {

                // MARK: Loading

                Section("Loading") {

                    Toggle(
                        "Lazy room loading",
                        isOn: $lazyRooms
                    )

                    Toggle(
                        "Lazy texture loading",
                        isOn: $lazyTextures
                    )

                    Toggle(
                        "Lazy audio loading",
                        isOn: $lazyAudio
                    )

                    Picker(
                        "Data.win loading",
                        selection: $loadType
                    ) {
                        Text("Per chunk")
                            .tag(0)

                        Text("Whole file")
                            .tag(1)
                    }
                }

                // MARK: Display

                Section("Display & Controls") {

                    Toggle(
                        "Touch controls",
                        isOn: $touchControls
                    )

                    Toggle(
                        "FPS",
                        isOn: $showFPS
                    )

                    Toggle(
                        "Widescreen",
                        isOn: $widescreen
                    )

                    if widescreen {
                        Picker(
                            "Aspect ratio",
                            selection: $widescreenAspect
                        ) {
                            Text("16:9")
                                .tag(1.7777778)

                            Text("16:10")
                                .tag(1.6)

                            Text("21:9")
                                .tag(2.3333333)

                            Text("4:3")
                                .tag(1.3333333)
                        }
                    }
                }

                // MARK: Window

                Section("Window Size") {

                    Stepper(
                        "Width: \(windowWidth == 0 ? "Auto" : "\(windowWidth)")",
                        value: $windowWidth,
                        in: 0...7680,
                        step: 1
                    )

                    Stepper(
                        "Height: \(windowHeight == 0 ? "Auto" : "\(windowHeight)")",
                        value: $windowHeight,
                        in: 0...4320,
                        step: 1
                    )

                    if windowWidth != 0 || windowHeight != 0 {
                        Button("Reset to Auto") {
                            windowWidth = 0
                            windowHeight = 0
                        }
                    }
                }

                // MARK: Performance

                Section("Performance") {

                    Picker(
                        "Game speed",
                        selection: $speed
                    ) {
                        Text("0.5×")
                            .tag(0.5)

                        Text("1×")
                            .tag(1.0)

                        Text("1.5×")
                            .tag(1.5)

                        Text("2×")
                            .tag(2.0)

                        Text("3×")
                            .tag(3.0)
                    }
                    .pickerStyle(.segmented)

                    

                }

                Section("Graphics") {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(
                            "Metal",
                            isOn: $metal
                        )
                        Text("* Experimental")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("* Graphical glitches may occur.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("* Better performance")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    }
    

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(
                            "OpenGL ES",
                            isOn: Binding(
                                get: { !metal },
                                set: { newValue in metal = !newValue }
                            )
                        )
                        Text("* Legacy - will be removed from iOS soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("* Better compatibility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("* Unless using Simulator, no graphical glitches")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        
                    }
                }

                // MARK: Debugging

                Section("Debugging") {

                    Toggle(
                        "Debug mode",
                        isOn: $debug
                    )

                    Toggle(
                        "Disassemble",
                        isOn: $disassemble
                    )

                    Toggle(
                        "Trace frames",
                        isOn: $traceFrames
                    )

                    Toggle(
                        "Trace inherited events",
                        isOn: $traceEventInherited
                    )

                    Toggle(
                        "Log unknown functions",
                        isOn: $alwaysLogUnknownFunctions
                    )

                    Toggle(
                        "Log stubbed functions",
                        isOn: $alwaysLogStubbedFunctions
                    )

                    Toggle(
                        "Disable log colours",
                        isOn: $disableLogColours
                    )
                }

                // MARK: Printing

                Section("Debug Output") {

                    Toggle(
                        "Print rooms",
                        isOn: $printRooms
                    )

                    Toggle(
                        "Print objects",
                        isOn: $printObjects
                    )

                    Toggle(
                        "Print shaders",
                        isOn: $printShaders
                    )

                    Toggle(
                        "Print declared functions",
                        isOn: $printDeclaredFunctions
                    )

                    Toggle(
                        "Print unknown functions",
                        isOn: $printUnknownFunctions
                    )
                }

                // MARK: Frame Control
                
                #if ENABLE_VM_TRACING
                Section("Frame Control") {

                    Stepper(
                        traceBytecodeAfterFrame <= 0
                            ? "Bytecode tracing: Disabled"
                            : "Trace bytecode after frame \(traceBytecodeAfterFrame)",
                        value: $traceBytecodeAfterFrame,
                        in: 0...1_000_000
                    )

                }

                #endif

            }
            .navigationTitle("Settings")
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button("Reset") {
                        reset()
                    }
                }
            }
        }
    }

    private func reset() {

        // Loading
        lazyRooms = true
        lazyTextures = true
        lazyAudio = true
        loadType = 0

        // Display
        touchControls = true
        widescreen = false
        widescreenAspect = 1.7777778
        windowWidth = 0
        windowHeight = 0
        renderer = 0
        headless = false

        // Performance
        speed = 1.0
        fastForwardSpeed = 0.0
        profilerFramesBetween = 0
        opcodeProfiler = false

        // Debugging
        debug = false
        disassemble = false
        alwaysLogUnknownFunctions = false
        alwaysLogStubbedFunctions = false
        disableLogColours = false
        traceFrames = false
        traceEventInherited = false

        // Printing
        printRooms = false
        printObjects = false
        printShaders = false
        printDeclaredFunctions = false
        printUnknownFunctions = false

        // Frame control
        exitAtFrame = -1
        traceBytecodeAfterFrame = 0

        // Seed
        hasSeed = false
        seed = 0

        // Input
        recordInputsPath = ""
        playbackInputsPath = ""

        // Advanced
        eagerRooms = ""
        dumpJsonFilePattern = ""
    }
}
