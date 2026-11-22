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

// Package linux runs the end-to-end scenarios of vfox-clang in throwaway Ubuntu
// containers. Run it from tests/e2e with `go test -v -run TestE2E ./linux`.
package linux

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/version-fox/vfox-clang/tests/e2e/common"
)

// TestE2E runs every scenario on Ubuntu 26.04 containers, with real vfox 1.1.0.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the end-to-end suite runs without -short")
	}
	if _, err := exec.LookPath("docker"); err != nil {
		t.Fatalf("the Linux suite needs docker: %v", err)
	}
	root := repoRoot(t)
	image := buildImage(t)
	artifacts := common.BuildArtifacts(t, root)
	fake := common.NewFakeGitHub(t)
	common.RunAll(t, NewFactory(image), artifacts, fake)
}

// repoRoot returns the root of the plugin, found from the package directory
// tests/e2e/linux.
func repoRoot(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("find the plugin root: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "metadata.lua")); err != nil {
		t.Fatalf("%s is not the plugin root: %v", root, err)
	}
	return root
}

// buildImage builds the test image from this package's Dockerfile. The tag
// hashes the Dockerfile, so a changed Dockerfile builds a new image.
func buildImage(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("working directory: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "Dockerfile"))
	if err != nil {
		t.Fatalf("read the Dockerfile: %v", err)
	}
	tag := fmt.Sprintf("vfox-clang-e2e:%x", hashOf(data))
	start := time.Now()
	out, err := exec.Command("docker", "build", "--quiet", "--tag", tag, dir).CombinedOutput()
	if err != nil {
		t.Fatalf("docker build: %v\n%s", err, out)
	}
	t.Logf("image %s ready in %s", strings.TrimSpace(tag), time.Since(start).Round(time.Second))
	return tag
}

// hashOf is a 64-bit FNV-1a hash, enough to tell two Dockerfiles apart.
func hashOf(data []byte) uint64 {
	var hash uint64 = 14695981039346656037
	for _, b := range data {
		hash ^= uint64(b)
		hash *= 1099511628211
	}
	return hash
}
