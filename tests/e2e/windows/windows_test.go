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

// Package windows runs the end-to-end scenarios of vfox-clang on the Windows
// runner itself, with real vfox 1.1.0. Run it from tests/e2e with
// `go test -v -run TestE2E ./windows` on Windows.
package windows

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/version-fox/vfox-clang/tests/e2e/common"
)

// TestE2E runs every scenario on Windows, with real vfox 1.1.0.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the end-to-end suite runs without -short")
	}
	if runtime.GOOS != "windows" {
		t.Skip("the Windows suite runs on a Windows host")
	}
	root, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("find the plugin root: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "metadata.lua")); err != nil {
		t.Fatalf("%s is not the plugin root: %v", root, err)
	}
	artifacts := common.BuildArtifacts(t, root)
	fake := common.NewFakeGitHub(t)
	common.RunAll(t, NewFactory(), artifacts, fake)
}
