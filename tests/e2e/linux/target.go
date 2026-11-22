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

package linux

import (
	"bytes"
	"errors"
	"fmt"
	"os/exec"
	"path"
	"testing"
	"time"

	"github.com/version-fox/vfox-clang/tests/e2e/common"
)

// workDir is where the scenarios put their files in the container.
const workDir = "/e2e"

// container is a throwaway Ubuntu container that vfox runs in. Its Docker name
// is unique to the test, so a leftover from a killed run can be found and removed.
type container struct {
	name string
}

var _ common.Target = (*container)(nil)

// Work is the directory the scenarios own in the container.
func (c *container) Work() string {
	return workDir
}

// Home is the HOME of root in the container, with a space in it (issue #5).
func (c *container) Home() string {
	return "/root/home with space"
}

// Vfox is the path of the vfox binary the suite copies into the container.
func (c *container) Vfox() string {
	return path.Join(workDir, "bin", "vfox")
}

// Host is the address of the fake GitHub: the container shares the host's
// network, so the loopback address of the host is reachable from it.
func (c *container) Host() string {
	return "127.0.0.1"
}

// Join joins path elements with the forward slash of Linux.
func (c *container) Join(elem ...string) string {
	return path.Join(elem...)
}

// Exe adds nothing: Linux programs have no suffix.
func (c *container) Exe(name string) string {
	return name
}

// Profile is empty: on Linux the HOME of the sandbox is the whole profile.
func (c *container) Profile() map[string]string {
	return map[string]string{}
}

// Mkdir creates a directory and its parents in the container.
func (c *container) Mkdir(t *testing.T, dir string) {
	t.Helper()
	if result := c.exec(t, nil, "mkdir", "-p", dir); result.Code != 0 {
		t.Fatalf("mkdir %s: %s", dir, result.Output)
	}
}

// Put copies a host file into the container with docker cp, which keeps its
// mode, so an executable stays executable.
func (c *container) Put(t *testing.T, hostPath, targetPath string) {
	t.Helper()
	c.Mkdir(t, path.Dir(targetPath))
	out, err := exec.Command("docker", "cp", hostPath, c.name+":"+targetPath).CombinedOutput()
	if err != nil {
		t.Fatalf("docker cp %s to %s: %v\n%s", hostPath, targetPath, err, out)
	}
}

// Exists reports whether path exists in the container.
func (c *container) Exists(t *testing.T, target string) bool {
	t.Helper()
	return c.exec(t, nil, "test", "-e", target).Code == 0
}

// ReadFile returns the content of a file in the container.
func (c *container) ReadFile(t *testing.T, target string) string {
	t.Helper()
	result := c.exec(t, nil, "cat", target)
	if result.Code != 0 {
		t.Fatalf("cat %s: %s", target, result.Output)
	}
	return result.Output
}

// Run runs program with args in the container, with env added to its environment.
func (c *container) Run(t *testing.T, env map[string]string, program string, args ...string) common.Result {
	t.Helper()
	return c.exec(t, env, append([]string{program}, args...)...)
}

// exec runs a command in the container through docker exec, with a deadline
// that allows a real clang install.
func (c *container) exec(t *testing.T, env map[string]string, command ...string) common.Result {
	t.Helper()
	args := []string{"exec"}
	for _, pair := range common.EnvList(env) {
		args = append(args, "--env", pair)
	}
	args = append(args, c.name)
	args = append(args, command...)

	cmd := exec.Command("docker", args...)
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	timer := time.AfterFunc(30*time.Minute, func() {
		_ = cmd.Process.Kill()
	})
	defer timer.Stop()
	err := cmd.Run()
	code := 0
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		code = exitErr.ExitCode()
	} else if err != nil {
		t.Fatalf("docker exec %v: %v", command, err)
	}
	return common.Result{Output: output.String(), Code: code}
}

// NewFactory returns the factory that starts a container from image for each
// scenario. The container shares the host's network and is removed with the test.
func NewFactory(image string) common.Factory {
	return func(t *testing.T) common.Target {
		t.Helper()
		name := fmt.Sprintf("vfox-clang-e2e-%d", time.Now().UnixNano())
		out, err := exec.Command("docker", "run", "--detach", "--rm", "--network", "host",
			"--name", name, image, "sleep", "infinity").CombinedOutput()
		if err != nil {
			t.Fatalf("docker run %s: %v\n%s", image, err, out)
		}
		t.Cleanup(func() {
			_ = exec.Command("docker", "rm", "--force", name).Run()
		})
		target := &container{name: name}
		target.Mkdir(t, target.Work())
		target.Mkdir(t, target.Home())
		return target
	}
}
