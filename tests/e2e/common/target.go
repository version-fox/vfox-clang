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

// Package common holds the end-to-end scenarios and what every platform shares:
// the artifacts they run with, a fake GitHub, and the target abstraction.
package common

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"testing"
	"time"
)

// Result is the outcome of one command: its combined output and its exit code.
type Result struct {
	Output string
	Code   int
}

// Target is an environment vfox runs in. On Linux it is a throwaway container,
// on Windows the runner itself. Every scenario goes through it, so the same
// checks cover both platforms.
type Target interface {
	// Work is a directory the target owns, where the scenarios put their files.
	Work() string
	// Home is the HOME directory vfox runs with. It contains a space (issue #5).
	Home() string
	// Vfox is the path of the vfox binary inside the target.
	Vfox() string
	// Host is the address that reaches a server listening on the host.
	Host() string
	// Join joins path elements with the target's separator.
	Join(elem ...string) string
	// Exe adds the executable suffix of the target's platform to a program name.
	Exe(name string) string
	// Mkdir creates a directory and its parents inside the target.
	Mkdir(t *testing.T, path string)
	// Put copies a file from the host to targetPath inside the target, creating
	// the parent directories, and keeps the file's mode.
	Put(t *testing.T, hostPath, targetPath string)
	// Exists reports whether path exists inside the target.
	Exists(t *testing.T, path string) bool
	// ReadFile returns the content of the file at path inside the target.
	ReadFile(t *testing.T, path string) string
	// Run runs program with args inside the target. env is added to the target's
	// environment; a key that is already there is replaced.
	Run(t *testing.T, env map[string]string, program string, args ...string) Result
}

// Sandbox is one vfox installation inside a target: HOME, VFOX_HOME and the
// plugin under test. Scenarios run vfox through it, never through the target.
type Sandbox struct {
	T        Target
	Artifact *Artifacts
	Home     string
	VfoxHome string
}

// NewSandbox prepares a sandbox in target: the vfox binary and a fresh HOME that
// contains a space, with VFOX_HOME inside it.
func NewSandbox(t *testing.T, target Target, a *Artifacts) *Sandbox {
	t.Helper()
	home := target.Home()
	target.Mkdir(t, home)
	target.Put(t, a.Vfox, target.Vfox())
	return &Sandbox{
		T:        target,
		Artifact: a,
		Home:     home,
		VfoxHome: target.Join(home, ".vfox"),
	}
}

// PluginDir is where vfox keeps the installed clang plugin.
func (s *Sandbox) PluginDir() string {
	return s.T.Join(s.VfoxHome, "plugin", "clang")
}

// InstallDir is where vfox keeps the installed clang versions, as v-<version>
// directories, and the lock and marker files of an install in progress.
func (s *Sandbox) InstallDir() string {
	return s.T.Join(s.VfoxHome, "cache", "clang")
}

// Env is the environment vfox runs with: HOME, VFOX_HOME and CI, which keeps
// vfox from drawing progress bars. extra is added on top.
func (s *Sandbox) Env(extra map[string]string) map[string]string {
	env := map[string]string{
		"HOME":        s.Home,
		"USERPROFILE": s.Home,
		"VFOX_HOME":   s.VfoxHome,
		"CI":          "1",
	}
	for key, value := range extra {
		env[key] = value
	}
	return env
}

// Vfox runs vfox with args in the sandbox, with extra added to its environment.
func (s *Sandbox) Vfox(t *testing.T, extra map[string]string, args ...string) Result {
	t.Helper()
	return s.T.Run(t, s.Env(extra), s.T.Vfox(), args...)
}

// retryAttempts is how many times a network command runs before the scenario
// gives up. A download from GitHub or conda-forge can be cut short by the network
// in between, and a second try usually gets the whole file.
const retryAttempts = 5

// VfoxRetry is Vfox for a command that touches the network: a failure is tried
// again, up to retryAttempts times, with a longer wait each time.
func (s *Sandbox) VfoxRetry(t *testing.T, extra map[string]string, args ...string) Result {
	t.Helper()
	var result Result
	for attempt := 1; attempt <= retryAttempts; attempt++ {
		result = s.Vfox(t, extra, args...)
		if result.Code == 0 {
			return result
		}
		if attempt < retryAttempts {
			t.Logf("attempt %d of vfox %s failed with status %d; retrying", attempt, strings.Join(args, " "), result.Code)
			time.Sleep(time.Duration(attempt*15) * time.Second)
		}
	}
	return result
}

// AddPlugin installs the plugin under test from the zip the artifacts built.
func (s *Sandbox) AddPlugin(t *testing.T) {
	t.Helper()
	s.T.Put(t, s.Artifact.Plugin, s.T.Join(s.T.Work(), "clang.zip"))
	result := s.Vfox(t, nil, "add", "--source", s.T.Join(s.T.Work(), "clang.zip"))
	requireStatus(t, result, 0, "vfox add")
}

var listedVersion = regexp.MustCompile(`(?m)^\s+-\s+(\d+\.\d+\.\d+)`)

// ParseVersions returns the versions `vfox search` listed, in the order printed.
func ParseVersions(output string) []string {
	var versions []string
	for _, match := range listedVersion.FindAllStringSubmatch(output, -1) {
		versions = append(versions, match[1])
	}
	return versions
}

// requireStatus fails the test, with the output, when a command did not exit
// with the wanted status.
func requireStatus(t *testing.T, result Result, want int, what string) {
	t.Helper()
	if result.Code != want {
		t.Fatalf("%s: exit status %d, want %d\n%s", what, result.Code, want, result.Output)
	}
}

// requireOutput fails the test when the output lacks each of the wanted parts.
func requireOutput(t *testing.T, result Result, what string, parts ...string) {
	t.Helper()
	for _, part := range parts {
		if !strings.Contains(result.Output, part) {
			t.Fatalf("%s: output lacks %q\n%s", what, part, result.Output)
		}
	}
}

// sortedKeys returns the keys of a map in order, so commands are reproducible.
func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

// EnvList renders env as KEY=VALUE pairs in a fixed order.
func EnvList(env map[string]string) []string {
	var list []string
	for _, key := range sortedKeys(env) {
		list = append(list, fmt.Sprintf("%s=%s", key, env[key]))
	}
	return list
}
