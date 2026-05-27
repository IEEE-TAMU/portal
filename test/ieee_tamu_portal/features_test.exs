defmodule IeeeTamuPortal.FeaturesTest do
  use ExUnit.Case, async: false

  alias IeeeTamuPortal.Features

  @s3_key IeeeTamuPortalWeb.Upload.SimpleS3Upload

  describe "enabled?/1" do
    test "returns true for s3_resume_upload when all config is present" do
      assert Features.enabled?(:s3_resume_upload)
    end

    test "returns true for admin_panel when creds are configured" do
      assert Features.enabled?(:admin_panel)
    end

    test "returns false for unknown feature key" do
      refute Features.enabled?(:nonexistent)
    end

    test "returns false when config key is entirely absent" do
      refute Features.enabled?(:mautic)
    end

    test "returns false when required keys have nil values" do
      original = save_config(@s3_key)
      put_config(@s3_key, region: nil, access_key_id: nil, secret_access_key: nil, url: nil)
      refute Features.enabled?(:s3_resume_upload)
      restore_config(@s3_key, original)
    end

    test "returns true when all required keys are present" do
      original = save_config(:mautic)

      put_config(:mautic,
        base_url: "https://mautic.example.com",
        username: "user",
        password: "pass"
      )

      assert Features.enabled?(:mautic)
      restore_config(:mautic, original)
    end

    test "returns false when one required key is nil" do
      original = save_config(@s3_key)

      put_config(@s3_key,
        region: "auto",
        access_key_id: nil,
        secret_access_key: "secret",
        url: "https://example.com"
      )

      refute Features.enabled?(:s3_resume_upload)
      restore_config(@s3_key, original)
    end

    test "returns false for :single config when value is nil" do
      original = save_config(:discord_bot_url)
      Application.put_env(:ieee_tamu_portal, :discord_bot_url, nil)
      refute Features.enabled?(:discord_bot)
      restore_config(:discord_bot_url, original)
    end

    test "returns false for :single config when value is empty string" do
      original = save_config(:discord_bot_url)
      Application.put_env(:ieee_tamu_portal, :discord_bot_url, "")
      refute Features.enabled?(:discord_bot)
      restore_config(:discord_bot_url, original)
    end

    test "returns true for :single config when value is a non-empty string" do
      original = save_config(:discord_bot_url)
      Application.put_env(:ieee_tamu_portal, :discord_bot_url, "http://localhost:3000")
      assert Features.enabled?(:discord_bot)
      restore_config(:discord_bot_url, original)
    end
  end

  describe "list/0" do
    test "returns all feature definitions with enabled status" do
      all = Features.list()
      assert length(all) == 6
      assert Enum.all?(all, &Map.has_key?(&1, :enabled))
      assert Enum.all?(all, &Map.has_key?(&1, :name))
      assert Enum.all?(all, &Map.has_key?(&1, :key))
    end
  end

  describe "configured_features/0" do
  end

  defp save_config(key) do
    Application.get_env(:ieee_tamu_portal, key)
  end

  defp put_config(key, value) do
    Application.put_env(:ieee_tamu_portal, key, value)
  end

  defp restore_config(key, nil) do
    Application.delete_env(:ieee_tamu_portal, key)
  end

  defp restore_config(key, value) do
    Application.put_env(:ieee_tamu_portal, key, value)
  end
end
