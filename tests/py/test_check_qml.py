"""lib/check-qml.py: property checks on the repo's own components."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(files):
    with tempfile.TemporaryDirectory() as tmp:
        for name, text in files.items():
            (Path(tmp) / name).parent.mkdir(parents=True, exist_ok=True)
            (Path(tmp) / name).write_text(text)
        r = subprocess.run([sys.executable, str(ROOT / "lib" / "check-qml.py"), tmp], capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr


class CheckQml(unittest.TestCase):
    def test_component_on_unknown_qt_base_is_not_flagged(self):
        rc, out = run({
            "EaseAnim.qml": "import QtQuick\nNumberAnimation {\n    duration: 100\n}\n",
            "Use.qml": "import QtQuick\nItem {\n    Behavior on x { EaseAnim { duration: 50 } }\n}\n",
        })
        self.assertNotIn("has no property", out)

    def test_changed_handler_of_inherited_property_is_allowed(self):
        rc, out = run({
            "Surface.qml": "import QtQuick\nRectangle {\n    property int level: 0\n}\n",
            "Use.qml": "import QtQuick\nItem {\n    Surface { onXChanged: {} onLevelChanged: {} }\n}\n",
        })
        self.assertNotIn("has no property", out)

    def test_typo_on_own_component_is_still_flagged(self):
        rc, out = run({
            "Chip.qml": "import QtQuick\nItem {\n    property string title: \"\"\n}\n",
            "Use.qml": "import QtQuick\nItem {\n    Chip { titel: \"x\" }\n}\n",
        })
        self.assertIn("Chip has no property `titel`", out)


    def test_handler_of_a_property_declared_in_the_same_object_is_allowed(self):
        rc, out = run({
            "Page.qml": "import QtQuick\nItem {\n    property string title: \"\"\n}\n",
            "Use.qml": "import QtQuick\nPage {\n    readonly property string dir: \"x\"\n    onDirChanged: {}\n}\n",
        })
        self.assertNotIn("has no property", out)

    # A type from another directory loads only through an import of that directory —
    # without one Quickshell refuses the whole shell.
    SPRING = "import QtQuick\nNumberAnimation {\n}\n"

    def test_type_from_another_directory_without_import_is_flagged(self):
        rc, out = run({
            "components/SpringAnim.qml": self.SPRING,
            "modules/wall/View.qml": "import QtQuick\nItem {\n    Behavior on y { SpringAnim {} }\n}\n",
        })
        self.assertIn("SpringAnim needs `import qs.components`", out)
        self.assertEqual(rc, 1)

    def test_type_from_another_directory_with_qs_import_is_fine(self):
        rc, out = run({
            "components/SpringAnim.qml": self.SPRING,
            "modules/wall/View.qml": "import QtQuick\nimport qs.components\nItem {\n    Behavior on y { SpringAnim {} }\n}\n",
        })
        self.assertNotIn("needs", out)

    def test_type_through_a_relative_import_or_the_same_directory_is_fine(self):
        rc, out = run({
            "components/SpringAnim.qml": self.SPRING,
            "modules/wall/Tile.qml": "import QtQuick\nItem {\n}\n",
            "modules/wall/View.qml": "import QtQuick\nimport \"../../components\"\nItem {\n    Tile {}\n    Behavior on y { SpringAnim {} }\n}\n",
        })
        self.assertNotIn("needs", out)


    def test_type_through_a_symlinked_qs_directory_is_fine(self):
        # The apps share the shell's directories through symlinks.
        import os
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            (t / "shell/components").mkdir(parents=True)
            (t / "shell/components/SpringAnim.qml").write_text(self.SPRING)
            (t / "apps/settings").mkdir(parents=True)
            os.symlink("../../shell/components", t / "apps/settings/components")
            (t / "apps/settings/shell.qml").write_text("import QtQuick\nimport qs.components\nItem {\n    Behavior on y { SpringAnim {} }\n}\n")
            r = subprocess.run([sys.executable, str(ROOT / "lib" / "check-qml.py"), str(t / "shell"), str(t / "apps/settings")], capture_output=True, text=True)
            self.assertNotIn("needs", r.stdout + r.stderr)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
