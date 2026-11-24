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
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

// VfoxVersion is the vfox release the suites run against: the one the unit
// tests and the Lua hooks are checked with (see docs/e2e.md).
const VfoxVersion = "1.1.0"

// downloadAttempts bounds how often the pinned vfox archive is downloaded when
// the download is cut short or its digest does not match.
const downloadAttempts = 5

// vfoxRelease is one archive of the pinned vfox release, with its SHA-256 as
// published in the release's checksums.txt.
type vfoxRelease struct {
	asset  string
	sha256 string
	binary string
}

var vfoxReleases = map[string]vfoxRelease{
	"linux/amd64": {
		asset:  "vfox_" + VfoxVersion + "_linux_x86_64.tar.gz",
		sha256: "3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4",
		binary: "vfox",
	},
	"windows/amd64": {
		asset:  "vfox_" + VfoxVersion + "_windows_x86_64.zip",
		sha256: "1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a",
		binary: "vfox.exe",
	},
	"windows/arm64": {
		asset:  "vfox_" + VfoxVersion + "_windows_aarch64.zip",
		sha256: "67bf5c8b3bde5c1b3fc06dcaa460db9bb1dc9fc587b467d1dc96205377767465",
		binary: "vfox.exe",
	},
}

// pixiAssets names pixi's release archive for each platform the suites run on.
var pixiAssets = map[string]string{
	"linux/amd64":   "pixi-x86_64-unknown-linux-musl.tar.gz",
	"windows/amd64": "pixi-x86_64-pc-windows-msvc.zip",
	"windows/arm64": "pixi-aarch64-pc-windows-msvc.zip",
}

// Artifacts are the files the scenarios put into a target.
type Artifacts struct {
	// Vfox is the vfox binary of the pinned release.
	Vfox string
	// Plugin is the zip of the plugin working tree.
	Plugin string
	// Clang is a program that answers `--version` the way clang does, for the
	// system-install scenario. Its version is FakeClangVersion.
	Clang string
	// Pixi is a program that always fails, put in the archive pixi comes in.
	Pixi string
	// PixiAsset is the name of pixi's archive for the platform.
	PixiAsset string
	// PixiArchive is that archive, holding Pixi as the pixi executable.
	PixiArchive []byte
}

// FakeClangVersion is the version the fake clang reports. It is unlike any
// real release, so it never collides with a clang the runner has installed.
const FakeClangVersion = "99.1.2"

const fakeClangSource = `package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--version" {
		fmt.Println("clang version ` + FakeClangVersion + ` (fake)")
		return
	}
	fmt.Fprintln(os.Stderr, "fake clang: only --version is supported")
	os.Exit(2)
}
`

const fakePixiSource = `package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "fake pixi: this build always fails")
	os.Exit(1)
}
`

// Platform returns the key of the running platform, such as linux/amd64, and
// skips the test when the suites do not cover it.
func Platform(t *testing.T) string {
	t.Helper()
	key := runtime.GOOS + "/" + runtime.GOARCH
	if _, ok := vfoxReleases[key]; !ok {
		t.Skipf("the end-to-end suites do not cover %s", key)
	}
	return key
}

// BuildArtifacts builds everything a scenario needs for the running platform.
// repoRoot is the root of the plugin, the directory with metadata.lua.
func BuildArtifacts(t *testing.T, repoRoot string) *Artifacts {
	t.Helper()
	key := Platform(t)
	dir := t.TempDir()

	a := &Artifacts{
		Plugin:    filepath.Join(dir, "clang-plugin.zip"),
		Clang:     filepath.Join(dir, exeName("clang")),
		Pixi:      filepath.Join(dir, exeName("pixi")),
		PixiAsset: pixiAssets[key],
	}
	if err := BuildPluginZip(repoRoot, a.Plugin); err != nil {
		t.Fatalf("pack the plugin: %v", err)
	}
	a.Vfox = DownloadVfox(t, key)
	buildGo(t, fakeClangSource, a.Clang)
	buildGo(t, fakePixiSource, a.Pixi)

	binary, err := os.ReadFile(a.Pixi)
	if err != nil {
		t.Fatalf("read the fake pixi: %v", err)
	}
	a.PixiArchive, err = pixiArchive(a.PixiAsset, exeName("pixi"), binary)
	if err != nil {
		t.Fatalf("pack the fake pixi: %v", err)
	}
	return a
}

// exeName adds .exe on Windows, where the suites build programs for the host.
func exeName(name string) string {
	if runtime.GOOS == "windows" {
		return name + ".exe"
	}
	return name
}

// buildGo compiles one Go source file into output, statically and for the host.
func buildGo(t *testing.T, source, output string) {
	t.Helper()
	src := filepath.Join(t.TempDir(), "main.go")
	if err := os.WriteFile(src, []byte(source), 0o600); err != nil {
		t.Fatalf("write %s: %v", src, err)
	}
	cmd := exec.Command("go", "build", "-trimpath", "-o", output, src)
	cmd.Env = append(os.Environ(), "CGO_ENABLED=0")
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("go build %s: %v\n%s", output, err, out)
	}
}

