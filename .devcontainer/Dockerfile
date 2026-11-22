# Copyright 2026 vfox-clang contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The development container of vfox-clang (see docs/e2e.md). It carries the tools
# the checks in .github/workflows use, at the same versions, plus the vfox release
# the offline tests run with. The end-to-end suite starts its containers on the
# host's Docker daemon through the socket that devcontainer.json mounts.

FROM golang:1.27.4

# The Docker CLI only: it drives the host's daemon.
COPY --from=docker:29-cli /usr/local/bin/docker /usr/local/bin/docker

# Keep these versions in step with .github/workflows/lint.yml, license.yml and
# test.yml.
ARG STYLUA_VERSION=2.5.2
ARG LUA_LANGUAGE_SERVER_VERSION=3.19.1
ARG VFOX_VERSION=1.1.0

# Heredocs need BuildKit, which Docker uses by default.
RUN <<EOF
set -o errexit -o nounset -o xtrace
apt-get update
apt-get install --assume-yes --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    zip
rm --recursive --force /var/lib/apt/lists/*
case "$(dpkg --print-architecture)" in
    amd64) stylua_asset=stylua-linux-x86_64.zip; luals_asset="lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-x64.tar.gz"; vfox_dir="vfox_${VFOX_VERSION}_linux_x86_64" ;;
    arm64) stylua_asset=stylua-linux-aarch64.zip; luals_asset="lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-arm64.tar.gz"; vfox_dir="vfox_${VFOX_VERSION}_linux_aarch64" ;;
    *) echo "FAIL unsupported architecture $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 5 --output /tmp/stylua.zip \
    "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/${stylua_asset}"
unzip -q /tmp/stylua.zip -d /usr/local/bin
rm --force /tmp/stylua.zip
curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 5 --output /tmp/luals.tar.gz \
    "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/${luals_asset}"
mkdir --parents /opt/lua-language-server
tar --extract --gzip --file /tmp/luals.tar.gz --directory /opt/lua-language-server
rm --force /tmp/luals.tar.gz
ln --symbolic /opt/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server
curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 5 --output /tmp/vfox.tar.gz \
    "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/${vfox_dir}.tar.gz"
tar --extract --gzip --file /tmp/vfox.tar.gz --directory /usr/local/bin --strip-components=1 "${vfox_dir}/vfox"
rm --force /tmp/vfox.tar.gz
stylua --version
lua-language-server --version
vfox --version
EOF

# The license and workflow checks, at the versions license.yml and lint.yml use.
# A module download can be cut short by the network, and go install does not
# retry it, so each install is tried up to five times.
RUN <<EOF
set -o errexit -o nounset -o xtrace
export GOBIN=/usr/local/bin
retry() {
    attempt=1
    until "$@"; do
        if [ "$attempt" -ge 5 ]; then
            return 1
        fi
        attempt=$((attempt + 1))
        sleep 5
    done
}
retry go install github.com/apache/skywalking-eyes/cmd/license-eye@v0.9.0
retry go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
command -v license-eye actionlint
EOF
