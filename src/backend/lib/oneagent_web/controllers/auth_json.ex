defmodule OneAgentWeb.AuthJSON do
  alias OneAgent.Accounts.User

  def render("user.json", %{user: user, token: token}) do
    %{
      data: %{
        user: user_data(user),
        token: token
      }
    }
  end

  def render("user.json", %{user: user}) do
    %{data: %{user: user_data(user)}}
  end

  def render("message.json", %{message: message}) do
    %{data: %{message: message}}
  end

  def render("error.json", %{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end

  defp user_data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      confirmed_at: user.confirmed_at,
      inserted_at: user.inserted_at
    }
  end
end
