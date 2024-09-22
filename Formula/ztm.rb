class Ztm < Formula
  desc "Zerto Trust Mesh (ZTM) is open-source software for decentralized HTTP/2 tunnels"
  homepage "https://github.com/flomesh-io/ztm"
  url "https://github.com/flomesh-io/ztm.git", tag: "v0.2.0"
  license "Apache-2.0"

  depends_on "cmake" => :build
  depends_on "node" => :build
  depends_on "openssl@3" => :build

  def install
    node_version = `node -v`.strip
    major_version = node_version.split(".")[0].delete_prefix("v").to_i
    odie "Node.js version 16 or later is required. Detected: #{node_version}" if major_version < 16

    openssl = Formula["openssl@3"]
    clang = `xcrun --find clang`.chomp
    clangpp = `xcrun --find clang++`.chomp

    cd "gui" do
      system "npm", "install", *std_npm_args(only: :build)
      system "npm", "run", "build"
      # system "npm", "run", "build:apps"
      system "npm", "run", "build:tunnel"
      system "npm", "run", "build:proxy"
      system "npm", "run", "build:script"
    end

    system "git", "submodule", "update", "--init"

    cd "pipy" do
      system "npm", "install", *std_npm_args(only: :build)
    end

    version = ENV["ZTM_VERSION"] || `git describe --abbrev=0 --tags`.strip
    commit = `git log -1 --format=%H`.strip
    commit_date = `git log -1 --format=%cD`.strip

    version_json = <<~EOS
      {
        "version": "#{version}",
        "commit": "#{commit}",
        "date": "#{commit_date}"
      }
    EOS

    (buildpath/"cli/version.json").write version_json
    (buildpath/"agent/version.json").write version_json

    File.write("version.env", <<~EOS)
      VERSION="#{version}"
      COMMIT="#{commit}"
      COMMIT_DATE="#{commit_date}"
    EOS

    mkdir "pipy/build" do
      cmake_args = std_cmake_args + [
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_C_COMPILER=#{clang}",
        "-DCMAKE_CXX_COMPILER=#{clangpp}",
        "-DPIPY_GUI=OFF",
        "-DPIPY_OPENSSL=#{openssl.opt_prefix}",
        "-DCMAKE_CXX_FLAGS=-stdlib=libc++",
        "-DPIPY_CODEBASES=ON",
        "-DPIPY_CUSTOM_CODEBASES=ztm/ca:../ca,ztm/hub:../hub,ztm/agent:../agent,ztm/cli:../cli",
        "-DPIPY_DEFAULT_OPTIONS='repo://ztm/cli --args'",
      ]

      system "cmake", "..", *cmake_args
      system "make", "-j"
    end

    bin.install "pipy/bin/pipy" => "ztm"
  end

  test do
    system "#{bin}/ztm", "--version"
  end
end
