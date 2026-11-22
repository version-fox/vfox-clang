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
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// manifestPath is the path of the manifest release on GitHub, as the plugin asks for it.
const manifestPath = "/version-fox/vfox-clang/releases/manifest"

// pixiDownloadPrefix is the path under which the plugin asks for pixi's archive.
const pixiDownloadPrefix = "/prefix-dev/pixi/releases/latest/download/"

// FakeGitHub stands in for github.com on the host: it serves the manifest the
// plugin reads and the pixi archive it downloads. A scenario changes what it
// serves before it runs vfox.
type FakeGitHub struct {
	server *httptest.Server

	mu       sync.Mutex
	status   int
	manifest string
	assets   map[string][]byte
}

// NewFakeGitHub starts the fake on 127.0.0.1 and stops it with the test.
func NewFakeGitHub(t *testing.T) *FakeGitHub {
	t.Helper()
	fake := &FakeGitHub{
		status:   http.StatusOK,
		manifest: ManifestPage(),
		assets:   map[string][]byte{},
	}
	fake.server = httptest.NewServer(fake)
	t.Cleanup(fake.server.Close)
	return fake
}

// Port is the port the fake listens on.
func (f *FakeGitHub) Port() int {
	return f.server.Listener.Addr().(*net.TCPAddr).Port
}

// URL is the base URL the plugin reads through GITHUB_URL, as seen from the host.
func (f *FakeGitHub) URL() string {
	return fmt.Sprintf("http://127.0.0.1:%d", f.Port())
}

// SetManifest makes the manifest page answer with status and body.
func (f *FakeGitHub) SetManifest(status int, body string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.status = status
	f.manifest = body
}

// SetAsset makes the pixi archive named asset answer with data.
func (f *FakeGitHub) SetAsset(asset string, data []byte) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.assets[asset] = data
}

// ServeHTTP answers the manifest and the pixi archives, and 404 for the rest.
func (f *FakeGitHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	switch {
	case r.URL.Path == manifestPath:
		w.WriteHeader(f.status)
		_, _ = w.Write([]byte(f.manifest))
	case strings.HasPrefix(r.URL.Path, pixiDownloadPrefix):
		data, ok := f.assets[strings.TrimPrefix(r.URL.Path, pixiDownloadPrefix)]
		if !ok {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(data)
	default:
		http.NotFound(w, r)
	}
}

// ManifestPage is the manifest release's page: the JSON list of versions in a
// <code> block, as GitHub renders it. With no versions it lists the defaults the
// scenarios check against.
func ManifestPage(versions ...string) string {
	if len(versions) == 0 {
		versions = []string{"22.1.3", "22.1.0", "21.1.8"}
	}
	list, _ := json.MarshalIndent(map[string][]string{"conda-forge": versions}, "", "    ")
	return "<html><body><article><pre><code>" + string(list) + "\n</code></pre></article></body></html>"
}

// ClosedPort returns a port on 127.0.0.1 that nothing listens on, for the
// scenario in which the mirror cannot be reached.
func ClosedPort(t *testing.T) int {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	if err := listener.Close(); err != nil {
		t.Fatalf("close listener: %v", err)
	}
	return port
}
