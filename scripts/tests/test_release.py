"""Integration tests: actual filesystem effects and actual Mach-O fixtures."""
import hashlib
import os
import plistlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def invoke(script, *args):
    return subprocess.run(["bash", str(ROOT / "scripts" / script), *map(str, args)],
                          cwd=ROOT, capture_output=True, text=True)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        parent = ROOT / "output/releases"
        parent.mkdir(parents=True, exist_ok=True)
        self.temp = Path(tempfile.mkdtemp(prefix="test space ", dir=parent))

    def tearDown(self):
        shutil.rmtree(self.temp)

    def assertFailed(self, result, message):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr)

    def test_build_rejects_existing_or_linked_output_without_mutation(self):
        existing = self.temp / "existing"
        existing.mkdir()
        sentinel = existing / "keep"
        sentinel.write_text("original")
        self.assertFailed(invoke("build-universal.sh", "--work-dir", existing), "already exists")
        link = self.temp / "link"
        link.symlink_to(existing)
        self.assertFailed(invoke("build-universal.sh", "--work-dir", link), "symlink")
        self.assertEqual(sentinel.read_text(), "original")

    def test_build_rejects_outside_release_tree(self):
        self.assertFailed(invoke("build-universal.sh", "--work-dir", ROOT / "dist/new"),
                          "output/releases")

    def test_toolchain_failure_cannot_leave_candidate(self):
        # An invalid toolchain must fail even on machines whose default toolchain works.
        environment = dict(os.environ, DEVELOPER_DIR=str(self.temp / "missing developer"))
        target = self.temp / "incomplete"
        result = subprocess.run(["bash", str(ROOT / "scripts/build-universal.sh"),
                                 "--work-dir", str(target)], env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("toolchain", result.stderr.lower())
        self.assertFalse((target / "bin/BubuDesktop").exists())

    def fixture(self, universal=True, minimum="14.0", return_value=0):
        source = self.temp / "fixture.c"
        source.write_text(f"int main(void) {{ return {return_value}; }}\n")
        outputs = []
        for arch in (["arm64", "x86_64"] if universal else ["arm64"]):
            output = self.temp / arch
            subprocess.run(["xcrun", "clang", "-target", f"{arch}-apple-macos{minimum}",
                            str(source), "-g", "-Wl,-headerpad_max_install_names", "-o", str(output)], check=True, capture_output=True)
            outputs.append(output)
        binary = self.temp / "fixture"
        subprocess.run(["lipo", "-create", *map(str, outputs), "-output", str(binary)],
                       check=True, capture_output=True)
        return binary

    def package(self, binary, destination, *options):
        return invoke("package-release.sh", "--version", "0.4.0-beta.1", "--build", "5",
                      "--bundle-id", "local.yierbubu.release-test", "--binary", binary,
                      "--output", destination, *options)

    def test_beta_zip_roundtrip_preserves_app_and_declares_unnotarized(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires source artwork")
        candidate = self.temp / "beta candidate"
        result = self.package(self.fixture(), candidate, "--unnotarized-beta")
        self.assertEqual(result.returncode, 0, result.stderr)
        app = candidate / "BETA-UNNOTARIZED/YierBubu.app"
        output = self.temp / "beta delivery"
        result = invoke("make-beta-release.sh", app, "--output", output, "--zip-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        archive = output / "YierBubu-macOS-Universal-v0.4.0-beta.1.zip"
        self.assertTrue(archive.is_file())
        extracted = self.temp / "extracted"
        subprocess.run(["ditto", "-x", "-k", str(archive), str(extracted)], check=True)
        copy = extracted / "YierBubu/YierBubu.app"
        self.assertEqual(invoke("verify-release.sh", copy).returncode, 0)
        self.assertEqual(hashlib.sha256((app / "Contents/MacOS/BubuDesktop").read_bytes()).hexdigest(),
                         hashlib.sha256((copy / "Contents/MacOS/BubuDesktop").read_bytes()).hexdigest())
        self.assertIn("未公证", (extracted / "YierBubu/先读我.txt").read_text())
        self.assertTrue((output / "SHA256SUMS.txt").is_file())

    def test_beta_delivery_rejects_internal_candidate(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires source artwork")
        candidate = self.temp / "internal candidate"
        self.assertEqual(self.package(self.fixture(), candidate).returncode, 0)
        output = self.temp / "must not exist"
        self.assertFailed(invoke("make-beta-release.sh", candidate / "INTERNAL/YierBubu.app",
                                 "--output", output, "--zip-only"), "beta")
        self.assertFalse(output.exists())

    def test_beta_permission_identity_separates_versions_and_changed_code(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires artwork")
        identities = []
        for name, version, build, value in [("old", "0.4.0-beta.1", "5", 0),
                                            ("new", "0.4.0-beta.3", "7", 0),
                                            ("rebuilt", "0.4.0-beta.3", "7", 1)]:
            output = self.temp / name
            result = invoke("package-release.sh", "--version", version, "--build", build,
                            "--bundle-id", "local.yierbubu.release-test", "--binary", self.fixture(return_value=value),
                            "--output", output, "--unnotarized-beta")
            self.assertEqual(result.returncode, 0, result.stderr)
            app = output / "BETA-UNNOTARIZED/YierBubu.app"
            info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            identity = info["CFBundleIdentifier"]
            self.assertNotEqual(identity, "local.yierbubu.release-test")
            self.assertEqual(info.get("YierBubuBaseBundleIdentifier"), "local.yierbubu.release-test")
            for arch in ("arm64", "x86_64"):
                signature = subprocess.run(["codesign", "-d", "--verbose=2", "--arch", arch, str(app)],
                                           capture_output=True, text=True, check=True)
                self.assertIn(f"Identifier={identity}\n", signature.stderr)
            identities.append(identity)
        self.assertEqual(len(set(identities)), 3, "Changed code must never reuse an old beta TCC identity")
        duplicate = self.temp / "identical payload elsewhere"
        result = invoke("package-release.sh", "--version", "0.4.0-beta.3", "--build", "7",
                        "--bundle-id", "local.yierbubu.release-test", "--binary", self.temp / "fixture",
                        "--output", duplicate, "--unnotarized-beta")
        self.assertEqual(result.returncode, 0, result.stderr)
        info = plistlib.loads((duplicate / "BETA-UNNOTARIZED/YierBubu.app/Contents/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleIdentifier"], identities[-1], "Output directory must not change permission identity")

    def test_beta_verifier_rejects_legacy_shared_permission_identity(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires artwork")
        output = self.temp / "legacy beta"
        self.assertEqual(self.package(self.fixture(), output, "--unnotarized-beta").returncode, 0)
        app = output / "BETA-UNNOTARIZED/YierBubu.app"
        path = app / "Contents/Info.plist"
        info = plistlib.loads(path.read_bytes())
        info["CFBundleIdentifier"] = "local.yierbubu.release-test"
        path.write_bytes(plistlib.dumps(info))
        subprocess.run(["codesign", "--force", "--sign", "-", "--identifier", info["CFBundleIdentifier"], str(app)],
                       check=True, capture_output=True)
        self.assertFailed(invoke("verify-release.sh", app), "permission identity")

    def test_verifier_rejects_signature_identifier_different_from_bundle(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires artwork")
        output = self.temp / "wrong signing identity"
        self.assertEqual(self.package(self.fixture(), output, "--unnotarized-beta").returncode, 0)
        app = output / "BETA-UNNOTARIZED/YierBubu.app"
        subprocess.run(["codesign", "--force", "--sign", "-", "--identifier", "local.wrong.identity", str(app)],
                       check=True, capture_output=True)
        self.assertFailed(invoke("verify-release.sh", app), "codesign")

    @unittest.skipUnless(os.environ.get("YIERBUBU_TEST_DMG") == "1", "DMG mount check requires desktop execution")
    def test_disk_image_verifier_rejects_missing_applications_link(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires source artwork")
        candidate = self.temp / "dmg candidate"
        self.assertEqual(self.package(self.fixture(), candidate, "--unnotarized-beta").returncode, 0)
        app = candidate / "BETA-UNNOTARIZED/YierBubu.app"
        image = self.temp / "invalid layout"
        image.mkdir()
        subprocess.run(["ditto", str(app), str(image / "YierBubu.app")], check=True)
        dmg = self.temp / "missing-link.dmg"
        subprocess.run(["hdiutil", "create", "-volname", "Beta test", "-srcfolder", str(image),
                        "-format", "UDZO", str(dmg)], check=True, capture_output=True)
        code = "import sys; sys.path.insert(0, sys.argv[1]); from beta import verify_disk_image; verify_disk_image(sys.argv[2], sys.argv[3])"
        result = subprocess.run(["python3", "-c", code, str(ROOT / "scripts/release"), str(dmg), str(app)],
                                capture_output=True, text=True)
        self.assertFailed(result, "Applications")

    def test_package_rejects_thin_binary_and_newer_deployment(self):
        destination = self.temp / "bad thin"
        self.assertFailed(self.package(self.fixture(False), destination), "architectures")
        self.assertFalse(destination.exists())
        destination = self.temp / "bad minimum"
        self.assertFailed(self.package(self.fixture(True, "15.0"), destination), "deployment")
        self.assertFalse(destination.exists())

    def test_package_checks_version_before_creating_output(self):
        destination = self.temp / "invalid"
        result = invoke("package-release.sh", "--version", "bad/version", "--build", "0",
                        "--bundle-id", "local.test", "--binary", "/missing", "--output", destination)
        self.assertFailed(result, "version")
        self.assertFalse(destination.exists())

    def test_real_macho_package_and_tamper_detection(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Default public source excludes character artwork; package integration requires approved assets")
        binary = self.fixture()
        before = hashlib.sha256(binary.read_bytes()).hexdigest()
        destination = self.temp / "valid candidate"
        result = self.package(binary, destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        app = destination / "INTERNAL/YierBubu.app"
        self.assertTrue(app.is_dir())
        self.assertEqual(invoke("verify-release.sh", app).returncode, 0)
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        self.assertEqual(info.get("CFBundleIconFile"), "YierBubu.icns")
        icon = app / "Contents/Resources/YierBubu.icns"
        self.assertTrue(icon.is_file(), "Installer must contain the Finder application icon")
        self.assertEqual(icon.read_bytes()[:4], b"icns")
        self.assertTrue(str(ROOT).encode() not in (app / "Contents/MacOS/BubuDesktop").read_bytes(),
                        "Packaged executable must not retain personal source/object paths")
        self.assertEqual(len(list((app / "Contents/Resources/Layered").iterdir())), 3)
        self.assertEqual(hashlib.sha256(binary.read_bytes()).hexdigest(), before)
        # A label is not a signing identity: even a renamed candidate must be refused.
        signed = destination / "SIGNED-UNNOTARIZED"
        signed.mkdir()
        shutil.move(app, signed / "YierBubu.app")
        app = signed / "YierBubu.app"
        self.assertFailed(invoke("notarize-release.sh", app, "--keychain-profile", "unused"), "Developer ID")
        (app / "Contents/Resources/Layered/compact-paws.png").unlink()
        self.assertFailed(invoke("verify-release.sh", app), "resource")

    def test_verify_rejects_missing_declared_application_icon(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires source artwork")
        candidate = self.temp / "icon removal"
        self.assertEqual(self.package(self.fixture(), candidate).returncode, 0)
        app = candidate / "INTERNAL/YierBubu.app"
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        icon = app / "Contents/Resources" / info.get("CFBundleIconFile", "YierBubu.icns")
        icon.unlink(missing_ok=True)
        self.assertFailed(invoke("verify-release.sh", app), "icon")

    def test_package_never_replaces_existing_directory(self):
        sentinel = self.temp / "keep"
        sentinel.write_text("safe")
        result = self.package(Path("/missing"), self.temp)
        self.assertFailed(result, "already exists")
        self.assertEqual(sentinel.read_text(), "safe")

    def test_verify_rejects_embedded_dependency_without_effective_rpath(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires approved source artwork for package fixture")
        destination = self.temp / "dependency candidate"
        self.assertEqual(self.package(self.fixture(), destination).returncode, 0)
        app = destination / "INTERNAL/YierBubu.app"
        frameworks = app / "Contents/Frameworks"
        libsource = self.temp / "library.c"
        libsource.write_text("int value(void) { return 0; }\n")
        main = self.temp / "dependent.c"
        main.write_text("extern int value(void); int main(void) { return value(); }\n")
        libraries, executables = [], []
        for arch in ["arm64", "x86_64"]:
            library = self.temp / f"{arch}.dylib"
            executable = self.temp / f"{arch}-dependent"
            subprocess.run(["xcrun", "clang", "-target", f"{arch}-apple-macos14.0", "-dynamiclib",
                            str(libsource), "-install_name", "@rpath/libFixture.dylib", "-o", str(library)],
                           check=True, capture_output=True)
            subprocess.run(["xcrun", "clang", "-target", f"{arch}-apple-macos14.0", str(main),
                            str(library), "-o", str(executable)], check=True, capture_output=True)
            libraries.append(library)
            executables.append(executable)
        library = frameworks / "libFixture.dylib"
        executable = app / "Contents/MacOS/BubuDesktop"
        for inputs, output in [(libraries, library), (executables, executable)]:
            subprocess.run(["lipo", "-create", *map(str, inputs), "-output", str(output)], check=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(library)], check=True, capture_output=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True, capture_output=True)
        self.assertFailed(invoke("verify-release.sh", app), "Missing bundled dependency")

    def test_package_repairs_missing_frameworks_rpath_in_intel_slice(self):
        if not (ROOT / "Resources/Layered/compact-scene.png").is_file():
            self.skipTest("Requires approved source artwork for package fixture")
        binary = self.fixture()
        subprocess.run(["install_name_tool", "-add_rpath", "@executable_path/../Frameworks",
                        str(self.temp / "arm64")], check=True, capture_output=True)
        subprocess.run(["lipo", "-create", str(self.temp / "arm64"), str(self.temp / "x86_64"),
                        "-output", str(binary)], check=True, capture_output=True)
        destination = self.temp / "asymmetric"
        result = self.package(binary, destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        executable = destination / "INTERNAL/YierBubu.app/Contents/MacOS/BubuDesktop"
        loads = subprocess.run(["otool", "-arch", "x86_64", "-l", str(executable)],
                               check=True, capture_output=True, text=True).stdout
        self.assertIn("@executable_path/../Frameworks", loads)

    def test_notarize_rejects_shallow_candidate_before_network(self):
        app = ROOT / "output/releases" / (self.temp.name + ".app")
        app.mkdir()
        try:
            self.assertFailed(invoke("notarize-release.sh", app, "--keychain-profile", "unused"), "candidate layout")
            self.assertFalse((ROOT / "output/FINAL").exists())
        finally:
            app.rmdir()

    def test_notarize_rejects_symlinked_ancestor_before_network(self):
        actual = self.temp / "real"
        (actual / "SIGNED-UNNOTARIZED/YierBubu.app").mkdir(parents=True)
        alias = self.temp / "alias"
        alias.symlink_to(actual, target_is_directory=True)
        self.assertFailed(invoke("notarize-release.sh", alias / "SIGNED-UNNOTARIZED/YierBubu.app",
                                 "--keychain-profile", "unused"), "symlink")

    def export_fixture(self):
        repo = Path(tempfile.mkdtemp(prefix="source fixture ", dir=self.temp))
        shutil.copytree(ROOT / "scripts", repo / "scripts", ignore=shutil.ignore_patterns("__pycache__"))
        public = ROOT / "docs/public"
        if public.is_dir():
            shutil.copytree(public, repo / "docs/public")
        else:
            # Public exports intentionally move these documents to their root.
            (repo / "docs/public").mkdir(parents=True)
            for name in ["README.md", "PRIVACY.md", "INSTALL.md", "LICENSE-DECISION.md",
                         "RELEASE-NOTES.md", "THIRD_PARTY_NOTICES.md"]:
                shutil.copy2(ROOT / name, repo / "docs/public" / name)
        shutil.copy2(ROOT / "docs/release-process.md", repo / "docs/release-process.md")
        for name in ["Package.swift", "LICENSE", ".gitignore"]:
            shutil.copy2(ROOT / name, repo / name)
        for name in ["Sources", "Tests", ".github"]:
            (repo / name).mkdir()
        return repo

    def test_export_rejects_linked_source_roots_and_standalone_inputs(self):
        for relative in ["Sources", "docs/public", "Package.swift"]:
            with self.subTest(relative=relative):
                repo = self.export_fixture()
                selected = repo / relative
                external = self.temp / ("external-" + relative.replace("/", "-"))
                if selected.is_dir():
                    shutil.move(selected, external)
                else:
                    shutil.move(selected, external)
                selected.symlink_to(external, target_is_directory=external.is_dir())
                result = subprocess.run(["bash", str(repo / "scripts/export-public-source.sh"),
                                         "--output", str(repo / "output/releases/export")], capture_output=True, text=True)
                self.assertFailed(result, "symlink")
                self.assertFalse((repo / "output/releases/export").exists())
                shutil.rmtree(repo)
                if external.is_dir():
                    shutil.rmtree(external)
                else:
                    external.unlink()

    def test_export_whitelist_with_spaces_and_without_artwork(self):
        destination = self.temp / "public source"
        result = invoke("export-public-source.sh", "--output", destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((destination / "Sources/BubuDesktop/SceneRenderer.swift").exists())
        self.assertTrue((destination / "README.md").exists())
        self.assertTrue((destination / "scripts/release/common.py").exists())
        for forbidden in [".git", "dist", "HandOff261018.md", "Resources/References", "docs/superpowers"]:
            self.assertFalse((destination / forbidden).exists(), forbidden)
        self.assertEqual(list(destination.rglob("*.png")), [])
        self.assertIn("素材", (destination / "README.md").read_text())

    def test_export_never_overwrites_or_follows_link(self):
        link = self.temp / "linked"
        link.symlink_to(self.temp, target_is_directory=True)
        self.assertFailed(invoke("export-public-source.sh", "--output", link), "symlink")
        self.assertFailed(invoke("export-public-source.sh", "--output", self.temp), "already exists")


if __name__ == "__main__":
    unittest.main()
