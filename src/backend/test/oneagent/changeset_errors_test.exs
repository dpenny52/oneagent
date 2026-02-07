defmodule OneAgent.ChangesetErrorsTest do
  use ExUnit.Case, async: true

  alias OneAgent.ChangesetErrors

  describe "format/1" do
    test "formats a single required field error" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{}, [:name])
        |> Ecto.Changeset.validate_required([:name])

      assert ChangesetErrors.format(changeset) == "name: can't be blank"
    end

    test "formats a length validation error with interpolated count" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{name: "ab"}, [:name])
        |> Ecto.Changeset.validate_length(:name, min: 3)

      assert ChangesetErrors.format(changeset) =~ "name: should be at least 3 character(s)"
    end

    test "formats multiple errors on the same field" do
      changeset =
        {%{}, %{email: :string}}
        |> Ecto.Changeset.cast(%{email: ""}, [:email])
        |> Ecto.Changeset.validate_required([:email])
        |> Ecto.Changeset.validate_format(:email, ~r/@/)

      result = ChangesetErrors.format(changeset)
      assert result =~ "email:"
      assert result =~ "can't be blank"
    end

    test "formats errors on multiple fields joined by semicolon" do
      changeset =
        {%{}, %{name: :string, email: :string}}
        |> Ecto.Changeset.cast(%{}, [:name, :email])
        |> Ecto.Changeset.validate_required([:name, :email])

      result = ChangesetErrors.format(changeset)
      assert result =~ "name: can't be blank"
      assert result =~ "email: can't be blank"
      assert result =~ ";"
    end

    test "returns empty string for valid changeset" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{name: "valid"}, [:name])
        |> Ecto.Changeset.validate_required([:name])

      assert ChangesetErrors.format(changeset) == ""
    end
  end
end
