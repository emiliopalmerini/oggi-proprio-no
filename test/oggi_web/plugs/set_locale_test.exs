defmodule OggiWeb.Plugs.SetLocaleTest do
  use OggiWeb.ConnCase

  alias OggiWeb.Plugs.SetLocale

  describe "call/2" do
    test "defaults to en_US when no Accept-Language header", %{conn: conn} do
      conn = SetLocale.call(conn, [])

      assert Gettext.get_locale(OggiWeb.Gettext) == "en_US"
      assert conn.assigns.locale == "en_US"
    end

    test "detects Italian from accept-language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "it")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "it"
      assert conn.assigns.locale == "it"
    end

    test "detects French from accept-language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "fr-FR,fr;q=0.9,en;q=0.8")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "fr"
      assert conn.assigns.locale == "fr"
    end

    test "detects German from accept-language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "de-DE,de;q=0.9")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "de"
      assert conn.assigns.locale == "de"
    end

    test "detects Spanish from accept-language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "es-MX,es;q=0.9")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "es"
      assert conn.assigns.locale == "es"
    end

    test "detects en_GB from accept-language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "en-GB,en;q=0.9")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "en_GB"
      assert conn.assigns.locale == "en_GB"
    end

    test "detects en_US from accept-language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "en-US,en;q=0.9")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "en_US"
      assert conn.assigns.locale == "en_US"
    end

    test "bare 'en' resolves to en_US", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "en")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "en_US"
      assert conn.assigns.locale == "en_US"
    end

    test "unsupported language falls back to en_US", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "ja,zh;q=0.9")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "en_US"
      assert conn.assigns.locale == "en_US"
    end

    test "regional variant falls back to base language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "fr-CA")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "fr"
      assert conn.assigns.locale == "fr"
    end

    test "picks highest quality match", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "ja;q=1.0, it;q=0.9, en;q=0.8")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "it"
      assert conn.assigns.locale == "it"
    end

    test "handles wildcard *", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "*")
        |> SetLocale.call([])

      assert Gettext.get_locale(OggiWeb.Gettext) == "en_US"
      assert conn.assigns.locale == "en_US"
    end
  end
end