// BuildPluginZip packs metadata.lua, hooks/ and lib/ of the plugin into a zip,
// with names relative to the plugin root, as `vfox add --source` expects.
func BuildPluginZip(repoRoot, output string) error {
	entries := []string{"metadata.lua"}
	for _, dir := range []string{"hooks", "lib"} {
		matches, err := filepath.Glob(filepath.Join(repoRoot, dir, "*.lua"))
		if err != nil {
			return err
		}
		for _, match := range matches {
			entries = append(entries, dir+"/"+filepath.Base(match))
		}
	}

	var buf bytes.Buffer
	writer := zip.NewWriter(&buf)
	for _, entry := range entries {
		data, err := os.ReadFile(filepath.Join(repoRoot, filepath.FromSlash(entry)))
		if err != nil {
			return err
		}
		out, err := writer.Create(entry)
		if err != nil {
			return err
		}
		if _, err := out.Write(data); err != nil {
			return err
		}
	}
	if err := writer.Close(); err != nil {
		return err
	}
	return os.WriteFile(output, buf.Bytes(), 0o644)
}

// DownloadVfox returns the path of the pinned vfox binary for key, downloaded
// into the user cache and checked against its SHA-256. VFOX_BIN, when set,
// names a binary to use instead, for a local run.
func DownloadVfox(t *testing.T, key string) string {
	t.Helper()
	if override := os.Getenv("VFOX_BIN"); override != "" {
		return override
	}
	release, ok := vfoxReleases[key]
	if !ok {
		t.Fatalf("no vfox release for %s", key)
	}
	cache, err := os.UserCacheDir()
	if err != nil {
		cache = os.TempDir()
	}
	dir := filepath.Join(cache, "vfox-clang-e2e", "vfox-"+VfoxVersion)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("create %s: %v", dir, err)
	}
	archive := filepath.Join(dir, release.asset)
	binary := filepath.Join(dir, release.binary)
	if _, err := os.Stat(binary); err == nil && archiveMatches(archive, release.sha256) {
		return binary
	}

	url := fmt.Sprintf("https://github.com/version-fox/vfox/releases/download/v%s/%s", VfoxVersion, release.asset)
	// A download from GitHub can be cut short, and then the checksum does not
	// match: that download is tried again, up to downloadAttempts times.
	var lastErr error
	for attempt := 1; attempt <= downloadAttempts; attempt++ {
		lastErr = download(url, archive)
		if lastErr == nil && !archiveMatches(archive, release.sha256) {
			lastErr = fmt.Errorf("checksum of %s does not match the pinned digest", release.asset)
		}
		if lastErr == nil {
			break
		}
		t.Logf("download of vfox %s, attempt %d of %d: %v", release.asset, attempt, downloadAttempts, lastErr)
		_ = os.Remove(archive)
		time.Sleep(time.Duration(attempt*5) * time.Second)
	}
	if lastErr != nil {
		t.Fatalf("download vfox: %v", lastErr)
	}
	data, err := extractBinary(archive, release.binary)
	if err != nil {
		t.Fatalf("extract vfox: %v", err)
	}
	if err := os.WriteFile(binary, data, 0o755); err != nil {
		t.Fatalf("write vfox: %v", err)
	}
	return binary
}

// archiveMatches reports whether the archive exists and has the wanted SHA-256.
func archiveMatches(archive, want string) bool {
	data, err := os.ReadFile(archive)
	return err == nil && sha256Hex(data) == want
}

func download(url, output string) error {
	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET %s: status %d", url, resp.StatusCode)
	}
	file, err := os.Create(output)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = io.Copy(file, resp.Body)
	return err
}

func fileSHA256(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return sha256Hex(data)
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

// extractBinary returns the content of the file named binary in a vfox archive,
// a .tar.gz or a .zip, wherever the archive keeps it.
func extractBinary(archive, binary string) ([]byte, error) {
	if strings.HasSuffix(archive, ".zip") {
		reader, err := zip.OpenReader(archive)
		if err != nil {
			return nil, err
		}
		defer reader.Close()
		for _, file := range reader.File {
			if path.Base(file.Name) == binary {
				in, err := file.Open()
				if err != nil {
					return nil, err
				}
				defer in.Close()
				return io.ReadAll(in)
			}
		}
		return nil, fmt.Errorf("%s not in %s", binary, archive)
	}
	raw, err := os.ReadFile(archive)
	if err != nil {
		return nil, err
	}
	gz, err := gzip.NewReader(bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	reader := tar.NewReader(gz)
	for {
		header, err := reader.Next()
		if err == io.EOF {
			return nil, fmt.Errorf("%s not in %s", binary, archive)
		}
		if err != nil {
			return nil, err
		}
		if header.Typeflag == tar.TypeReg && path.Base(header.Name) == binary {
			return io.ReadAll(reader)
		}
	}
}

// pixiArchive wraps a program into the archive pixi's release has for the
// platform: a .tar.gz with the program at its top for Linux, a .zip for Windows.
func pixiArchive(asset, program string, binary []byte) ([]byte, error) {
	var buf bytes.Buffer
	if strings.HasSuffix(asset, ".zip") {
		writer := zip.NewWriter(&buf)
		header := &zip.FileHeader{Name: program, Method: zip.Deflate}
		header.SetMode(0o755)
		out, err := writer.CreateHeader(header)
		if err != nil {
			return nil, err
		}
		if _, err := out.Write(binary); err != nil {
			return nil, err
		}
		if err := writer.Close(); err != nil {
			return nil, err
		}
		return buf.Bytes(), nil
	}
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	if err := tw.WriteHeader(&tar.Header{Name: program, Mode: 0o755, Size: int64(len(binary)), Typeflag: tar.TypeReg}); err != nil {
		return nil, err
	}
	if _, err := tw.Write(binary); err != nil {
		return nil, err
	}
	if err := tw.Close(); err != nil {
		return nil, err
	}
	if err := gz.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
