// Copyright 2026 vfox-clang contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package common

import (
	"runtime"
	"strconv"
	"strings"
	"testing"
)

// Factory starts a fresh target for one scenario. It stops the target when the
// test ends.
type Factory func(t *testing.T) Target

// RunAll runs every scenario, each in a fresh target. The scenarios that change
// what GitHub answers use fake, which runs on the host.
func RunAll(t *testing.T, factory Factory, a *Artifacts, fake *FakeGitHub) {
	t.Run("search lists the versions, --no-cache included", func(t *testing.T) {
		scenarioSearch(t, NewSandbox(t, factory(t), a))
	})
	t.Run("HTTP failures name their cause", func(t *testing.T) {
		scenarioHTTPFailures(t, NewSandbox(t, factory(t), a), fake)
	})
	t.Run("a failed install leaves no lock or partial install", func(t *testing.T) {
		scenarioFailedInstall(t, NewSandbox(t, factory(t), a), fake)
	})
	t.Run("install with a space in HOME", func(t *testing.T) {
		scenarioInstall(t, NewSandbox(t, factory(t), a))
	})
	t.Run("a system clang is detected and linked", func(t *testing.T) {
		scenarioDetect(t, NewSandbox(t, factory(t), a))
	})
}

// requireFailure fails the test when a command exited with status 0.
func requireFailure(t *testing.T, result Result, what string) {
	t.Helper()
	if result.Code == 0 {
		t.Fatalf("%s: exit status 0, want a failure\n%s", what, result.Output)
	}
}

// requireNoOutput fails the test when the output has any of the parts.
func requireNoOutput(t *testing.T, result Result, what string, parts ...string) {
	t.Helper()
	for _, part := range parts {
		if strings.Contains(result.Output, part) {
			t.Fatalf("%s: output has %q\n%s", what, part, result.Output)
		}
	}
}

// requireHomeWithSpace guards the premise of the install scenarios: issue #5 only
// shows with a space in HOME.
func requireHomeWithSpace(t *testing.T, s *Sandbox) {
	t.Helper()
	if !strings.Contains(s.Home, " ") {
		t.Fatalf("HOME %q has no space; the scenario needs one", s.Home)
	}
}

// scenarioSearch lists the versions from the real manifest, then does the same
// with `-- --no-cache`, which vfox passes to the plugin only after the --.
func scenarioSearch(t *testing.T, s *Sandbox) {
	s.AddPlugin(t)

	first := s.VfoxRetry(t, nil, "search", "clang")
	requireStatus(t, first, 0, "vfox search clang")
	requireOutput(t, first, "vfox search clang", "Available versions:")
	if len(ParseVersions(first.Output)) == 0 {
		t.Fatalf("vfox search clang listed no version:\n%s", first.Output)
	}

	refreshed := s.VfoxRetry(t, nil, "search", "clang", "--", "--no-cache")
	requireStatus(t, refreshed, 0, "vfox search clang -- --no-cache")
	requireOutput(t, refreshed, "vfox search clang -- --no-cache", "Available versions:")
	if len(ParseVersions(refreshed.Output)) == 0 {
		t.Fatalf("vfox search clang -- --no-cache listed no version:\n%s", refreshed.Output)
	}
}

// scenarioHTTPFailures points the plugin at a mirror that answers wrongly, and
// checks that vfox reports what went wrong (issue #6). Errors are not cached, so
// one sandbox serves all three cases.
func scenarioHTTPFailures(t *testing.T, s *Sandbox, fake *FakeGitHub) {
	s.AddPlugin(t)
	mirror := map[string]string{"GITHUB_URL": fake.URL()}

	fake.SetManifest(404, "Not Found")
	notFound := s.Vfox(t, mirror, "search", "clang")
	requireFailure(t, notFound, "a 404 manifest")
	requireOutput(t, notFound, "a 404 manifest", "Failed to get versions: status 404")
	requireNoOutput(t, notFound, "a 404 manifest", "concatenate")

	fake.SetManifest(200, "<html>the manifest has no list</html>")
	noList := s.Vfox(t, mirror, "search", "clang")
	requireFailure(t, noList, "a manifest without a list")
	requireOutput(t, noList, "a manifest without a list", "the manifest has no version list")

	closed := map[string]string{"GITHUB_URL": "http://127.0.0.1:" + strconv.Itoa(ClosedPort(t))}
	unreachable := s.Vfox(t, closed, "search", "clang")
	requireFailure(t, unreachable, "an unreachable mirror")
	requireOutput(t, unreachable, "an unreachable mirror", "Failed to request the version list")

	fake.SetManifest(200, ManifestPage())
}

