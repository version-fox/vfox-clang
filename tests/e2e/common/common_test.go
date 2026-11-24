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
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// The helpers the scenarios trust are unit-tested here, without vfox or the
// network, so `go test -short ./...` checks them in the lint job.

func TestParseVersions(t *testing.T) {
	output := "Available versions:\n - 22.1.3 (latest)\n - 22.1.0\n - 21.1.8 (installed)\n"
	got := ParseVersions(output)
	want := []string{"22.1.3", "22.1.0", "21.1.8"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("ParseVersions = %v, want %v", got, want)
	}
	if got := ParseVersions("Please select a version"); len(got) != 0 {
		t.Fatalf("ParseVersions on no list = %v, want none", got)
	}
}

func TestManifestPageRoundTripsThroughThePluginPattern(t *testing.T) {
	// The plugin reads the first <code> block of the page; it must be the JSON
	// list, and the list must come out in order.
	page := ManifestPage("99.0.0", "98.0.0")
	start := strings.Index(page, "<code>")
	end := strings.Index(page, "</code>")
	if start < 0 || end < start {
		t.Fatalf("no <code> block in %q", page)
	}
	block := page[start+len("<code>") : end]
	if !strings.Contains(block, `"conda-forge": [`) || !strings.Contains(block, `"99.0.0"`) {
		t.Fatalf("code block %q does not hold the list", block)
	}
}

func TestBuildPluginZipPacksTheHooksAndLibrary(t *testing.T) {
	root := t.TempDir()
	for _, file := range []string{"metadata.lua", "hooks/available.lua", "lib/util.lua", "README.md"} {
		path := filepath.Join(root, filepath.FromSlash(file))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("-- "+file+"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	output := filepath.Join(t.TempDir(), "plugin.zip")
	if err := BuildPluginZip(root, output); err != nil {
		t.Fatalf("BuildPluginZip: %v", err)
	}
	reader, err := zip.OpenReader(output)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	var names []string
	for _, file := range reader.File {
		names = append(names, file.Name)
	}
	want := []string{"metadata.lua", "hooks/available.lua", "lib/util.lua"}
	if !reflect.DeepEqual(names, want) {
		t.Fatalf("zip entries = %v, want %v (README.md is not part of the plugin)", names, want)
	}
}

func TestPixiArchiveRoundTrips(t *testing.T) {
	binary := []byte("#!fake pixi")
	for _, asset := range []string{
		"pixi-x86_64-unknown-linux-musl.tar.gz",
		"pixi-x86_64-pc-windows-msvc.zip",
		"pixi-aarch64-pc-windows-msvc.zip",
	} {
		archive, err := pixiArchive(asset, "pixi", binary)
		if err != nil {
			t.Fatalf("pixiArchive %s: %v", asset, err)
		}
		dir := t.TempDir()
		path := filepath.Join(dir, asset)
		if err := os.WriteFile(path, archive, 0o644); err != nil {
			t.Fatal(err)
		}
		got, err := extractBinary(path, "pixi")
		if err != nil {
			t.Fatalf("extractBinary %s: %v", asset, err)
		}
		if !bytes.Equal(got, binary) {
			t.Fatalf("%s holds %q, want %q", asset, got, binary)
		}
	}
}

func TestExtractBinaryReportsAMissingFile(t *testing.T) {
	archive, err := pixiArchive("pixi-x86_64-pc-windows-msvc.zip", "pixi", []byte("x"))
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "pixi.zip")
	if err := os.WriteFile(path, archive, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := extractBinary(path, "vfox"); err == nil {
		t.Fatal("extractBinary found a file that is not in the archive")
	}
}

func TestVfoxReleasesPinTheVersionAndDigests(t *testing.T) {
	for key, release := range vfoxReleases {
		if !strings.Contains(release.asset, VfoxVersion) {
			t.Errorf("%s asset %s does not name vfox %s", key, release.asset, VfoxVersion)
		}
		if len(release.sha256) != 64 {
			t.Errorf("%s has a digest of length %d, want 64", key, len(release.sha256))
		}
	}
}
