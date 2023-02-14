defmodule Rivet.Mix.Common do
  import Transmogrify
  require Logger

  @moduledoc """
  Common calls across mix tasks
  """

  # @switch_info [
  #   model: [default: true],
  #   db: [default: true],
  #   migration: [default: true],
  #   test: [default: true],
  #   loader: [default: false],
  #   seeds: [default: false],
  #   graphql: [default: false],
  #   resolver: [default: false],
  #   rest: [default: false],
  #   cache: [default: false]
  # ]
  #
  # @defaults Enum.reduce(@switch_info, %{}, fn {k, opts}, acc ->
  #             if Keyword.has_key?(opts, :default) do
  #               Map.put(acc, k, opts[:default])
  #             else
  #               acc
  #             end
  #           end)
  #           |> Map.to_list()

  @switches [
    lib_dir: [:string, :keep],
    mod_dir: [:string, :keep],
    test_dir: [:string, :keep],
    app_base: [:string, :keep],
    #      order: [:integer, :keep],
    model: :boolean
    #      db: :boolean,
    #      migration: :boolean,
    #      loader: :boolean,
    #      seeds: :boolean,
    #      graphql: :boolean,
    #      resolver: :boolean,
    #      rest: :boolean,
    #      cache: :boolean,
    #      test: :boolean
  ]

  # @aliases [
  #   m: :model,
  #   d: :db,
  #   l: :loader,
  #   s: :seeds,
  #   g: :graphql,
  #   c: :cache,
  #   t: :test
  # ]

  def parse_options(args, switches, aliases \\ []),
    do: OptionParser.parse(args, strict: @switches ++ switches, aliases: aliases)

  def getconf(key, opts, conf, default), do: opts[key] || conf[key] || default

  def cleandir(path) do
    (Path.split(path) |> Path.join()) <> "/"
  end

  # amazing that elixir still suffers with built-in time formatting; I don't
  # want to bring in a third-party lib, so just use posix time for now
  # is there something native to elixir that allows me to get this datestamp
  # in local system timezone without jumping through a bunch of hoops?
  def datestamp() do
    case System.cmd("date", ["+%0Y%0m%0d%0H%0M%0S"]) do
      {ts, 0} -> String.trim(ts)
    end
  end

  def maxlen_in(list, func \\ & &1),
    do: Enum.reduce(list, 0, fn i, x -> max(String.length(func.(i)), x) end)

  def as_module(name), do: "Elixir.#{modulename(name)}" |> String.to_atom()

  def module_extend(parent, mod), do: as_module("#{modulename(parent)}.#{modulename(mod)}")

  def module_pop(mod),
    do: String.split("#{mod}", ".") |> Enum.slice(0..-2) |> Enum.join(".") |> as_module()

  def pad(s, w, fill \\ "0")
  def pad(s, w, fill) when is_binary(s) and w < 0, do: String.pad_trailing(s, abs(w), fill)
  def pad(s, w, fill) when is_binary(s), do: String.pad_leading(s, w, fill)
  def pad(s, w, fill) when w < 0, do: String.pad_trailing("#{s}", abs(w), fill)
  def pad(s, w, fill), do: String.pad_leading("#{s}", w, fill)

  def option_configs(opts) do
    config = Mix.Project.config()
    uconf = config[:rivet] || []
    app = config[:app] || :APP_MISSING
    libdir = getconf(:lib_dir, opts, uconf, "./lib/") |> cleandir()
    testdir = getconf(:test_dir, opts, uconf, "./test/") |> cleandir()
    moddir = getconf(:mod_dir, opts, uconf, "#{app}") |> cleandir()

    with {:ok, modpath, testpath} <- get_paths(moddir, libdir, testdir) do
      {:ok,
       %{
         conf: config,
         uconf: uconf,
         app: app,
         libdir: libdir,
         moddir: moddir,
         modpath: modpath,
         testdir: testdir,
         testpath: testpath,
         base: modulename(getconf(:app_base, opts, uconf, "#{app}"))
       }, opts}
    end
  end

  def get_paths(moddir, libdir, testdir) do
    modpath = Path.join([libdir, moddir])

    if File.dir?(modpath) do
      {:ok, modpath, Path.join([testdir, moddir])}
    else
      {:error,
       "Folder #{modpath} doesn't exist (try: --mod-dir=#{moddir} or --lib-dir=#{libdir})"}
    end
  end

  def nodot(path) do
    case Path.split(path) do
      ["." | rest] -> rest
      rest -> rest
    end
  end

  def task_cmd(module) do
    case to_string(module) do
      "Elixir.Mix.Tasks." <> rest -> String.downcase(rest) |> String.replace(".", " ")
    end
  end
end
