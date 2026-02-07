defmodule OneAgent.Tools.SendEmail do
  @moduledoc """
  Sends an email on behalf of the user. Requires `email` bucket.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "send_email"

  @impl true
  def name, do: "Send Email"

  @impl true
  def description do
    "Send an email to a recipient. Requires email permission."
  end

  @impl true
  def bucket, do: :email

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "to" => %{
          "type" => "string",
          "description" => "Recipient email address"
        },
        "subject" => %{
          "type" => "string",
          "description" => "Email subject line"
        },
        "body" => %{
          "type" => "string",
          "description" => "Email body (plain text)"
        }
      },
      "required" => ["to", "subject", "body"]
    }
  end

  @impl true
  def required_credential_type, do: :api_key

  @impl true
  def execute(input, context) do
    from_email = context[:user_email] || Application.get_env(:oneagent, :email_from, "onboarding@resend.dev")

    email =
      Swoosh.Email.new(
        to: input["to"],
        from: {"OneAgent", from_email},
        subject: input["subject"],
        text_body: input["body"]
      )

    # Pass credential as Resend API key override if available
    deliver_config =
      case context[:credential_value] do
        nil -> []
        api_key -> [api_key: api_key]
      end

    case OneAgent.Mailer.deliver(email, deliver_config) do
      {:ok, _} ->
        {:ok, %{"sent_to" => input["to"], "subject" => input["subject"]}}

      {:error, reason} ->
        {:error, "Failed to send email: #{inspect(reason)}"}
    end
  end
end
