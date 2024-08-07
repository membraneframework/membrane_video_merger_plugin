defmodule Membrane.VideoMerger.Mixfile do
  use Mix.Project

  @version "0.9.1"
  @github_url "https://github.com/membraneframework/membrane_video_merger_plugin"

  def project do
    [
      app: :membrane_video_merger_plugin,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Membrane raw video cutter, merger and cut & merge bin",
      package: package(),

      # docs
      name: "Membrane Video Merger plugin",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      test_coverage: [tool: ExCoveralls, test_task: "test.all"],
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 1.0"},
      {:membrane_raw_video_format, "~> 0.3.0"},
      {:excoveralls, "~> 0.11", only: :test},
      {:membrane_file_plugin, "~> 0.16.0", only: :test},
      {:membrane_h264_plugin, "~> 0.9.0", only: :test},
      {:membrane_h264_ffmpeg_plugin, "~> 0.31.0", only: :test},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane],
      groups_for_modules: [
        CutAndMerge: [~r/^Membrane.VideoCutAndMerge.*/]
      ]
    ]
  end
end