// scenarioFailedInstall installs a version whose pixi always fails, then a
// version the manifest does not list. Neither may leave a lock file or a
// partial install behind (issue #4): vfox removes them only when the hooks
// report an error instead of exiting the process.
func scenarioFailedInstall(t *testing.T, s *Sandbox, fake *FakeGitHub) {
	s.AddPlugin(t)
	fake.SetManifest(200, ManifestPage("99.0.0"))
	fake.SetAsset(s.Artifact.PixiAsset, s.Artifact.PixiArchive)
	mirror := map[string]string{"GITHUB_URL": fake.URL()}

	failed := s.Vfox(t, mirror, "install", "--yes", "clang@99.0.0")
	requireFailure(t, failed, "install with a failing pixi")
	requireOutput(t, failed, "install with a failing pixi", "Failed to execute command")
	s.requireNoLeftovers(t, "99.0.0")

	unlisted := s.Vfox(t, mirror, "install", "--yes", "clang@1.0.0")
	requireFailure(t, unlisted, "install of an unlisted version")
	requireOutput(t, unlisted, "install of an unlisted version", "Unsupported version: 1.0.0")
	s.requireNoLeftovers(t, "1.0.0")
}

// requireNoLeftovers fails the test when a failed install of version left its
// installing marker or its version directory behind: vfox then reports the
// version as installed or hides it, and a retry starts from a broken state.
// The .lock file is not checked: vfox keeps it after every install, as an OS
// lock whose holder has exited, so its presence proves nothing.
func (s *Sandbox) requireNoLeftovers(t *testing.T, version string) {
	t.Helper()
	for _, name := range []string{".v-" + version + ".installing", "v-" + version} {
		if s.T.Exists(t, s.T.Join(s.InstallDir(), name)) {
			t.Errorf("after a failed install of %s, %s is still there", version, s.T.Join(s.InstallDir(), name))
		}
	}
}

// scenarioInstall installs the newest version of the real manifest, in a HOME
// with a space, and runs the clang it installed (issue #5).
func scenarioInstall(t *testing.T, s *Sandbox) {
	requireHomeWithSpace(t, s)
	s.AddPlugin(t)

	search := s.VfoxRetry(t, nil, "search", "clang")
	requireStatus(t, search, 0, "vfox search clang")
	versions := ParseVersions(search.Output)
	if len(versions) == 0 {
		t.Fatalf("vfox search clang listed no version:\n%s", search.Output)
	}
	latest := versions[0]

	install := s.VfoxRetry(t, nil, "install", "--yes", "clang@"+latest)
	requireStatus(t, install, 0, "vfox install clang@"+latest)

	clang := s.T.Join(s.InstallDir(), "v-"+latest, "clang-"+latest, "bin", s.T.Exe("clang"))
	version := s.T.Run(t, nil, clang, "--version")
	requireStatus(t, version, 0, clang+" --version")
	requireOutput(t, version, clang+" --version", "clang version "+latest)
}

// scenarioDetect puts a clang where LLVM installs live, then links it with
// `vfox link --detect clang`, as a user with a system LLVM would. Linux looks in
// CONDA_PREFIX, Windows in ProgramFiles, and both are set to a folder of the
// sandbox so the runner's own installs stay out of it.
func scenarioDetect(t *testing.T, s *Sandbox) {
	s.AddPlugin(t)

	var env map[string]string
	var root string
	if runtime.GOOS == "windows" {
		programFiles := s.T.Join(s.Home, "Program Files")
		env = map[string]string{"ProgramFiles": programFiles}
		root = s.T.Join(programFiles, "LLVM")
	} else {
		root = s.T.Join(s.Home, "conda env")
		env = map[string]string{"CONDA_PREFIX": root}
	}
	s.T.Put(t, s.Artifact.Clang, s.T.Join(root, "bin", s.T.Exe("clang")))

	linked := s.Vfox(t, env, "link", "--detect", "clang", "--yes")
	requireStatus(t, linked, 0, "vfox link --detect clang --yes")
	requireOutput(t, linked, "vfox link --detect clang --yes", FakeClangVersion)

	listed := s.Vfox(t, env, "list", "clang")
	requireStatus(t, listed, 0, "vfox list clang")
	requireOutput(t, listed, "vfox list clang", FakeClangVersion)

	again := s.Vfox(t, env, "link", "--detect", "clang", "--yes")
	requireStatus(t, again, 0, "vfox link --detect clang --yes, again")
	requireOutput(t, again, "vfox link --detect clang --yes, again", "No new clang installations found.")
}
