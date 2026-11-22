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

# The image the Linux suite runs vfox in. It holds nothing but the CA bundle:
# vfox, pixi, the plugin and the fake programs are copied in by the suite, so
# the same image serves every scenario and nothing installed by one leaks into
# another, since each scenario gets a container of its own.
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends ca-certificates; \
    rm --recursive --force /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
