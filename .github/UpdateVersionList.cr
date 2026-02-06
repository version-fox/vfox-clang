require "http/client"
require "json"
require "option_parser"

def fetchVersionList
  response = HTTP::Client.get "https://github.com/version-fox/vfox-clang/releases/manifest"
  versionJson = response.body.match!(/<code>([\s\S]+)<\/code>/)[1]
  versionList = Hash(String, Array(String)).from_json versionJson
end

def queryLatestClangVersion
  query = "query packageVersions($name: String!, $channelName: String!) {\n  package(name: $name, channelName: $channelName) {\n    versions(limit: 500) {\n      page {\n        version\n      }\n    }\n  }\n}"
  payload = {
    "query" => query,
    "variables" => {
      "channelName" => "conda-forge",
      "name" => "clang",
    },
    "operationName" => "packageVersions",
  }.to_json
  headers = HTTP::Headers{
    "Content-Type" => "application/json",
  }
  response = HTTP::Client.post("https://prefix.dev/api/graphql", headers: headers, body: payload)
  data = JSON.parse(response.body)
  data["data"]["package"]["versions"]["page"].as_a.first["version"].as_s
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
latestClangVersion = queryLatestClangVersion

if vlist["conda-forge"][0] != latestClangVersion
  vlist["conda-forge"].unshift(latestClangVersion)
  puts "Clang has an updated version: #{latestClangVersion}"
  File.open(output, "a") do |file|
    file.puts "```"
    file.puts vlist.to_pretty_json(indent = "    ")
    file.puts "```"
  end
end
