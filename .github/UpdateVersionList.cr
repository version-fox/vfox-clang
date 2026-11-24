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

require "http/client"
require "json"
require "option_parser"

# The conda subdirs of the platforms the plugin installs clang on. The manifest holds, under each of
# them, the versions of the conda-forge list that conda-forge publishes for that subdir.
SUBDIRS = %w(linux-64 linux-aarch64 osx-64 osx-arm64 win-64 win-arm64)

# The rows the versions query returns per page.
PAGE_SIZE = 50

def fetchVersionList
  response = HTTP::Client.get "https://github.com/version-fox/vfox-clang/releases/manifest"
  versionJson = response.body.match!(/<code>([\s\S]+?)<\/code>/)[1]
  versionList = Hash(String, Array(String)).from_json versionJson
end

# Returns every version of clang on conda-forge, newest first, each with the platforms it is published for.
def queryVersions : Array({String, Array(String)})
  query = "query packageVersions($name: String!, $channelName: String!, $limit: Int!, $page: Int!) {\n  package(name: $name, channelName: $channelName) {\n    versions(limit: $limit, page: $page) {\n      totalCount\n      page {\n        version\n        platforms\n      }\n    }\n  }\n}"
  headers = HTTP::Headers{
    "Content-Type" => "application/json",
  }
  versions = [] of {String, Array(String)}
  page = 0
  loop do
    payload = {
      "query" => query,
      "variables" => {
        "channelName" => "conda-forge",
        "name" => "clang",
        "limit" => PAGE_SIZE,
        "page" => page,
      },
      "operationName" => "packageVersions",
    }.to_json
    response = HTTP::Client.post("https://prefix.dev/api/graphql", headers: headers, body: payload)
    raise "prefix.dev answered #{response.status_code}" unless response.status_code == 200
    result = JSON.parse(response.body)["data"]["package"]["versions"]
    rows = result["page"].as_a
    rows.each do |row|
      platforms = (row["platforms"]?.try(&.as_a?) || [] of JSON::Any).map(&.as_s)
      versions << {row["version"].as_s, platforms}
    end
    page += 1
    break if rows.empty? || versions.size >= result["totalCount"].as_i || page >= 20
  end
  versions
end

output = "manifest.md"

OptionParser.parse do |parser|
  parser.banner = "Usage: #{Path[Process.executable_path.not_nil!].stem} [options]"
  parser.on("-o PATH", "--output PATH", "Specify the output path") { |path| output = path }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

vlist = fetchVersionList
before = vlist.to_pretty_json("    ")

versions = queryVersions
if versions.empty?
  STDERR.puts "ERROR: prefix.dev lists no version of clang"
  exit(1)
end
latestClangVersion = versions.first[0]
platforms = versions.to_h
conda = vlist["conda-forge"]

# Every version of the list needs its platforms. One without them would drop out of the platform
# lists unnoticed, so the run stops and publishes nothing.
missing = conda.reject { |version| platforms.has_key?(version) }
unless missing.empty?
  STDERR.puts "ERROR: prefix.dev has no platforms for #{missing.join(", ")}"
  exit(1)
end

if conda[0] != latestClangVersion
  conda.unshift(latestClangVersion)
  puts "Clang has an updated version: #{latestClangVersion}"
end

SUBDIRS.each do |subdir|
  listed = conda.select { |version| platforms[version].includes?(subdir) }
  if listed.empty?
    STDERR.puts "ERROR: no version of the list is published for #{subdir}"
    exit(1)
  end
  vlist[subdir] = listed
end

# The file is written only when the manifest changes, which is what the workflow checks for.
if vlist.to_pretty_json("    ") != before
  File.open(output, "w") do |file|
    file.puts "```"
    file.puts vlist.to_pretty_json("    ")
    file.puts "```"
  end
end
