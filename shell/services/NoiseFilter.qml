pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/*
 * The microphone without the room: RNNoise (noise-suppression-for-voice) in a
 * PipeWire filter-chain, run as its own process. On, it adds a "Noise-free
 * microphone" source and makes it the default, so Discord and the rest pick
 * it up; off, the default goes back to what it was. Remembered across logins
 * (audio.noiseFilter).
 */
Singleton {
    id: root

    readonly property string plugin: "/usr/lib64/ladspa/librnnoise_ladspa.so"
    property bool available: false
    readonly property bool on: Settings.get("audio.noiseFilter", false)
    readonly property string nodeName: "vitrum_mic_clean"
    readonly property var node: Pipewire.nodes.values.find(n => n.name === nodeName) || null
    property string previous: ""

    function set(v) { Settings.set("audio.noiseFilter", !!v); }
    function toggle() { set(!on); }

    Process {
        command: ["sh", "-c", 'for p in /usr/lib64/ladspa /usr/lib/ladspa /usr/local/lib/ladspa; do [ -e "$p/librnnoise_ladspa.so" ] && { echo "$p/librnnoise_ladspa.so"; exit 0; }; done; exit 1']
        running: true
        stdout: StdioCollector { onStreamFinished: { root.available = text.trim().length > 0; if (root.available) root.found = text.trim(); } }
    }
    property string found: plugin

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-rnnoise"
    readonly property string conf:
        'context.properties = { log.level = 0 }\n' +
        'context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert  support.* = support/libspa-support }\n' +
        'context.modules = [\n' +
        '  { name = libpipewire-module-rt args = { nice.level = -11 } flags = [ ifexists nofail ] }\n' +
        '  { name = libpipewire-module-protocol-native }\n' +
        '  { name = libpipewire-module-client-node }\n' +
        '  { name = libpipewire-module-adapter }\n' +
        '  { name = libpipewire-module-filter-chain\n' +
        '    args = {\n' +
        '      node.description = "Noise-free microphone"\n' +
        '      media.name = "Noise-free microphone"\n' +
        '      filter.graph = { nodes = [ { type = ladspa name = rnnoise plugin = "' + found + '" label = noise_suppressor_mono\n' +
        '        control = { "VAD Threshold (%)" = 50.0 "VAD Grace Period (ms)" = 200 "Retroactive VAD Grace (ms)" = 0 } } ] }\n' +
        '      capture.props = { node.name = "capture.vitrum_rnnoise" node.passive = true audio.rate = 48000 }\n' +
        '      playback.props = { node.name = "' + nodeName + '" media.class = Audio/Source audio.rate = 48000 }\n' +
        '    }\n' +
        '  }\n' +
        ']\n'

    Process {
        id: chain
        running: root.on && root.available
        command: ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/vitrum-rnnoise.conf" && PIPEWIRE_CONFIG_DIR="$1" exec pipewire -c vitrum-rnnoise.conf',
                  "_", root.dir, root.conf]
        onRunningChanged: if (!running) root._restore()
    }

    // Once the source exists, it becomes the default; the one it replaced is kept.
    onNodeChanged: if (node && on) {
        const cur = Pipewire.defaultAudioSource;
        if (cur && cur.name !== nodeName) previous = cur.name;
        Pipewire.preferredDefaultAudioSource = node;
    }
    function _restore() {
        if (!previous) return;
        const p = Pipewire.nodes.values.find(n => n.name === previous);
        if (p) Pipewire.preferredDefaultAudioSource = p;
        previous = "";
    }
}
