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

package windows

import (
	"bytes"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/version-fox/vfox-clang/tests/e2e/common"
)

// hostVariables are the variables a runner may set that would change what vfox
// does in a scenario. Each scenario sets the ones it needs, and the rest are
// removed.
var hostVariables = []string{
	"GITHUB_URL", "Conda_Forge", "CONDA_PREFIX", "VFOX_HOME", "HOME", "USERPROFILE", "CI",
}

// native is the Windows runner itself, with one directory of its own per
// scenario. The directory is named after the scenario and never reused.
type native struct {
	root string
}

var _ common.Target = (*native)(nil)

// Work is the directory the scenarios put their files in.
func (n *native) Work() string {
	return filepath.Join(n.root, "work")
}

// Home is the HOME vfox runs with. It contains a space, as the path of a real
// user profile often does (issue #5).
func (n *native) Home() string {
	return filepath.Join(n.root, "home with space")
}

// Vfox is the path of the vfox binary the suite copies into the work directory.
func (n *native) Vfox() string {
	return filepath.Join(n.root, "bin", "vfox.exe")
}

// Host is the address of the fake GitHub on this machine.
func (n *native) Host() string {
	return "127.0.0.1"
}

// Join joins path elements with the Windows separator.
func (n *native) Join(elem ...string) string {
	return filepath.Join(elem...)
}

// Exe adds the .exe suffix of Windows programs.
func (n *native) Exe(name string) string {
	return name + ".exe"
}

// Mkdir creates a directory and its parents.
func (n *native) Mkdir(t *testing.T, dir string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", dir, err)
	}
}

// Put copies a file from the host to targetPath, creating its directory.
func (n *native) Put(t *testing.T, hostPath, targetPath string) {
	t.Helper()
	n.Mkdir(t, filepath.Dir(targetPath))
	in, err := os.Open(hostPath)
	if err != nil {
		t.Fatalf("open %s: %v", hostPath, err)
	}
	defer in.Close()
	out, err := os.OpenFile(targetPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		t.Fatalf("create %s: %v", targetPath, err)
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		t.Fatalf("copy %s to %s: %v", hostPath, targetPath, err)
	}
	if err := out.Close(); err != nil {
		t.Fatalf("close %s: %v", targetPath, err)
	}
}

// Exists reports whether path exists.
func (n *native) Exists(t *testing.T, path string) bool {
	t.Helper()
	_, err := os.Stat(path)
	return err == nil
}

// ReadFile returns the content of a file.
func (n *native) ReadFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(data)
}

// Run runs program with args, with env applied over the runner's environment
// after the host variables that would interfere are removed.
func (n *native) Run(t *testing.T, env map[string]string, program string, args ...string) common.Result {
	t.Helper()
	cmd := exec.Command(program, args...)
	cmd.Env = mergedEnvironment(env)
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	err := cmd.Run()
	code := 0
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		code = exitErr.ExitCode()
	} else if err != nil {
		t.Fatalf("run %s: %v", program, err)
	}
	return common.Result{Output: output.String(), Code: code}
}

// mergedEnvironment returns the runner's environment without the host variables
// that interfere, with env added. Windows names are case-insensitive, so the
// comparison ignores case.
func mergedEnvironment(env map[string]string) []string {
	drop := map[string]bool{}
	for _, name := range hostVariables {
		drop[strings.ToUpper(name)] = true
	}
	for name := range env {
		drop[strings.ToUpper(name)] = true
	}
	var merged []string
	for _, pair := range os.Environ() {
		index := strings.Index(pair, "=")
		if index <= 0 {
			continue
		}
		if drop[strings.ToUpper(pair[:index])] {
			continue
		}
		merged = append(merged, pair)
	}
	return append(merged, common.EnvList(env)...)
}

// NewFactory starts a new target for each scenario, in a directory that the
// test removes when it ends. The sandbox copies vfox in.
func NewFactory() common.Factory {
	return func(t *testing.T) common.Target {
		t.Helper()
		target := &native{root: t.TempDir()}
		target.Mkdir(t, target.Work())
		target.Mkdir(t, target.Home())
		return target
	}
}
