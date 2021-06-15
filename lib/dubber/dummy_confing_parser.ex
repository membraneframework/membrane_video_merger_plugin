defmodule DummyConfigParser do
  alias Membrane.Time
  @spec parse(string) :: %{}
  def parse(path_to_config) do
    %{
      "track_1" => [%{start: 0, stop: 1.5 * Time.second()}, %{start: 9.5 * Time.second(), stop: 10 * Time.second()}],
      "track_2" => [%{start: 1.5 * Time.second(), stop: 4.5 * Time.second()}],
      "track_3" => [%{start: 4.5 * Time.second(), stop: 9.5 * Time.second()}]
    }
  end
end
