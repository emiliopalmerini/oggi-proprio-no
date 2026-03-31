defmodule OggiWeb.Plugs.SetLocale do
  @moduledoc """
  Parses the Accept-Language header and sets the Gettext locale.
  """
  import Plug.Conn

  @supported_locales ~w(en_US en_GB fr de it es)
  @default_locale "en_US"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      conn
      |> get_req_header("accept-language")
      |> parse_header()
      |> resolve_locale()

    Gettext.put_locale(OggiWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end

  defp parse_header([]), do: []

  defp parse_header([header | _]) do
    header
    |> String.split(",")
    |> Enum.map(&parse_tag/1)
    |> Enum.sort_by(fn {_tag, q} -> q end, :desc)
    |> Enum.map(fn {tag, _q} -> tag end)
  end

  defp parse_tag(entry) do
    case String.split(String.trim(entry), ";") do
      [tag] ->
        {normalize_tag(tag), 1.0}

      [tag | params] ->
        quality =
          Enum.find_value(params, 1.0, fn param ->
            case String.trim(param) do
              "q=" <> q -> parse_quality(q)
              _ -> nil
            end
          end)

        {normalize_tag(tag), quality}
    end
  end

  defp parse_quality(q) do
    case Float.parse(q) do
      {val, _} -> val
      :error -> 1.0
    end
  end

  defp normalize_tag(tag) do
    tag |> String.trim() |> String.replace("-", "_")
  end

  defp resolve_locale(tags) do
    Enum.find_value(tags, @default_locale, fn tag ->
      cond do
        tag == "*" -> nil
        tag in @supported_locales -> tag
        remap_tag(tag) in @supported_locales -> remap_tag(tag)
        base_language(tag) in @supported_locales -> base_language(tag)
        true -> nil
      end
    end)
  end

  defp remap_tag("en"), do: "en_US"
  defp remap_tag(tag), do: tag

  defp base_language(tag) do
    tag |> String.split("_") |> hd()
  end
end
