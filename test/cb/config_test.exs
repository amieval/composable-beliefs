defmodule CB.ConfigTest do
  # async: false - these tests mutate the :cb app env and the CB_BELIEFS
  # OS env var, which are process-global.
  use ExUnit.Case, async: false

  alias CB.Config

  setup do
    prev_env = Application.get_env(:cb, :beliefs_path)
    prev_os = System.get_env("CB_BELIEFS")

    on_exit(fn ->
      if prev_env,
        do: Application.put_env(:cb, :beliefs_path, prev_env),
        else: Application.delete_env(:cb, :beliefs_path)

      if prev_os,
        do: System.put_env("CB_BELIEFS", prev_os),
        else: System.delete_env("CB_BELIEFS")
    end)

    # Clean slate so each assertion controls exactly the sources it sets.
    Application.delete_env(:cb, :beliefs_path)
    System.delete_env("CB_BELIEFS")
    :ok
  end

  test "app env beliefs_path takes precedence over CB_BELIEFS" do
    System.put_env("CB_BELIEFS", "/from/env.json")
    Application.put_env(:cb, :beliefs_path, "/from/app.json")
    assert Config.beliefs_path() == "/from/app.json"
  end

  test "CB_BELIEFS is used when the app env is unset" do
    System.put_env("CB_BELIEFS", "/from/env.json")
    assert Config.beliefs_path() == "/from/env.json"
  end

  test "falls back to the default path when neither is set" do
    assert String.ends_with?(Config.beliefs_path(), "beliefs/beliefs.json")
  end
end
